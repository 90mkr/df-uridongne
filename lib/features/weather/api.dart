// 날씨·미세먼지 자료 받기 (이 폴더는 날씨 담당 방만 고침)
//
//  ─ 날씨: 기상청 단기예보 (초단기실황 = 지금, 단기예보 = 시간별·오늘~모레)
//      단지 위경도 → 기상청 격자(nx, ny)로 바꿔 부른다. 같은 격자는 30분 안에 다시 부르지 않는다.
//  ─ 미세먼지: 에어코리아 (가까운 측정소 실시간 + 내일 예보 등급)
//      측정소 위치는 collector/features/weather.py 가 미리 모아 둔 web/data/weather/stations.json
//      (없으면 시·도 전체 측정소 중 동네 이름이 맞는 곳)
//  ─ 크롬 미리보기(웹)에서 공공데이터 서버가 막히면 미리보기용 대체 자료(Open-Meteo)로 보여 준다.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/keys.dart';

// ---------------- 모양 ----------------

enum Sky { clear, partly, cloudy, overcast, rain, snow, sleet, shower }

String skyText(Sky s) => switch (s) {
      Sky.clear => '맑음',
      Sky.partly => '구름 조금',
      Sky.cloudy => '구름 많음',
      Sky.overcast => '흐림',
      Sky.rain => '비',
      Sky.snow => '눈',
      Sky.sleet => '비 또는 눈',
      Sky.shower => '소나기',
    };

bool isWet(Sky s) => s == Sky.rain || s == Sky.snow || s == Sky.sleet || s == Sky.shower;

class Hour {
  final DateTime t;
  final double? temp;
  final Sky sky;
  final int? pop; // 강수확률 %
  final String rain; // 강수량 글 (예: '1mm')
  final int? hum;
  final double? wind;
  const Hour(this.t, {this.temp, this.sky = Sky.clear, this.pop, this.rain = '', this.hum, this.wind});
}

class Day {
  final DateTime date;
  double? min, max;
  Sky am = Sky.clear, pm = Sky.clear;
  int popAm = 0, popPm = 0;
  Day(this.date);
  int get pop => math.max(popAm, popPm);
}

class Dust {
  final String station; // 측정소 이름
  final String time; // 측정 시각 글
  final int? pm10, pm25, o3x1000; // 오존은 ppm×1000
  final int g10, g25, gO3; // 1 좋음 ~ 4 매우나쁨, 0 모름
  final int tomorrow10, tomorrow25; // 내일 예보 등급
  final bool approx; // 대체 자료(모델 추정)
  const Dust({
    this.station = '',
    this.time = '',
    this.pm10,
    this.pm25,
    this.o3x1000,
    this.g10 = 0,
    this.g25 = 0,
    this.gO3 = 0,
    this.tomorrow10 = 0,
    this.tomorrow25 = 0,
    this.approx = false,
  });
  int get worst => math.max(g10, g25);
  Dust withTomorrow(int t10, int t25) => Dust(
      station: station, time: time, pm10: pm10, pm25: pm25, o3x1000: o3x1000, g10: g10, g25: g25, gO3: gO3, tomorrow10: t10, tomorrow25: t25, approx: approx);
}

class Weather {
  final double? temp; // 지금 기온
  final Sky sky;
  final int? hum;
  final double? wind;
  final double? rain1h; // 1시간 강수량 mm
  final List<Hour> hours; // 지금부터 시간별
  final List<Day> days; // 오늘·내일·모레
  final Dust? dust;
  final DateTime at; // 받은 시각
  final String source; // '기상청' 또는 '미리보기용 대체 자료'
  const Weather({
    this.temp,
    this.sky = Sky.clear,
    this.hum,
    this.wind,
    this.rain1h,
    this.hours = const [],
    this.days = const [],
    this.dust,
    required this.at,
    this.source = '기상청',
  });

  Day? get today => days.isEmpty ? null : days.first;
  Day? get tomorrow => days.length < 2 ? null : days[1];

  // 체감온도 (기상청 겨울철 식, 10℃ 이하·바람 1.3m/s 이상일 때만)
  double? get feels {
    final t = temp, w = wind;
    if (t == null) return null;
    if (w == null || t > 10 || w < 1.3) return t;
    final v = math.pow(w * 3.6, 0.16);
    return 13.12 + 0.6215 * t - 11.37 * v + 0.3965 * v * t;
  }
}

// ---------------- 등급 ----------------

const gradeText = ['-', '좋음', '보통', '나쁨', '매우나쁨'];

int grade10(int? v) => v == null ? 0 : (v <= 30 ? 1 : v <= 80 ? 2 : v <= 150 ? 3 : 4);
int grade25(int? v) => v == null ? 0 : (v <= 15 ? 1 : v <= 35 ? 2 : v <= 75 ? 3 : 4);

// ---------------- 기상청 격자 ----------------

({int nx, int ny}) kmaGrid(double lat, double lng) {
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

// ---------------- 받기 공통 ----------------

DateTime get _nowKst => DateTime.now().toUtc().add(const Duration(hours: 9));
String _ymd(DateTime t) => '${t.year}${_2(t.month)}${_2(t.day)}';
String _2(int v) => v.toString().padLeft(2, '0');

String get _key {
  final k = kDataGoKrKey.trim();
  return k.contains('%') ? k : Uri.encodeQueryComponent(k); // 「인코딩」 열쇠·「디코딩」 열쇠 모두 받기
}

String get _airKey {
  final k = (kAirKoreaKey.isNotEmpty ? kAirKoreaKey : kDataGoKrKey).trim();
  return k.contains('%') ? k : Uri.encodeQueryComponent(k);
}

Future<dynamic> _get(String url) async {
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final body = utf8.decode(r.bodyBytes);
    if (!body.trimLeft().startsWith('{')) return null; // 열쇠 오류 등은 XML로 옴
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

List _items(dynamic j) {
  try {
    final b = j['response']['body'];
    final it = b['items'];
    if (it is List) return it;
    final x = it['item'];
    return x is List ? x : (x == null ? const [] : [x]);
  } catch (_) {
    return const [];
  }
}

// ---------------- 기상청 ----------------

Sky _sky(int? sky, int? pty) {
  switch (pty) {
    case 1:
    case 5:
      return Sky.rain;
    case 2:
    case 6:
      return Sky.sleet;
    case 3:
    case 7:
      return Sky.snow;
    case 4:
      return Sky.shower;
  }
  return switch (sky) { 3 => Sky.cloudy, 4 => Sky.overcast, 2 => Sky.partly, _ => Sky.clear };
}

double? _num(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  if (s.isEmpty || s == '-' || s.contains('없음')) return null;
  return double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

// 단기예보 발표: 02·05·08·11·14·17·20·23시 (10분 뒤부터 받을 수 있어 15분 여유)
({String date, String time}) _fcstBase(DateTime now) {
  final t = now.subtract(const Duration(minutes: 15));
  const hs = [23, 20, 17, 14, 11, 8, 5, 2];
  for (final h in hs) {
    if (t.hour >= h) return (date: _ymd(t), time: '${_2(h)}00');
  }
  return (date: _ymd(t.subtract(const Duration(days: 1))), time: '2300');
}

Future<Weather?> _kma(LatLng p) async {
  if (kDataGoKrKey.isEmpty) return null;
  final g = kmaGrid(p.latitude, p.longitude);
  final now = _nowKst;
  const base = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0';
  String q(String op, String d, String t, int rows) =>
      '$base/$op?serviceKey=$_key&pageNo=1&numOfRows=$rows&dataType=JSON&base_date=$d&base_time=$t&nx=${g.nx}&ny=${g.ny}';

  // 지금 (초단기실황: 매시 정각 자료, 40분쯤 뒤 나옴)
  final nt = now.subtract(const Duration(minutes: 45));
  final fb = _fcstBase(now);
  // 오늘 최저·최고는 새벽 2시 발표에만 다 들어 있어 따로 받는다
  final needEarly = now.hour >= 3 && !(fb.date == _ymd(now) && fb.time == '0200');

  final res = await Future.wait([
    _get(q('getUltraSrtNcst', _ymd(nt), '${_2(nt.hour)}00', 20)),
    _get(q('getVilageFcst', fb.date, fb.time, 1000)),
    if (needEarly) _get(q('getVilageFcst', _ymd(now), '0200', 1000)),
  ]);
  final ncst = _items(res[0]);
  final fc = _items(res[1]);
  if (ncst.isEmpty && fc.isEmpty) return null;

  // 지금
  final n = <String, double?>{for (final x in ncst) '${x['category']}': _num(x['obsrValue'])};

  // 시간별 묶기 (fcstDate+fcstTime)
  final slots = <String, Map<String, String>>{};
  void put(List items) {
    for (final x in items) {
      final k = '${x['fcstDate']}${x['fcstTime']}';
      (slots[k] ??= {})['${x['category']}'] = '${x['fcstValue']}';
    }
  }

  if (res.length > 2) put(_items(res[2])); // 새벽 발표 먼저, 최신 발표가 덮게
  put(fc);

  DateTime parse(String k) => DateTime(int.parse(k.substring(0, 4)), int.parse(k.substring(4, 6)), int.parse(k.substring(6, 8)), int.parse(k.substring(8, 10)));
  final keys = slots.keys.toList()..sort();
  final hours = <Hour>[];
  final days = <String, Day>{};
  final nowHour = DateTime(now.year, now.month, now.day, now.hour);
  for (final k in keys) {
    final s = slots[k]!;
    final t = parse(k);
    final sky = _sky(int.tryParse(s['SKY'] ?? ''), int.tryParse(s['PTY'] ?? ''));
    final pop = int.tryParse(s['POP'] ?? '');
    final dk = k.substring(0, 8);
    final day = days[dk] ??= Day(DateTime(t.year, t.month, t.day));
    final tmn = _num(s['TMN']), tmx = _num(s['TMX']), tmp = _num(s['TMP']);
    if (tmn != null) day.min = tmn;
    if (tmx != null) day.max = tmx;
    if (t.hour == 9) day.am = sky;
    if (t.hour == 15) day.pm = sky;
    if (pop != null) {
      if (t.hour < 12) day.popAm = math.max(day.popAm, pop);
      if (t.hour >= 12) day.popPm = math.max(day.popPm, pop);
    }
    if (!t.isBefore(nowHour) && hours.length < 30) {
      final pcp = s['PCP'] ?? '';
      hours.add(Hour(t, temp: tmp, sky: sky, pop: pop, rain: pcp.contains('없음') ? '' : pcp, hum: int.tryParse(s['REH'] ?? ''), wind: _num(s['WSD'])));
    }
  }
  // 최저·최고가 비면 시간별 기온으로 채움
  for (final dk in days.keys) {
    final d = days[dk]!;
    final ts = [for (final k in keys) if (k.startsWith(dk)) _num(slots[k]!['TMP'])].whereType<double>().toList();
    if (ts.isEmpty) continue;
    d.min ??= ts.reduce(math.min);
    d.max ??= ts.reduce(math.max);
  }
  final dl = days.values.where((d) => !d.date.isBefore(DateTime(now.year, now.month, now.day))).take(3).toList();

  final first = hours.isEmpty ? null : hours.first;
  final ptyNow = n['PTY']?.round() ?? 0;
  // 지금 하늘: 비·눈이 오는 중이면 실황, 아니면 이번 시간 예보의 하늘 모양(구름)만
  final firstKey = keys.where((k) => !parse(k).isBefore(nowHour)).firstOrNull;
  final skyNow = ptyNow > 0 ? _sky(null, ptyNow) : _sky(int.tryParse(firstKey == null ? '' : (slots[firstKey]!['SKY'] ?? '')), 0);
  return Weather(
    temp: n['T1H'] ?? first?.temp,
    sky: skyNow,
    hum: n['REH']?.round() ?? first?.hum,
    wind: n['WSD'] ?? first?.wind,
    rain1h: n['RN1'],
    hours: hours,
    days: dl,
    at: now,
  );
}

// ---------------- 에어코리아 ----------------

class _Station {
  final String name;
  final double lat, lng;
  const _Station(this.name, this.lat, this.lng);
}

List<_Station>? _stations;

Future<List<_Station>> _loadStations() async {
  if (_stations != null) return _stations!;
  final j = await getJson('${dataBase}weather/stations.json');
  final out = <_Station>[];
  if (j is Map) {
    for (final s in (j['stations'] as List? ?? const [])) {
      if (s is Map && s['y'] != null && s['x'] != null) out.add(_Station('${s['n']}', (s['y'] as num).toDouble(), (s['x'] as num).toDouble()));
    }
  }
  _stations = out;
  return out;
}

int? _int(dynamic v) => _num(v)?.round();

Dust? _dustFrom(Map x, String station) {
  final p10 = _int(x['pm10Value']), p25 = _int(x['pm25Value']);
  if (p10 == null && p25 == null) return null;
  final o3 = _num(x['o3Value']);
  return Dust(
    station: station,
    time: '${x['dataTime'] ?? ''}',
    pm10: p10,
    pm25: p25,
    o3x1000: o3 == null ? null : (o3 * 1000).round(),
    g10: _int(x['pm10Grade1h']) ?? _int(x['pm10Grade']) ?? grade10(p10),
    g25: _int(x['pm25Grade1h']) ?? _int(x['pm25Grade']) ?? grade25(p25),
    gO3: _int(x['o3Grade']) ?? 0,
  );
}

const _air = 'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc';

Future<Dust?> _airkorea(LatLng p, Complex c) async {
  if (kDataGoKrKey.isEmpty && kAirKoreaKey.isEmpty) return null;
  // 1) 가까운 측정소부터 (값이 비면 다음 측정소)
  final st = await _loadStations();
  if (st.isNotEmpty) {
    final near = [...st]..sort((a, b) => meters(p, LatLng(a.lat, a.lng)).compareTo(meters(p, LatLng(b.lat, b.lng))));
    for (final s in near.take(3)) {
      final j = await _get('$_air/getMsrstnAcctoRltmMesureDnsty?serviceKey=$_airKey&returnType=json&numOfRows=1&pageNo=1'
          '&stationName=${Uri.encodeQueryComponent(s.name)}&dataTerm=DAILY&ver=1.3');
      final it = _items(j);
      if (it.isEmpty) continue;
      final d = _dustFrom(it.first as Map, s.name);
      if (d != null) return d;
    }
  }
  // 2) 측정소 위치가 없으면 시·도 전체에서 동네 이름이 맞는 곳
  final sido = c.area?.sido ?? '';
  if (sido.isEmpty) return null;
  final j = await _get('$_air/getCtprvnRltmMesureDnsty?serviceKey=$_airKey&returnType=json&numOfRows=200&pageNo=1'
      '&sidoName=${Uri.encodeQueryComponent(sido)}&ver=1.3');
  final it = _items(j).whereType<Map>().toList();
  if (it.isEmpty) return null;
  final words = <String>{
    ...?c.area?.name.split('/'),
    if ((c.area?.gu ?? '').isNotEmpty) c.area!.gu.replaceAll(RegExp(r'[구군시]$'), ''),
    ...c.addr.split(' ').where((w) => w.endsWith('동')).map((w) => w.replaceAll(RegExp(r'\d*동$'), '')),
  }..removeWhere((w) => w.length < 2);
  Map? pick;
  for (final w in words) {
    pick = it.where((x) => '${x['stationName']}'.contains(w) && _num(x['pm10Value']) != null).firstOrNull;
    if (pick != null) break;
  }
  pick ??= it.where((x) => _num(x['pm10Value']) != null).firstOrNull;
  return pick == null ? null : _dustFrom(pick, '${pick['stationName']}');
}

// 내일 예보 등급 (「인천 : 보통,서울 : 좋음 …」 글에서 시·도 찾기)
Future<(int, int)> _dustTomorrow(String sido) async {
  if (sido.isEmpty || (kDataGoKrKey.isEmpty && kAirKoreaKey.isEmpty)) return (0, 0);
  final now = _nowKst;
  final tm = now.add(const Duration(days: 1));
  final tmText = '${tm.year}-${_2(tm.month)}-${_2(tm.day)}';
  Future<int> one(String code) async {
    // 오늘 발표분에 내일 예보가 들어 있다 (새벽 5시 전이면 어제 발표분)
    final sd = now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
    final j = await _get('$_air/getMinuDustFrcstDspth?serviceKey=$_airKey&returnType=json&numOfRows=100&pageNo=1'
        '&searchDate=${sd.year}-${_2(sd.month)}-${_2(sd.day)}&InformCode=$code');
    final it = _items(j).whereType<Map>().where((x) => '${x['informData']}' == tmText).toList()
      ..sort((a, b) => '${b['dataTime']}'.compareTo('${a['dataTime']}'));
    if (it.isEmpty) return 0;
    final m = RegExp('$sido\\s*:\\s*(좋음|보통|나쁨|매우나쁨)').firstMatch('${it.first['informGrade']}');
    return m == null ? 0 : gradeText.indexOf(m.group(1)!);
  }

  final r = await Future.wait([one('PM10'), one('PM25')]);
  return (r[0], r[1]);
}

// ---------------- 미리보기용 대체 자료 (웹에서 공공데이터가 막힐 때만) ----------------

Sky _wmo(int? c) {
  if (c == null) return Sky.clear;
  if (c == 0) return Sky.clear;
  if (c <= 2) return Sky.partly;
  if (c == 3) return Sky.overcast;
  if (c >= 45 && c <= 48) return Sky.overcast;
  if (c >= 71 && c <= 77 || c == 85 || c == 86) return Sky.snow;
  if (c == 66 || c == 67) return Sky.sleet;
  if (c >= 80 && c <= 82 || c >= 95) return Sky.shower;
  return Sky.rain;
}

Future<Weather?> _openMeteo(LatLng p) async {
  final lat = p.latitude.toStringAsFixed(4), lng = p.longitude.toStringAsFixed(4);
  final r = await Future.wait([
    _get('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&timezone=Asia%2FSeoul&forecast_days=3&wind_speed_unit=ms'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation'
        '&hourly=temperature_2m,precipitation_probability,weather_code,relative_humidity_2m,wind_speed_10m,precipitation'
        '&daily=temperature_2m_min,temperature_2m_max'),
    _get('https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lng&timezone=Asia%2FSeoul&current=pm10,pm2_5,ozone'
        '&hourly=pm10,pm2_5&forecast_days=2'),
  ]);
  final w = r[0];
  if (w is! Map || w['current'] == null) return null;
  final cur = w['current'] as Map;
  final h = (w['hourly'] as Map?) ?? const {};
  final ht = (h['time'] as List?) ?? const [];
  final now = _nowKst;
  final nowHour = DateTime(now.year, now.month, now.day, now.hour);
  final hours = <Hour>[];
  final days = <String, Day>{};
  for (var i = 0; i < ht.length; i++) {
    final t = DateTime.parse('${ht[i]}');
    final sky = _wmo((h['weather_code'] as List)[i] as int?);
    final pop = ((h['precipitation_probability'] as List?)?[i] as num?)?.round();
    final dk = _ymd(t);
    final d = days[dk] ??= Day(DateTime(t.year, t.month, t.day));
    if (t.hour == 9) d.am = sky;
    if (t.hour == 15) d.pm = sky;
    if (pop != null) {
      if (t.hour < 12) d.popAm = math.max(d.popAm, pop);
      if (t.hour >= 12) d.popPm = math.max(d.popPm, pop);
    }
    if (!t.isBefore(nowHour) && hours.length < 30) {
      final mm = ((h['precipitation'] as List?)?[i] as num?)?.toDouble() ?? 0;
      hours.add(Hour(t,
          temp: ((h['temperature_2m'] as List)[i] as num?)?.toDouble(),
          sky: sky,
          pop: pop,
          rain: mm >= 0.1 ? '${mm < 1 ? '1mm 미만' : '${mm.round()}mm'}' : '',
          hum: ((h['relative_humidity_2m'] as List?)?[i] as num?)?.round(),
          wind: ((h['wind_speed_10m'] as List?)?[i] as num?)?.toDouble()));
    }
  }
  final dd = (w['daily'] as Map?) ?? const {};
  final dt = (dd['time'] as List?) ?? const [];
  for (var i = 0; i < dt.length; i++) {
    final d = days[_ymd(DateTime.parse('${dt[i]}'))];
    if (d == null) continue;
    d.min = ((dd['temperature_2m_min'] as List)[i] as num?)?.toDouble();
    d.max = ((dd['temperature_2m_max'] as List)[i] as num?)?.toDouble();
  }
  Dust? dust;
  final a = r[1];
  if (a is Map && a['current'] is Map) {
    final ac = a['current'] as Map;
    final p10 = (ac['pm10'] as num?)?.round(), p25 = (ac['pm2_5'] as num?)?.round();
    // 내일 등급: 내일 하루 평균으로
    var t10 = 0, t25 = 0;
    final ah = (a['hourly'] as Map?) ?? const {};
    final at = (ah['time'] as List?) ?? const [];
    final tm = _ymd(now.add(const Duration(days: 1)));
    final v10 = <num>[], v25 = <num>[];
    for (var i = 0; i < at.length; i++) {
      if (_ymd(DateTime.parse('${at[i]}')) != tm) continue;
      final x = (ah['pm10'] as List)[i], y = (ah['pm2_5'] as List)[i];
      if (x is num) v10.add(x);
      if (y is num) v25.add(y);
    }
    if (v10.isNotEmpty) t10 = grade10((v10.reduce((s, e) => s + e) / v10.length).round());
    if (v25.isNotEmpty) t25 = grade25((v25.reduce((s, e) => s + e) / v25.length).round());
    dust = Dust(station: '', pm10: p10, pm25: p25, g10: grade10(p10), g25: grade25(p25), tomorrow10: t10, tomorrow25: t25, approx: true);
  }
  return Weather(
    temp: (cur['temperature_2m'] as num?)?.toDouble(),
    sky: _wmo(cur['weather_code'] as int?),
    hum: (cur['relative_humidity_2m'] as num?)?.round(),
    wind: (cur['wind_speed_10m'] as num?)?.toDouble(),
    rain1h: (cur['precipitation'] as num?)?.toDouble(),
    hours: hours,
    days: days.values.take(3).toList(),
    dust: dust,
    at: now,
    source: '미리보기용 대체 자료',
  );
}

// ---------------- 바깥에서 쓰는 곳 ----------------

final Map<String, Weather> _cache = {};
final Map<String, Future<Weather?>> _loading = {};

// 같은 격자는 30분 안에 다시 부르지 않는다 (force 면 5분)
Future<Weather?> weatherFor(Complex c, {bool force = false}) {
  final g = kmaGrid(c.lat, c.lng);
  final k = '${g.nx}_${g.ny}';
  final have = _cache[k];
  final keep = force ? const Duration(minutes: 5) : const Duration(minutes: 30);
  if (have != null && _nowKst.difference(have.at) < keep) return Future.value(have);
  return _loading[k] ??= _fetchSafe(c).whenComplete(() => _loading.remove(k)).then((w) {
    if (w != null) _cache[k] = w;
    return w ?? have;
  });
}

Weather? cachedWeather(Complex c) {
  final g = kmaGrid(c.lat, c.lng);
  return _cache['${g.nx}_${g.ny}'];
}

String lastWeatherError = '';

Future<Weather?> _fetchSafe(Complex c) async {
  try {
    lastWeatherError = '';
    return await _fetch(c).timeout(const Duration(seconds: 40));
  } catch (e, st) {
    lastWeatherError = '$e';
    // ignore: avoid_print
    print('[날씨] $e\n$st');
    return null;
  }
}

// 부분 실패는 다른 자료를 막지 않게 하나씩 감싼다
Future<T?> _safe<T>(Future<T?> f, String what) async {
  try {
    return await f.timeout(const Duration(seconds: 30));
  } catch (e) {
    // ignore: avoid_print
    print('[날씨] $what: $e');
    return null;
  }
}

Future<Weather?> _fetch(Complex c) async {
  final p = c.pos;
  final kma = _safe(_kma(p), '기상청');
  final air = _safe(_airkorea(p, c), '에어코리아');
  final fc = _safe(_dustTomorrow(c.area?.sido ?? ''), '미세먼지 예보');
  var w = await kma;
  var d = await air;
  final tm = await fc ?? (0, 0);
  if (d != null) d = d.withTomorrow(tm.$1, tm.$2);
  if (w == null && kIsWeb) {
    final o = await _openMeteo(p);
    if (o != null) {
      return Weather(
          temp: o.temp, sky: o.sky, hum: o.hum, wind: o.wind, rain1h: o.rain1h, hours: o.hours, days: o.days, dust: d ?? o.dust, at: o.at, source: o.source);
    }
  }
  if (w == null) return null;
  if (d == null && kIsWeb) d = (await _openMeteo(p))?.dust;
  return Weather(temp: w.temp, sky: w.sky, hum: w.hum, wind: w.wind, rain1h: w.rain1h, hours: w.hours, days: w.days, dust: d, at: w.at, source: w.source);
}
