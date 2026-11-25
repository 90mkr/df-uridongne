// 오늘의 산책 지수 — 반려동물 테마 방 (대표님 11-26)
// 기상청 단기예보(시간별 기온·하늘·비·바람) + 에어코리아(지금 미세먼지)로
// 시간마다 「좋음 / 보통 / 짧게 / 쉬어요」를 매기고, 오늘 가장 좋은 시간과 아이 맞춤 팁을 보여 준다.
// 기준은 아이 크기·단두종·나이에 따라 다르게 (우리 아이 수첩의 강아지 → 없으면 직접 고름 'pet.walk').
// 이 폴더 안에서만 완결 (날씨 방 코드는 가져다 쓰지 않음 — 작업 규칙)
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/dg.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'kids.dart';

// ---------------- 아이 기준 ----------------

enum DogSize { small, medium, large }

const kDogSizeText = {DogSize.small: '소형견', DogSize.medium: '중형견', DogSize.large: '대형견'};

// 코가 짧아 더위에 약한 견종 (이름에 들어 있으면)
const _flatWords = ['퍼그', '불독', '불도그', '시츄', '시추', '페키니즈', '보스턴', '프렌치', '복서', '라사', '친', '카발리에', '브뤼셀', '샤페이', '마스티프'];

class WalkProfile {
  DogSize size;
  bool flat; // 단두종
  bool senior; // 8살 넘음
  String who; // 「콩이 기준」처럼 보여 줄 이름 ('' = 직접 고름)
  WalkProfile({this.size = DogSize.small, this.flat = false, this.senior = false, this.who = ''});

  String get label => [kDogSizeText[size]!, if (flat) '단두종', if (senior) '노령'].join(' · ');
  Map toJson() => {'s': size.name, 'f': flat, 'o': senior};
}

/// 수첩의 첫 강아지로 기준을 잡고, 없으면 직접 고른 값('pet.walk')
Future<WalkProfile> walkProfile() async {
  await loadKids();
  final dog = kids.value.where((k) => k.kind == '강아지').firstOrNull;
  if (dog != null) {
    final w = dog.weight;
    final b = dog.birth;
    final age = b == null ? 0 : DateTime.now().difference(b).inDays / 365.25;
    return WalkProfile(
      size: w <= 0 || w < 10 ? DogSize.small : (w < 25 ? DogSize.medium : DogSize.large),
      flat: _flatWords.any((x) => dog.breed.contains(x)),
      senior: age >= 8,
      who: dog.name,
    );
  }
  final s = await prefGet('pet.walk');
  try {
    final j = jsonDecode(s ?? '');
    if (j is Map) {
      return WalkProfile(
        size: DogSize.values.where((x) => x.name == j['s']).firstOrNull ?? DogSize.small,
        flat: j['f'] == true,
        senior: j['o'] == true,
      );
    }
  } catch (_) {}
  return WalkProfile();
}

bool get onlyCats => kids.value.isNotEmpty && kids.value.every((k) => k.kind == '고양이');

// ---------------- 자료 ----------------

class WalkHour {
  final DateTime t;
  final double? temp;
  final int sky; // 1 맑음 · 3 구름 많음 · 4 흐림
  final int pty; // 0 없음 · 1 비 · 2 비/눈 · 3 눈 · 4 소나기
  final int pop; // 강수확률
  final double wind; // m/s
  const WalkHour(this.t, {this.temp, this.sky = 1, this.pty = 0, this.pop = 0, this.wind = 0});

  // 체감온도 (기상청 겨울철 식: 10℃ 이하 · 바람 1.3m/s 이상)
  double? get feels {
    final v = temp;
    if (v == null || v > 10 || wind < 1.3) return v;
    final w = math.pow(wind * 3.6, 0.16);
    return 13.12 + 0.6215 * v - 11.37 * w + 0.3965 * w * v;
  }

  bool get snow => pty == 2 || pty == 3;
  bool get wet => pty > 0;
}

class WalkData {
  final List<WalkHour> hours; // 지금부터 내일 밤까지
  final int dust; // 1 좋음 ~ 4 매우나쁨, 0 모름 (미세먼지·초미세먼지 중 나쁜 쪽)
  final String dustText; // 「미세먼지 보통 · 초미세 좋음」
  final String station;
  final DateTime at;
  const WalkData(this.hours, this.dust, this.dustText, this.station, this.at);
}

const _gradeText = ['-', '좋음', '보통', '나쁨', '매우나쁨'];
int _g10(int? v) => v == null ? 0 : (v <= 30 ? 1 : v <= 80 ? 2 : v <= 150 ? 3 : 4);
int _g25(int? v) => v == null ? 0 : (v <= 15 ? 1 : v <= 35 ? 2 : v <= 75 ? 3 : 4);

double? _num(dynamic v) => v == null ? null : double.tryParse('$v'.trim());
String _2(int v) => v.toString().padLeft(2, '0');
String _ymd(DateTime t) => '${t.year}${_2(t.month)}${_2(t.day)}';
DateTime get _kst => DateTime.now().toUtc().add(const Duration(hours: 9));

Future<dynamic> _json(String url, {int cache = 1800}) async {
  try {
    final r = await dgGet(url, cache: cache);
    if (r.statusCode != 200) return null;
    final b = utf8.decode(r.bodyBytes);
    if (!b.trimLeft().startsWith('{')) return null;
    return jsonDecode(b);
  } catch (_) {
    return null;
  }
}

List _items(dynamic j) {
  try {
    final it = j['response']['body']['items'];
    if (it is List) return it;
    final x = it['item'];
    return x is List ? x : (x == null ? const [] : [x]);
  } catch (_) {
    return const [];
  }
}

({int nx, int ny}) _grid(double lat, double lng) {
  const re = 6371.00877 / 5.0, slat1 = 30.0, slat2 = 60.0, olon = 126.0, olat = 38.0, xo = 43.0, yo = 136.0;
  const d = math.pi / 180.0;
  final s1 = slat1 * d, s2 = slat2 * d, ol = olon * d, oa = olat * d;
  var sn = math.tan(math.pi * 0.25 + s2 * 0.5) / math.tan(math.pi * 0.25 + s1 * 0.5);
  sn = math.log(math.cos(s1) / math.cos(s2)) / math.log(sn);
  var sf = math.tan(math.pi * 0.25 + s1 * 0.5);
  sf = math.pow(sf, sn) * math.cos(s1) / sn;
  var ro = math.tan(math.pi * 0.25 + oa * 0.5);
  ro = re * sf / math.pow(ro, sn);
  var ra = math.tan(math.pi * 0.25 + lat * d * 0.5);
  ra = re * sf / math.pow(ra, sn);
  var th = lng * d - ol;
  if (th > math.pi) th -= 2.0 * math.pi;
  if (th < -math.pi) th += 2.0 * math.pi;
  th *= sn;
  return (nx: (ra * math.sin(th) + xo + 0.5).floor(), ny: (ro - ra * math.cos(th) + yo + 0.5).floor());
}

// 단기예보 발표 시각 (02·05·08·11·14·17·20·23시, 10분 뒤부터)
({String date, String time}) _base(DateTime now) {
  final t = now.subtract(const Duration(minutes: 15));
  for (final h in const [23, 20, 17, 14, 11, 8, 5, 2]) {
    if (t.hour >= h) return (date: _ymd(t), time: '${_2(h)}00');
  }
  return (date: _ymd(t.subtract(const Duration(days: 1))), time: '2300');
}

Future<List<WalkHour>> _forecast(LatLng p) async {
  final g = _grid(p.latitude, p.longitude);
  final now = _kst;
  final b = _base(now);
  final j = await _json('https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst'
      '?pageNo=1&numOfRows=1000&dataType=JSON&base_date=${b.date}&base_time=${b.time}&nx=${g.nx}&ny=${g.ny}');
  final slots = <String, Map<String, String>>{};
  for (final x in _items(j)) {
    if (x is! Map) continue;
    (slots['${x['fcstDate']}${x['fcstTime']}'] ??= {})['${x['category']}'] = '${x['fcstValue']}';
  }
  final from = DateTime(now.year, now.month, now.day, now.hour);
  final until = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
  final out = <WalkHour>[];
  for (final k in slots.keys.toList()..sort()) {
    final t = DateTime(int.parse(k.substring(0, 4)), int.parse(k.substring(4, 6)), int.parse(k.substring(6, 8)), int.parse(k.substring(8, 10)));
    if (t.isBefore(from) || !t.isBefore(until)) continue;
    final s = slots[k]!;
    out.add(WalkHour(t,
        temp: _num(s['TMP']),
        sky: int.tryParse(s['SKY'] ?? '') ?? 1,
        pty: int.tryParse(s['PTY'] ?? '') ?? 0,
        pop: int.tryParse(s['POP'] ?? '') ?? 0,
        wind: _num(s['WSD']) ?? 0));
  }
  return out;
}

Future<(int, String, String)> _dust(Complex c) async {
  final sido = c.area?.sido ?? (c.addr.split(' ').firstOrNull ?? '');
  if (sido.isEmpty) return (0, '', '');
  final short = sido.replaceAll(RegExp(r'(특별자치시|특별자치도|특별시|광역시|도)$'), '');
  final j = await _json('https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty'
      '?returnType=json&numOfRows=300&pageNo=1&sidoName=${Uri.encodeQueryComponent(short.isEmpty ? sido : short)}&ver=1.3');
  final it = _items(j).whereType<Map>().where((x) => _num(x['pm10Value']) != null || _num(x['pm25Value']) != null).toList();
  if (it.isEmpty) return (0, '', '');
  final words = <String>{
    ...?c.area?.name.split('/'),
    if ((c.area?.gu ?? '').isNotEmpty) c.area!.gu.replaceAll(RegExp(r'[구군시]$'), ''),
    ...c.addr.split(' ').where((w) => w.endsWith('동')).map((w) => w.replaceAll(RegExp(r'\d*동$'), '')),
  }..removeWhere((w) => w.length < 2);
  Map? pick;
  for (final w in words) {
    pick = it.where((x) => '${x['stationName']}'.contains(w)).firstOrNull;
    if (pick != null) break;
  }
  pick ??= it.first;
  final g10 = int.tryParse('${pick['pm10Grade1h'] ?? ''}') ?? _g10(_num(pick['pm10Value'])?.round());
  final g25 = int.tryParse('${pick['pm25Grade1h'] ?? ''}') ?? _g25(_num(pick['pm25Value'])?.round());
  final worst = math.max(g10, g25);
  final text = [if (g10 > 0) '미세먼지 ${_gradeText[g10]}', if (g25 > 0) '초미세 ${_gradeText[g25]}'].join(' · ');
  return (worst, text, '${pick['stationName'] ?? ''}');
}

final Map<String, (DateTime, Future<WalkData?>)> _cache = {};

/// 같은 단지는 30분 안에 다시 부르지 않는다
Future<WalkData?> walkData(Complex c, {bool force = false}) {
  final have = _cache[c.id];
  if (!force && have != null && DateTime.now().difference(have.$1).inMinutes < 30) return have.$2;
  final f = () async {
    final r = await Future.wait([_forecast(c.pos), _dust(c)]);
    final hours = r[0] as List<WalkHour>;
    final d = r[1] as (int, String, String);
    if (hours.isEmpty) return null;
    return WalkData(hours, d.$1, d.$2, d.$3, DateTime.now());
  }();
  _cache[c.id] = (DateTime.now(), f);
  f.then((v) {
    if (v == null) _cache.remove(c.id); // 실패는 묶어 두지 않음
  });
  return f;
}

// ---------------- 매기기 ----------------

// 0 좋음 · 1 보통 · 2 짧게 · 3 쉬어요
const kWalkLevel = ['산책 좋음', '보통', '짧게만', '쉬어요'];
const kWalkShort = ['좋음', '보통', '짧게', '쉬어요'];

class WalkJudge {
  final int level;
  final List<String> why; // 「체감 -6℃」처럼 낮춘 까닭
  const WalkJudge(this.level, this.why);
}

WalkJudge judge(WalkHour h, int dust, WalkProfile p, {bool useDust = true}) {
  var lv = 0;
  final why = <String>[];
  void up(int v, String w) {
    if (v > lv) lv = v;
    if (v > 0 && !why.contains(w)) why.add(w);
  }

  // 더위: 기본 27℃부터 짧게, 31℃부터 쉬어요 (단두종·노령 3도 낮게, 대형견 1도 낮게)
  final t = h.temp;
  final f = h.feels;
  if (t != null) {
    var hot = 27.0;
    if (p.flat) hot -= 3;
    if (p.senior) hot -= 2;
    if (p.size == DogSize.large) hot -= 1;
    final sun = h.sky == 1 && h.t.hour >= 11 && h.t.hour <= 16;
    final tt = t + (sun ? 2 : 0); // 한낮 햇볕은 더 덥게
    if (tt >= hot + 4) {
      up(3, '더위 ${t.round()}℃');
    } else if (tt >= hot) {
      up(2, '더위 ${t.round()}℃');
    } else if (tt >= hot - 3) {
      up(1, '조금 더움 ${t.round()}℃');
    }
  }
  // 추위: 소형견 0℃ · 중형견 -5℃ · 대형견 -10℃ 아래면 짧게 (노령 3도 높게)
  if (f != null) {
    var cold = switch (p.size) { DogSize.small => 0.0, DogSize.medium => -5.0, DogSize.large => -10.0 };
    if (p.senior) cold += 3;
    if (f <= cold - 8) {
      up(3, '체감 ${f.round()}℃');
    } else if (f <= cold) {
      up(2, '체감 ${f.round()}℃');
    } else if (f <= cold + 5) {
      up(1, '쌀쌀함 체감 ${f.round()}℃');
    }
  }
  // 비·눈
  if (h.wet) {
    up(h.pty == 4 ? 2 : (h.snow ? 2 : 3), h.snow ? '눈' : '비');
  } else if (h.pop >= 60) {
    up(1, '비 올 확률 ${h.pop}%');
  }
  // 바람
  if (h.wind >= 10) {
    up(2, '강한 바람 ${h.wind.round()}m/s');
  } else if (h.wind >= 7) {
    up(1, '바람 ${h.wind.round()}m/s');
  }
  // 미세먼지 (지금 값이라 오늘 낮까지만 적용)
  if (useDust) {
    if (dust >= 4) {
      up(3, '미세먼지 매우나쁨');
    } else if (dust == 3) {
      up(2, '미세먼지 나쁨');
    }
  }
  return WalkJudge(lv, why);
}

class WalkDay {
  final WalkHour? now;
  final WalkJudge? nowJudge;
  final List<(WalkHour, WalkJudge)> today; // 지금~오늘 밤(6~21시)
  final List<(WalkHour, WalkJudge)> tomorrow; // 내일 6~21시
  final (DateTime, DateTime, int)? best; // 오늘 가장 좋은 시간대 (시작, 끝, 단계)
  final (DateTime, DateTime, int)? bestTomorrow;
  final List<(String, String)> tips; // (아이콘, 글)
  const WalkDay({this.now, this.nowJudge, this.today = const [], this.tomorrow = const [], this.best, this.bestTomorrow, this.tips = const []});
}

bool _daytime(DateTime t) => t.hour >= 6 && t.hour <= 21;

// 가장 좋은 단계가 이어지는 시간대 — 단계가 같으면 날씨가 덜 극단적인(15℃에 가까운) 쪽
(DateTime, DateTime, int)? _bestRun(List<(WalkHour, WalkJudge)> v) {
  if (v.isEmpty) return null;
  final minLv = v.map((x) => x.$2.level).reduce(math.min);
  (int, int)? bestRun;
  double bestCost = 1e9;
  var i = 0;
  while (i < v.length) {
    if (v[i].$2.level != minLv) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < v.length && v[j + 1].$2.level == minLv && v[j + 1].$1.t.difference(v[j].$1.t).inHours == 1) {
      j++;
    }
    var cost = 0.0;
    for (var k = i; k <= j; k++) {
      cost += ((v[k].$1.feels ?? 15) - 15).abs();
    }
    cost /= (j - i + 1);
    if (cost < bestCost) {
      bestCost = cost;
      bestRun = (i, j);
    }
    i = j + 1;
  }
  if (bestRun == null) return null;
  // 너무 길면 가장 좋은 두 시간만
  var (a, b) = bestRun;
  if (b - a > 1) {
    var mid = a;
    double c = 1e9;
    for (var k = a; k < b; k++) {
      final cc = (((v[k].$1.feels ?? 15) - 15).abs() + ((v[k + 1].$1.feels ?? 15) - 15).abs());
      if (cc < c) {
        c = cc;
        mid = k;
      }
    }
    a = mid;
    b = mid + 1;
  }
  return (v[a].$1.t, v[b].$1.t.add(const Duration(hours: 1)), minLv);
}

WalkDay walkDay(WalkData d, WalkProfile p) {
  final now = _kst;
  final today = <(WalkHour, WalkJudge)>[];
  final tomorrow = <(WalkHour, WalkJudge)>[];
  WalkHour? cur;
  for (final h in d.hours) {
    final isToday = h.t.day == now.day;
    final j = judge(h, d.dust, p, useDust: isToday);
    cur ??= h;
    if (!_daytime(h.t)) continue;
    (isToday ? today : tomorrow).add((h, j));
  }
  final nowJ = cur == null ? null : judge(cur, d.dust, p);

  // 팁 — 오늘 남은 낮 시간을 보고 많아야 세 줄
  final tips = <(String, String)>[];
  final span = today.isNotEmpty ? today.map((x) => x.$1).toList() : [if (cur != null) cur];
  final minFeels = span.map((h) => h.feels).whereType<double>().fold<double?>(null, (a, b) => a == null ? b : math.min(a, b));
  final maxTemp = span.map((h) => h.temp).whereType<double>().fold<double?>(null, (a, b) => a == null ? b : math.max(a, b));
  final sunnyHot = span.any((h) => h.sky == 1 && (h.temp ?? 0) >= 25 && h.t.hour >= 11 && h.t.hour <= 16);
  if (span.any((h) => h.snow)) tips.add(('weather', '눈길 염화칼슘이 발바닥을 상하게 해요. 산책 뒤 미지근한 물로 발을 씻고 잘 말려 주세요.'));
  if (sunnyHot) tips.add(('weather', '한낮 아스팔트는 기온보다 훨씬 뜨거워요. 손등을 5초 대 보고 뜨거우면 그늘길·흙길로 가세요.'));
  if (maxTemp != null && maxTemp >= 25) tips.add(('pet', '물과 접는 그릇을 챙기고, 혀를 길게 내밀고 헐떡이면 바로 그늘에서 쉬게 해 주세요.'));
  if (minFeels != null && minFeels <= 5 && (p.size == DogSize.small || p.senior)) {
    tips.add(('pet', '${p.who.isEmpty ? '작은 아이' : p.who}는 추위를 많이 타요. 옷을 입히고 해가 있는 낮에 짧게 다녀오세요.'));
  } else if (minFeels != null && minFeels <= 0) {
    tips.add(('pet', '추운 날엔 산책 시간을 줄이고, 다녀와서 발 사이 눈·얼음을 털어 주세요.'));
  }
  if (d.dust >= 3) tips.add(('weather', '미세먼지가 나빠요. 짧게 다녀오고 산책 뒤 얼굴·발을 물티슈로 닦아 주세요.'));
  if (span.any((h) => h.wet) || span.any((h) => h.pop >= 60)) tips.add(('weather', '비 소식이 있어요. 비옷을 입히거나 비가 그친 사이에 다녀오고 털을 바싹 말려 주세요.'));
  if (span.any((h) => h.wind >= 7)) tips.add(('weather', '바람이 세요. 소리에 놀라 뛰쳐나갈 수 있으니 줄을 짧게 잡아 주세요.'));
  if (p.flat && maxTemp != null && maxTemp >= 20) tips.add(('pet', '코가 짧은 아이는 숨이 쉽게 차요. 천천히 걷고 자주 쉬어 주세요.'));
  if (tips.isEmpty) tips.add(('pet', '걷기 좋은 날이에요. 새로운 길로 냄새 맡기 산책을 해 보세요. 머리를 쓰는 산책이 더 지치게 해요.'));

  return WalkDay(
    now: cur,
    nowJudge: nowJ,
    today: today,
    tomorrow: tomorrow,
    best: _bestRun(today),
    bestTomorrow: _bestRun(tomorrow),
    tips: tips.take(3).toList(),
  );
}

String hourText(DateTime t) {
  final h = t.hour;
  if (h == 0) return '밤 12시';
  if (h < 12) return '오전 $h시';
  if (h == 12) return '낮 12시';
  return '오후 ${h - 12}시';
}

String runText((DateTime, DateTime, int) r) {
  final a = r.$1, b = r.$2;
  final ah = a.hour, bh = b.hour;
  final pre = ah < 12 && bh <= 12 ? '오전 ' : (ah >= 12 ? '오후 ' : '');
  String n(int h) => '${h > 12 ? h - 12 : h}';
  return pre.isEmpty ? '${hourText(a)}~${hourText(b)}' : '$pre${n(ah)}~${n(bh)}시';
}

// ---------------- 화면 ----------------

class PetWalkPage extends StatefulWidget {
  final Complex complex;
  const PetWalkPage({super.key, required this.complex});
  @override
  State<PetWalkPage> createState() => _PetWalkPageState();
}

class _PetWalkPageState extends State<PetWalkPage> {
  WalkProfile prof = WalkProfile();
  WalkData? data;
  bool loading = true, failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      loading = true;
      failed = false;
    });
    final r = await Future.wait([walkProfile(), walkData(widget.complex, force: force)]);
    if (!mounted) return;
    setState(() {
      prof = r[0] as WalkProfile;
      data = r[1] as WalkData?;
      failed = data == null;
      loading = false;
    });
  }

  Future<void> _pick() async {
    final p = WalkProfile(size: prof.size, flat: prof.flat, senior: prof.senior);
    final ok = await showSheet<bool>(
        context,
        (ctx) => StatefulBuilder(
            builder: (ctx, set) => Padding(
                  padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 20),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const MixTitle('우리 아이', '기준', size: 16),
                    const SizedBox(height: 4),
                    Text('크기·코 모양·나이에 따라 더위·추위 기준이 달라져요.', style: T.small),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in DogSize.values) ChoiceChipBox(kDogSizeText[s]!, on: p.size == s, onTap: () => set(() => p.size = s)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChipBox('코가 짧은 견종 (퍼그·불독·시츄 등)', on: p.flat, onTap: () => set(() => p.flat = !p.flat)),
                      ChoiceChipBox('8살 넘음', on: p.senior, onTap: () => set(() => p.senior = !p.senior)),
                    ]),
                    const SizedBox(height: 18),
                    Btn('이 기준으로 보기', primary: true, onTap: () => Navigator.pop(ctx, true)),
                  ]),
                )));
    if (ok != true) return;
    await prefSet('pet.walk', jsonEncode(p.toJson()));
    setState(() => prof = p);
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final day = d == null ? null : walkDay(d, prof);
    return DetailPage(
      title: '오늘의 산책',
      icon: 'pet',
      white: false,
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
          if (onlyCats) ...[
            _Note('고양이는 집 안 사냥 놀이가 산책을 대신해요. 아래 지수는 강아지 기준이에요.'),
            const SizedBox(height: 12),
          ],
          if (loading && d == null)
            const _Skeleton()
          else if (day == null)
            _Note(failed ? '날씨 자료를 받지 못했어요. 아래로 당겨 다시 받아 주세요.' : '자료가 없어요.')
          else ...[
            _Hero(day: day, data: d!, prof: prof, onPick: prof.who.isEmpty ? _pick : null),
            const SizedBox(height: 14),
            _Hours(title: ('오늘', '시간별'), list: day.today, best: day.best, empty: '오늘 낮 산책 시간이 지났어요. 내일을 봐 주세요.'),
            const SizedBox(height: 14),
            _Tips(tips: day.tips),
            const SizedBox(height: 14),
            _Hours(title: ('내일', '미리 보기'), list: day.tomorrow, best: day.bestTomorrow, empty: '내일 예보가 아직 없어요.', compact: true),
            const SizedBox(height: 16),
            Text(
                '기상청 단기예보 · 에어코리아${d.station.isEmpty ? '' : ' ${d.station} 측정소'} · ${_2(d.at.hour)}:${_2(d.at.minute)} 받음\n'
                '일반적인 수의학 권고를 바탕으로 한 참고 지수예요. 아이 건강 상태에 따라 다를 수 있어요.',
                style: T.tiny),
          ],
        ]),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.all(16),
        child: Text(text, style: T.body),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 190,
        decoration: cardBox(),
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

// 맨 위 — 지금 단계 + 반원 눈금 + 추천 시간
class _Hero extends StatelessWidget {
  final WalkDay day;
  final WalkData data;
  final WalkProfile prof;
  final VoidCallback? onPick;
  const _Hero({required this.day, required this.data, required this.prof, this.onPick});

  @override
  Widget build(BuildContext context) {
    final j = day.nowJudge;
    final h = day.now;
    final lv = j?.level ?? 0;
    final best = day.best;
    final f = h?.feels, t = h?.temp;
    final line = [
      if (t != null) '지금 ${t.round()}℃',
      if (f != null && t != null && (f - t).abs() >= 1) '체감 ${f.round()}℃',
      if (data.dustText.isNotEmpty) data.dustText,
    ].join(' · ');
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(prof.who.isEmpty ? '${prof.label} 기준' : '${prof.who} 기준 · ${prof.label}', style: T.small)),
          if (onPick != null)
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text('기준 바꾸기', style: TextStyle(fontSize: 11.5, color: kBlue, fontWeight: FontWeight.w600))),
            ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '지금 산책  ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300, color: kInk)),
                TextSpan(text: kWalkShort[lv], style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, color: lv == 0 ? kBlue : kInk)),
              ])),
              const SizedBox(height: 2),
              if (j != null && j.why.isNotEmpty) Text(j.why.take(2).join(' · '), style: const TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (line.isNotEmpty) Text(line, style: T.small),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 96, height: 58, child: CustomPaint(painter: _Gauge(lv))),
        ]),
        const SizedBox(height: 14),
        Container(height: 1, color: kLine),
        const SizedBox(height: 12),
        Row(children: [
          const LineIcon('weather', size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: best == null
                ? Text('오늘 낮 산책 시간은 지났어요', style: T.body)
                : Text.rich(TextSpan(children: [
                    const TextSpan(text: '추천 시간  ', style: TextStyle(fontSize: 13, color: kSub)),
                    TextSpan(text: runText(best), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    TextSpan(text: '  ${kWalkShort[best.$3]}', style: const TextStyle(fontSize: 12.5, color: kSub)),
                  ])),
          ),
        ]),
      ]),
    );
  }
}

// 반원 눈금 — 네 칸, 지금 단계만 채움 (좋음은 파랑, 나머지는 진한 회색)
class _Gauge extends CustomPainter {
  final int level;
  _Gauge(this.level);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 4);
    final r = math.min(size.width / 2, size.height) - 6;
    const gap = 0.06;
    final seg = (math.pi - gap * 3) / 4;
    for (var i = 0; i < 4; i++) {
      final start = math.pi + i * (seg + gap);
      final on = i == level;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 9 : 7
        ..strokeCap = StrokeCap.butt
        ..color = on ? (level == 0 ? kBlue : kInk) : const Color(0xFFE6EAF0);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, seg, false, p);
    }
    // 바늘 끝 점
    final a = math.pi + level * (seg + gap) + seg / 2;
    final tip = c + Offset(math.cos(a), math.sin(a)) * (r - 14);
    canvas.drawLine(c, tip, Paint()
      ..color = kInk
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 3.5, Paint()..color = kInk);
  }

  @override
  bool shouldRepaint(_Gauge o) => o.level != level;
}

// 시간별 막대 — 좋을수록 키가 크고, 추천 시간대만 파랑 (휴대폰에서는 옆으로 밀기)
class _Hours extends StatelessWidget {
  final (String, String) title;
  final List<(WalkHour, WalkJudge)> list;
  final (DateTime, DateTime, int)? best;
  final String empty;
  final bool compact;
  const _Hours({required this.title, required this.list, required this.best, required this.empty, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final b = best;
    bool inBest(DateTime t) => b != null && !t.isBefore(b.$1) && t.isBefore(b.$2);
    final barMax = compact ? 34.0 : 52.0;
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MixTitle(title.$1, title.$2, size: 14.5),
          const Spacer(),
          if (b != null) Text('추천 ${runText(b)}', style: const TextStyle(fontSize: 11.5, color: kBlue, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Text(empty, style: T.small)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (h, j) in list)
                SizedBox(
                  width: 40,
                  child: Column(children: [
                    if (!compact) Text(h.temp == null ? '' : '${h.temp!.round()}°', style: TextStyle(fontSize: 11, color: inBest(h.t) ? kBlue : kSub, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: barMax,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 14,
                          height: barMax * (4 - j.level) / 4,
                          decoration: BoxDecoration(
                            color: inBest(h.t) ? kBlue : (j.level >= 3 ? const Color(0xFFE6EAF0) : const Color(0xFFC9D0DB)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('${h.t.hour}시', style: TextStyle(fontSize: 10.5, color: inBest(h.t) ? kBlue : kSub, fontWeight: inBest(h.t) ? FontWeight.w700 : FontWeight.w400)),
                    if (!compact) ...[
                      const SizedBox(height: 1),
                      Text(kWalkShort[j.level], style: const TextStyle(fontSize: 10, color: kMute)),
                    ],
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _Tips extends StatelessWidget {
  final List<(String, String)> tips;
  const _Tips({required this.tips});
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const MixTitle('오늘의', '산책 팁', size: 14.5),
          const SizedBox(height: 6),
          for (final (ic, t) in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LineIcon(ic, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: const TextStyle(fontSize: 13, height: 1.4))),
              ]),
            ),
        ]),
      );
}
