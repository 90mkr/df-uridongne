// 지하철 자료 (지하철 담당: 본부, 대표님 요청 11-24)
// web/data/subway/st_<동네>.json — 동네 지하철역 위치 + 역별 시간표 (collector/features/subway.py 가 주 1회 모음)
// 인천1·2호선은 실시간 도착이 공개되지 않아 「시간표 기준」으로 다음 열차를 계산한다.
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

class Departure {
  final int mins; // 지금부터 몇 분 뒤
  final String hhmm, end; // 출발 시각 「0532」, 종착역
  const Departure(this.mins, this.hhmm, this.end);
  String get minsText => mins <= 0 ? '곧 출발' : '$mins분';
  String get clock => '${hhmm.substring(0, 2)}:${hhmm.substring(2, 4)}';
}

class Station {
  final String name, line, id;
  final LatLng pos;
  final Map<String, List<(String, String)>> tt; // 「01U」 → [(hhmm, 종착)]
  const Station({required this.name, required this.line, required this.id, required this.pos, required this.tt});

  bool get hasTable => tt.isNotEmpty;

  // 이 역에서 떠나는 방향만 (끝역은 한 방향뿐 — 송도달빛축제공원·인천 등)
  List<String> get dirs => [for (final ud in ['U', 'D']) if (tt.keys.any((k) => k.endsWith(ud))) ud];

  // 오늘 요일 구분: 01 평일 · 02 토요일 · 03 일요일(공휴일도 일요일 시간표)
  static String dayCode(DateTime now) => now.weekday == DateTime.saturday ? '02' : (now.weekday == DateTime.sunday ? '03' : '01');

  /// 방향(U 상행 · D 하행)별 지금 이후 열차 n대
  List<Departure> next(String ud, DateTime now, {int n = 3}) {
    final list = tt['${dayCode(now)}$ud'] ?? tt['01$ud'] ?? const [];
    final cur = now.hour * 60 + now.minute;
    final out = <Departure>[];
    for (final (t, end) in list) {
      final m = int.tryParse(t.substring(0, 2))! * 60 + int.tryParse(t.substring(2, 4))!;
      if (m < cur) continue;
      out.add(Departure(m - cur, t, end));
      if (out.length >= n) break;
    }
    return out;
  }

  /// 방향 이름: 그 방향 막차 종착역 기준 「계양 방면」
  String towards(String ud, DateTime now) {
    final list = tt['${dayCode(now)}$ud'] ?? tt['01$ud'] ?? const [];
    if (list.isEmpty) return ud == 'U' ? '상행' : '하행';
    final counts = <String, int>{};
    for (final (_, e) in list) {
      if (e.isNotEmpty) counts[e] = (counts[e] ?? 0) + 1;
    }
    if (counts.isEmpty) return ud == 'U' ? '상행' : '하행';
    final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    return '${top.replaceAll(RegExp(r'역$'), '')} 방면';
  }

  /// 막차 시각
  String last(String ud, DateTime now) {
    final list = tt['${dayCode(now)}$ud'] ?? const [];
    if (list.isEmpty) return '';
    final t = list.last.$1;
    return '${t.substring(0, 2)}:${t.substring(2, 4)}';
  }
}

final Map<String, List<Station>> _cache = {};

Future<List<Station>> stationsOf(String areaId) async {
  if (areaId.isEmpty) return const [];
  final have = _cache[areaId];
  if (have != null) return have;
  final j = await getJson('${dataBase}subway/st_$areaId.json');
  final out = <Station>[];
  for (final x in (j is Map ? (j['st'] as List? ?? const []) : const [])) {
    if (x is! Map) continue;
    final lat = (x['y'] as num?)?.toDouble(), lng = (x['x'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    final tt = <String, List<(String, String)>>{};
    final raw = x['tt'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) {
          tt['$k'] = [
            for (final r in v)
              if (r is List && r.isNotEmpty && '${r[0]}'.length == 4) ('${r[0]}', r.length > 1 ? '${r[1]}' : ''),
          ];
        }
      });
    }
    out.add(Station(name: '${x['n'] ?? ''}', line: '${x['l'] ?? ''}', id: '${x['id'] ?? ''}', pos: LatLng(lat, lng), tt: tt));
  }
  _cache[areaId] = out;
  return out;
}

/// 단지에서 가까운 역 (같은 역 다른 호선은 따로), 최대 km 안
Future<List<Station>> nearStations(Complex c, {double km = 2}) async {
  final all = await stationsOf(c.areaId);
  final l = all.where((s) => meters(c.pos, s.pos) <= km * 1000).toList()..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
  return l;
}

String naverStationUrl(Station s) => 'https://m.map.naver.com/search2/search.naver?query=${Uri.encodeComponent('${s.name}역 ${s.line}')}';
