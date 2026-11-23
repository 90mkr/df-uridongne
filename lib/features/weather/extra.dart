// 덧붙는 날씨 자료 (api.dart 의 한 부분) — 특보 · 중기예보(10일) · 생활기상지수 · 요일별 미세먼지 예보
// 모두 「지역 단위」 자료라 같은 지역은 한 번 받은 것을 정해진 시간 동안 함께 쓴다 (조회 한도 절약).
part of 'api.dart';

class Alert {
  final String kind; // 폭염·한파·호우·대설·황사·태풍·강풍·건조
  final bool warning; // 경보(true) / 주의보(false)
  const Alert(this.kind, this.warning);
  String get name => '$kind${warning ? '경보' : '주의보'}';
}

class DustDay {
  final DateTime date;
  final int g10, g25; // 1 좋음 ~ 4 매우나쁨, 0 모름 (오늘~모레 예보)
  final String week25; // 초미세 주간 예보 「낮음」「높음」 (그 뒤 날)
  const DustDay(this.date, {this.g10 = 0, this.g25 = 0, this.week25 = ''});
}

// ---------------- 지역 단위 함께 쓰기 ----------------

final Map<String, (DateTime, Object?)> _memoStore = {};
final Map<String, Future<Object?>> _memoLoading = {};

Future<T?> _memo<T>(String key, Duration keep, Future<T?> Function() load) async {
  final have = _memoStore[key];
  if (have != null && _nowKst.difference(have.$1) < keep) return have.$2 as T?;
  final f = _memoLoading[key] ??= _safe<T>(load(), key).then((v) {
    _memoLoading.remove(key);
    if (v != null) _memoStore[key] = (_nowKst, v);
    return v ?? have?.$2;
  });
  return await f as T?;
}

// 시·도 → 기상청 지역 번호
const _midLand = {
  '서울': '11B00000', '인천': '11B00000', '경기': '11B00000',
  '강원': '11D10000', '대전': '11C20000', '세종': '11C20000', '충남': '11C20000', '충북': '11C10000',
  '광주': '11F20000', '전남': '11F20000', '전북': '11F10000', '대구': '11H10000', '경북': '11H10000',
  '부산': '11H20000', '울산': '11H20000', '경남': '11H20000', '제주': '11G00000',
};
const _midTemp = {
  '서울': '11B10101', '인천': '11B20201', '경기': '11B20601', '강원': '11D10301', '대전': '11C20401', '세종': '11C20404',
  '충남': '11C20101', '충북': '11C10301', '광주': '11F20501', '전남': '21F20801', '전북': '11F10201', '대구': '11H10701',
  '경북': '11H10201', '부산': '11H20201', '울산': '11H20101', '경남': '11H20301', '제주': '11G00201',
};
const _areaNo = {
  '서울': '1100000000', '부산': '2600000000', '대구': '2700000000', '인천': '2800000000', '광주': '2900000000',
  '대전': '3000000000', '울산': '3100000000', '세종': '3611000000', '경기': '4100000000', '강원': '5100000000',
  '충북': '4300000000', '충남': '4400000000', '전북': '5200000000', '전남': '4600000000', '경북': '4700000000',
  '경남': '4800000000', '제주': '5000000000',
};
const _sidoLong = {
  '서울': ['서울'], '부산': ['부산'], '대구': ['대구'], '인천': ['인천'], '광주': ['광주'], '대전': ['대전'], '울산': ['울산'],
  '세종': ['세종'], '경기': ['경기'], '강원': ['강원'], '충북': ['충청북도', '충북'], '충남': ['충청남도', '충남'],
  '전북': ['전라북도', '전북'], '전남': ['전라남도', '전남'], '경북': ['경상북도', '경북'], '경남': ['경상남도', '경남'], '제주': ['제주'],
};

String _sidoShort(String s) {
  for (final k in _sidoLong.keys) {
    if (s.startsWith(k) || (_sidoLong[k]!.any((x) => s.startsWith(x)))) return k;
  }
  return s;
}

const _base = 'https://apis.data.go.kr/1360000';

// ---------------- 중기예보 (4~10일 뒤) ----------------

Sky _wfSky(String t) {
  if (t.contains('소나기')) return Sky.shower;
  if (t.contains('비/눈') || t.contains('눈/비') || t.contains('진눈')) return Sky.sleet;
  if (t.contains('눈')) return Sky.snow;
  if (t.contains('비')) return Sky.rain;
  if (t.contains('흐림') || t.contains('흐리')) return Sky.overcast;
  if (t.contains('구름많')) return Sky.cloudy;
  return Sky.clear;
}

Future<List<Day>> _mid(String sido) async {
  final land = _midLand[sido], temp = _midTemp[sido];
  if (land == null || kDataGoKrKey.isEmpty) return const [];
  return await _memo<List<Day>>('mid_$sido', const Duration(hours: 3), () async {
    final now = _nowKst;
    // 발표: 06시·18시 (15분 여유)
    final t = now.subtract(const Duration(minutes: 15));
    final DateTime fc;
    if (t.hour >= 18) {
      fc = DateTime(t.year, t.month, t.day, 18);
    } else if (t.hour >= 6) {
      fc = DateTime(t.year, t.month, t.day, 6);
    } else {
      final y = t.subtract(const Duration(days: 1));
      fc = DateTime(y.year, y.month, y.day, 18);
    }
    final tmFc = '${_ymd(fc)}${_2(fc.hour)}00';
    String q(String op, String reg) => '$_base/MidFcstInfoService/$op?serviceKey=$_key&pageNo=1&numOfRows=10&dataType=JSON&regId=$reg&tmFc=$tmFc';
    final r = await Future.wait([_get(q('getMidLandFcst', land)), _get(q('getMidTa', temp!))]);
    final l = _items(r[0]), ta = _items(r[1]);
    if (l.isEmpty && ta.isEmpty) return null;
    final lm = l.isEmpty ? const {} : l.first as Map;
    final tm = ta.isEmpty ? const {} : ta.first as Map;
    final out = <Day>[];
    for (var n = 3; n <= 10; n++) {
      final am = lm['wf${n}Am'] ?? lm['wf$n'], pm = lm['wf${n}Pm'] ?? lm['wf$n'];
      final pa = _int(lm['rnSt${n}Am'] ?? lm['rnSt$n']), pp = _int(lm['rnSt${n}Pm'] ?? lm['rnSt$n']);
      final lo = _num(tm['taMin$n']), hi = _num(tm['taMax$n']);
      if (am == null && lo == null) continue;
      final d = Day(DateTime(fc.year, fc.month, fc.day).add(Duration(days: n)))
        ..mid = true
        ..am = _wfSky('${am ?? ''}')
        ..pm = _wfSky('${pm ?? am ?? ''}')
        ..popAm = pa ?? 0
        ..popPm = pp ?? pa ?? 0
        ..min = lo
        ..max = hi;
      out.add(d);
    }
    return out;
  }) ?? const [];
}

// ---------------- 특보 ----------------

const _alertKinds = ['폭염', '한파', '호우', '대설', '황사', '태풍', '강풍', '건조'];

Future<Alert?> _alert(String sido, String gu) async {
  if (kDataGoKrKey.isEmpty || sido.isEmpty) return null;
  final text = await _memo<String>('pwn', const Duration(minutes: 10), () async {
    final j = await _get('$_base/WthrWrnInfoService/getPwnStatus?serviceKey=$_key&pageNo=1&numOfRows=10&dataType=JSON');
    final it = _items(j);
    if (j == null) return null;
    return it.isEmpty ? '' : '${(it.first as Map)['t6'] ?? ''}';
  });
  if (text == null || text.isEmpty) return null;
  final names = _sidoLong[sido] ?? [sido];
  Alert? best;
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final m = RegExp(r'([가-힣]+)(경보|주의보)\s*:\s*(.*)').firstMatch(line);
    if (m == null) continue;
    final kind = m.group(1)!.replaceAll(RegExp(r'^o\s*'), '');
    if (!_alertKinds.contains(kind)) continue;
    final where = m.group(3)!;
    var hit = false;
    for (final n in names) {
      final i = where.indexOf(n);
      if (i < 0) continue;
      // 「인천(강화군, 옹진군)」처럼 일부만이면 우리 구가 들어 있을 때만
      final rest = where.substring(i + n.length);
      final part = RegExp(r'^[가-힣]*\s*\(([^)]*)\)').firstMatch(rest);
      if (part == null || gu.isEmpty || part.group(1)!.contains(gu.replaceAll(RegExp(r'[구군시]$'), ''))) hit = true;
      if (hit) break;
    }
    if (!hit) continue;
    final a = Alert(kind, m.group(2) == '경보');
    if (best == null || (a.warning && !best.warning)) best = a;
  }
  return best;
}

// ---------------- 생활기상지수 (자외선·동파) ----------------

Future<int?> _livingIdx(String op, String sido) async {
  final area = _areaNo[sido];
  if (area == null || kDataGoKrKey.isEmpty) return null;
  return _memo<int>('$op$sido', const Duration(hours: 3), () async {
    final now = _nowKst.subtract(const Duration(minutes: 30));
    // 3시간마다 발표 → 가까운 발표 시각부터 두 번까지
    for (var back = 0; back < 2; back++) {
      final t = now.subtract(Duration(hours: back * 3));
      final h = t.hour - t.hour % 3;
      final j = await _get('$_base/LivingWthrIdxServiceV4/$op?serviceKey=$_key&pageNo=1&numOfRows=10&dataType=JSON&areaNo=$area&time=${_ymd(t)}${_2(h)}');
      final it = _items(j);
      if (it.isEmpty) continue;
      final m = it.first as Map;
      // 오늘 남은 시간 중 가장 높은 값
      final left = 24 - t.hour;
      int? best;
      for (var k = 0; k <= 21 && k <= left; k += 3) {
        final v = _int(m['h$k']);
        if (v != null && (best == null || v > best)) best = v;
      }
      return best ?? _int(m['today']);
    }
    return null;
  });
}

String uvText(int v) => v >= 11 ? '위험' : v >= 8 ? '매우 높음' : v >= 6 ? '높음' : v >= 3 ? '보통' : '낮음';

// ---------------- 요일별 미세먼지 예보 ----------------

Future<List<DustDay>> _dustDays(String sido) async {
  if (sido.isEmpty || (kDataGoKrKey.isEmpty && kAirKoreaKey.isEmpty)) return const [];
  return await _memo<List<DustDay>>('dust_$sido', const Duration(hours: 1), () async {
    final now = _nowKst;
    String day(DateTime t) => '${t.year}-${_2(t.month)}-${_2(t.day)}';
    // 1) 오늘~모레: 미세·초미세 등급
    Future<Map<String, int>> daily(String code) async {
      final out = <String, int>{};
      for (final sd in [now, now.subtract(const Duration(days: 1))]) {
        final j = await _get('$_air/getMinuDustFrcstDspth?serviceKey=$_airKey&returnType=json&numOfRows=100&pageNo=1&searchDate=${day(sd)}&InformCode=$code');
        final it = _items(j).whereType<Map>().toList()..sort((a, b) => '${b['dataTime']}'.compareTo('${a['dataTime']}'));
        for (final x in it) {
          final d = '${x['informData']}';
          if (out.containsKey(d)) continue;
          final m = RegExp('$sido\\s*:\\s*(좋음|보통|나쁨|매우나쁨)').firstMatch('${x['informGrade']}');
          if (m != null) out[d] = gradeText.indexOf(m.group(1)!);
        }
        if (out.isNotEmpty) break;
      }
      return out;
    }

    // 2) 주간 초미세 (낮음·높음)
    Future<Map<String, String>> week() async {
      final out = <String, String>{};
      for (final sd in [now, now.subtract(const Duration(days: 1))]) {
        final j = await _get('$_air/getMinuDustWeekFrcstDspth?serviceKey=$_airKey&returnType=json&numOfRows=10&pageNo=1&searchDate=${day(sd)}');
        final it = _items(j).whereType<Map>().toList();
        if (it.isEmpty) continue;
        final x = it.first;
        for (final n in ['One', 'Two', 'Three', 'Four']) {
          final d = '${x['frcst${n}Dt'] ?? ''}';
          final m = RegExp('$sido\\s*:\\s*(낮음|높음)').firstMatch('${x['frcst${n}Cn'] ?? ''}');
          if (d.isNotEmpty && m != null) out[d] = m.group(1)!;
        }
        if (out.isNotEmpty) break;
      }
      return out;
    }

    final r = await Future.wait([daily('PM10'), daily('PM25')]);
    final wk = await week();
    final dates = <String>{...r[0].keys, ...r[1].keys, ...wk.keys}.where((d) => d.compareTo(day(now)) >= 0).toList()..sort();
    if (dates.isEmpty) return null;
    return [
      for (final d in dates.take(7))
        DustDay(DateTime.parse(d), g10: r[0][d] ?? 0, g25: r[1][d] ?? 0, week25: wk[d] ?? ''),
    ];
  }) ?? const [];
}

// ---------------- 붙이기 ----------------

Future<void> _attachExtras(Weather w, Complex c) async {
  final sido = _sidoShort(c.area?.sido ?? '');
  final gu = c.area?.gu ?? '';
  final r = await Future.wait<Object?>([
    _mid(sido),
    _alert(sido, gu),
    _livingIdx('getUVIdxV4', sido),
    _isFreezeSeason ? _livingIdx('getFreezeIdxV4', sido) : Future.value(null),
    _dustDays(sido),
  ]);
  final mid = r[0] as List<Day>? ?? const [];
  final have = {for (final d in w.days) _ymd(d.date)};
  w.days = [...w.days, ...mid.where((d) => !have.contains(_ymd(d.date)) && d.date.isAfter(w.days.isEmpty ? DateTime(2000) : w.days.last.date))]
    ..sort((a, b) => a.date.compareTo(b.date));
  if (w.days.length > 10) w.days = w.days.take(10).toList();
  w.alert = r[1] as Alert?;
  w.uv = r[2] as int?;
  w.freeze = r[3] as int?;
  w.dustDays = r[4] as List<DustDay>? ?? const [];
  // 내일 예보 등급을 지금 미세먼지 칸에도
  final tm = w.dustDays.where((d) => d.date.day == _nowKst.add(const Duration(days: 1)).day).firstOrNull;
  if (w.dust != null && tm != null && (w.dust!.tomorrow10 == 0 && w.dust!.tomorrow25 == 0)) {
    w.dust = w.dust!.withTomorrow(tm.g10, tm.g25);
  }
}

bool get _isFreezeSeason {
  final m = _nowKst.month;
  return m == 12 || m <= 2;
}

// ---------------- 아침 알림 글 ----------------
// 특별한 게 없는 날은 null (알림을 보내지 않음). 본부의 알림 기능이 이 글을 그대로 보낸다.
String? morningBrief(Weather w) {
  final parts = <String>[];
  if (w.alert != null) parts.add('${w.alert!.name} 발효 중');
  final day = w.hours.where((h) => h.t.hour >= 6 && h.t.hour <= 21 && h.t.day == w.at.day).toList();
  final wet = day.where((h) => (h.pop ?? 0) >= 60 || isWet(h.sky)).toList();
  if (wet.isNotEmpty) {
    final h = wet.first;
    final when = h.t.hour < 12 ? '오전' : h.t.hour < 18 ? '오후' : '저녁';
    final snow = wet.any((x) => x.sky == Sky.snow || x.sky == Sky.sleet);
    parts.add('$when ${snow ? '눈' : '비'} · 우산 챙기세요');
  }
  final today = w.dustDays.isEmpty ? null : w.dustDays.first;
  final dg = math.max(w.dust?.worst ?? 0, math.max(today?.g10 ?? 0, today?.g25 ?? 0));
  if (dg >= 3) parts.add('미세먼지 ${gradeText[dg]} · 마스크');
  final lo = w.today?.min;
  if ((w.freeze ?? 0) >= 75 || (lo != null && lo <= -10)) parts.add('한파 · 동파 조심');
  if ((w.uv ?? 0) >= 8) parts.add('자외선 매우 높음 · 선크림');
  return parts.isEmpty ? null : parts.join('\n');
}
