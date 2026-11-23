// 단지 앞 버스 — 자료 (이 폴더는 단지 앞 버스 담당 방만 고침)
//
// 국토교통부 TAGO (공공데이터포털, 열쇠 kDataGoKrKey) — 서울을 뺀 전국 시내버스
//   정류소정보    BusSttnInfoInqireService/getCrdntPrxmtSttnList        좌표 둘레 정류장
//   도착정보      ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList  정류장에 오는 버스
//   노선정보      BusRouteInfoInqireService/getRouteInfoIem              기점·종점·첫차·막차·배차
//                 BusRouteInfoInqireService/getRouteAcctoThrghSttnList    노선이 지나는 정류장
//   위치정보      BusLcInfoInqireService/getRouteAcctoBusLcList          노선 위 버스 위치
//
// 단지 둘레 정류장은 collector/features/bus.py 가 매주 미리 모아 web/data/bus/near_<동네>.json 에 둔다
// (크롬 미리보기에서도 정류장은 보이게). 없으면 앱이 바로 부른다.
// 실시간 자료는 같은 주소를 30초 안에 다시 부르지 않는다.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/keys.dart';

const _base = 'https://apis.data.go.kr/1613000';

// ---------------- 모양 ----------------
class Stop {
  final String id, name, no;
  final int city;
  final LatLng pos;
  const Stop({required this.id, required this.name, required this.no, required this.city, required this.pos});

  Map<String, dynamic> toJson() => {'i': id, 'n': name, 'no': no, 'c': city, 'y': pos.latitude, 'x': pos.longitude};
  static Stop? fromJson(dynamic j) {
    if (j is! Map || j['y'] == null || j['x'] == null || j['i'] == null) return null;
    return Stop(
      id: '${j['i']}',
      name: '${j['n'] ?? ''}',
      no: '${j['no'] ?? ''}',
      city: int.tryParse('${j['c']}') ?? 0,
      pos: LatLng((j['y'] as num).toDouble(), (j['x'] as num).toDouble()),
    );
  }
}

class Arrival {
  final String routeId, routeNo, type;
  final int secs; // 도착까지 초
  final int left; // 남은 정류장 수
  final String vehicle; // 저상버스 등
  const Arrival({required this.routeId, required this.routeNo, required this.type, required this.secs, required this.left, required this.vehicle});

  int get mins => (secs / 60).ceil();
  bool get soon => secs <= 120 || left <= 1;
  String get minsText => soon ? '곧 도착' : '$mins분';
  String get leftText => left <= 0 ? '정류장 도착' : '$left정거장 전';
  bool get lowFloor => vehicle.contains('저상');
}

class RouteInfo {
  final String id, no, type, start, end, first, last, gap;
  const RouteInfo({required this.id, required this.no, required this.type, required this.start, required this.end, required this.first, required this.last, required this.gap});
}

class RouteStop {
  final String id, name, no;
  final int ord, updown;
  final LatLng? pos;
  const RouteStop({required this.id, required this.name, required this.no, required this.ord, required this.updown, this.pos});
}

class BusOnRoute {
  final String nodeId, nodeName, vehicleNo;
  final int ord;
  final LatLng? pos;
  const BusOnRoute({required this.nodeId, this.nodeName = '', required this.vehicleNo, required this.ord, this.pos});
}

// ---------------- 부르기 ----------------
// 결과: 성공이면 item 목록(없으면 빈 목록), 실패면 null
enum BusErr { none, noKey, blocked, fail }

BusErr lastErr = BusErr.none;

final Map<String, (DateTime, List<Map>)> _cache = {};

String get _key => kDataGoKrKey.contains('%') ? kDataGoKrKey : Uri.encodeQueryComponent(kDataGoKrKey);

Future<List<Map>?> _call(String path, Map<String, String> q, {Duration keep = const Duration(seconds: 30), int retry = 1}) async {
  if (!hasDataKey) {
    lastErr = BusErr.noKey;
    return null;
  }
  final qs = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  final url = '$_base/$path?serviceKey=$_key&_type=json&$qs';
  final hit = _cache[url];
  if (hit != null && DateTime.now().difference(hit.$1) < keep) return hit.$2;
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      lastErr = BusErr.fail;
      return null;
    }
    final body = utf8.decode(r.bodyBytes).trim();
    if (!body.startsWith('{')) {
      lastErr = BusErr.fail; // 열쇠 오류 등은 XML 로 온다
      return null;
    }
    final j = jsonDecode(body);
    final resp = j is Map ? j['response'] : null;
    final head = resp is Map ? resp['header'] : null;
    final code = head is Map ? '${head['resultCode'] ?? ''}' : '';
    if (code == '99' && retry > 0) {
      // 동시 접속 한도 — 잠깐 쉬고 한 번 더
      await Future.delayed(const Duration(milliseconds: 1500));
      return await _call(path, q, keep: keep, retry: retry - 1);
    }
    if (code.isNotEmpty && code != '00' && code != '0') {
      lastErr = BusErr.fail;
      return null;
    }
    final bodyMap = resp is Map ? resp['body'] : null;
    final items = bodyMap is Map ? bodyMap['items'] : null;
    final it = items is Map ? items['item'] : null;
    final list = <Map>[];
    if (it is List) {
      list.addAll(it.whereType<Map>());
    } else if (it is Map) {
      list.add(it);
    }
    _cache[url] = (DateTime.now(), list);
    lastErr = BusErr.none;
    return list;
  } catch (_) {
    // 크롬 미리보기는 공공데이터 서버가 막혀(CORS) 여기로 온다
    lastErr = kIsWeb ? BusErr.blocked : BusErr.fail;
    return null;
  }
}

String _s(dynamic v) => v == null ? '' : '$v'.trim();
int _i(dynamic v) => int.tryParse(_s(v)) ?? 0;
double? _d(dynamic v) => double.tryParse(_s(v));

String _hm(dynamic v) {
  if (_s(v).isEmpty) return '';
  final s = _s(v).padLeft(4, '0');
  if (s.length < 4) return '';
  return '${s.substring(0, 2)}:${s.substring(2, 4)}';
}

String routeTypeShort(String t) {
  final s = t.replaceAll('버스', '').trim();
  return s.isEmpty ? '시내' : s;
}

// ---------------- 단지 둘레 정류장 ----------------
final Map<String, Map?> _nearFiles = {};
final Map<String, List<Stop>> _nearLive = {};

Future<List<Stop>> stopsNear(Complex c) async {
  // 1) 미리 모은 자료
  if (!_nearFiles.containsKey(c.areaId)) {
    final j = await getJson('${dataBase}bus/near_${c.areaId}.json');
    _nearFiles[c.areaId] = j is Map ? j['near'] as Map? : null;
  }
  final pre = _nearFiles[c.areaId]?[c.id];
  if (pre is List && pre.isNotEmpty) {
    return _sorted([for (final x in pre) Stop.fromJson(x)].whereType<Stop>().toList(), c.pos);
  }
  // 2) 바로 부르기
  final have = _nearLive[c.id];
  if (have != null) return have;
  final items = await _call('BusSttnInfoInqireService/getCrdntPrxmtSttnList',
      {'gpsLati': c.lat.toStringAsFixed(6), 'gpsLong': c.lng.toStringAsFixed(6), 'numOfRows': '40', 'pageNo': '1'},
      keep: const Duration(hours: 12));
  if (items == null) return const [];
  final out = <Stop>[];
  for (final x in items) {
    final y = _d(x['gpslati']), lng = _d(x['gpslong']);
    if (y == null || lng == null || _s(x['nodeid']).isEmpty) continue;
    out.add(Stop(id: _s(x['nodeid']), name: _s(x['nodenm']), no: _s(x['nodeno']), city: _i(x['citycode']), pos: LatLng(y, lng)));
  }
  final list = _sorted(out, c.pos).where((s) => meters(c.pos, s.pos) <= 800).take(10).toList();
  _nearLive[c.id] = list;
  return list;
}

List<Stop> _sorted(List<Stop> l, LatLng p) => l..sort((a, b) => meters(p, a.pos).compareTo(meters(p, b.pos)));

// ---------------- 도착 ----------------
Future<List<Arrival>?> arrivals(Stop s) async {
  final items = await _call('ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList', {'cityCode': '${s.city}', 'nodeId': s.id, 'numOfRows': '60', 'pageNo': '1'});
  if (items == null) return null;
  final out = [
    for (final x in items)
      Arrival(
        routeId: _s(x['routeid']),
        routeNo: _s(x['routeno']),
        type: _s(x['routetp']),
        secs: _i(x['arrtime']),
        left: _i(x['arrprevstationcnt']),
        vehicle: _s(x['vehicletp']),
      ),
  ]..sort((a, b) => a.secs.compareTo(b.secs));
  return out;
}

// 노선마다 가장 먼저 오는 버스 + 그다음 버스
class RouteArrivals {
  final Arrival first;
  final Arrival? next;
  const RouteArrivals(this.first, this.next);
}

List<RouteArrivals> byRoute(List<Arrival> list) {
  final m = <String, List<Arrival>>{};
  for (final a in list) {
    m.putIfAbsent(a.routeId.isEmpty ? a.routeNo : a.routeId, () => []).add(a);
  }
  final out = [for (final l in m.values) RouteArrivals(l.first, l.length > 1 ? l[1] : null)];
  out.sort((a, b) => a.first.secs.compareTo(b.first.secs));
  return out;
}

// ---------------- 노선 ----------------
final Map<String, RouteInfo?> _infos = {};
final Map<String, List<RouteStop>> _routeStops = {};

Future<RouteInfo?> routeInfo(int city, String routeId) async {
  final k = '$city/$routeId';
  if (_infos.containsKey(k)) return _infos[k];
  final items = await _call('BusRouteInfoInqireService/getRouteInfoIem', {'cityCode': '$city', 'routeId': routeId}, keep: const Duration(hours: 12));
  if (items == null) return null;
  final x = items.isEmpty ? null : items.first;
  final gap = _s(x?['intervaltime']);
  final info = x == null
      ? null
      : RouteInfo(
          id: routeId,
          no: _s(x['routeno']),
          type: _s(x['routetp']),
          start: _s(x['startnodenm']),
          end: _s(x['endnodenm']),
          first: _hm(x['startvehicletime']),
          last: _hm(x['endvehicletime']),
          gap: gap.isEmpty || gap == '0' ? '' : '$gap분',
        );
  _infos[k] = info;
  return info;
}

Future<List<RouteStop>> routeStops(int city, String routeId) async {
  final k = '$city/$routeId';
  final have = _routeStops[k];
  if (have != null) return have;
  final items = await _call('BusRouteInfoInqireService/getRouteAcctoThrghSttnList', {'cityCode': '$city', 'routeId': routeId, 'numOfRows': '300', 'pageNo': '1'},
      keep: const Duration(hours: 12));
  if (items == null) return const [];
  final out = <RouteStop>[];
  for (final x in items) {
    final y = _d(x['gpslati']), lng = _d(x['gpslong']);
    out.add(RouteStop(
      id: _s(x['nodeid']),
      name: _s(x['nodenm']),
      no: _s(x['nodeno']),
      ord: _i(x['nodeord']),
      updown: _i(x['updowncd']),
      pos: y == null || lng == null ? null : LatLng(y, lng),
    ));
  }
  out.sort((a, b) => a.ord.compareTo(b.ord));
  _routeStops[k] = out;
  return out;
}

Future<List<BusOnRoute>?> busesOn(int city, String routeId) async {
  final items = await _call('BusLcInfoInqireService/getRouteAcctoBusLcList', {'cityCode': '$city', 'routeId': routeId, 'numOfRows': '100', 'pageNo': '1'});
  if (items == null) return null;
  return [
    for (final x in items)
      BusOnRoute(
        nodeId: _s(x['nodeid']),
        nodeName: _s(x['nodenm']),
        vehicleNo: _s(x['vehicleno']),
        ord: _i(x['nodeord']),
        pos: _d(x['gpslati']) != null && _d(x['gpslong']) != null ? LatLng(_d(x['gpslati'])!, _d(x['gpslong'])!) : null,
      ),
  ];
}

// 이 정류장 다음 정류장 이름 (「○○ 방면」 표시용) — 정류장에 오는 노선 하나로 알아낸다
final Map<String, String> _toward = {};

Future<String> towardOf(Stop s, List<Arrival> arr) async {
  final have = _toward[s.id];
  if (have != null) return have;
  for (final a in arr.take(2)) {
    if (a.routeId.isEmpty) continue;
    final list = await routeStops(s.city, a.routeId);
    final i = list.indexWhere((r) => r.id == s.id);
    if (i >= 0 && i + 1 < list.length) {
      final n = list[i + 1].name;
      _toward[s.id] = n;
      return n;
    }
  }
  return '';
}

// ---------------- 자주 타는 정류장 ----------------
Future<List<Stop>> pinnedStops() async {
  try {
    final s = await prefGet('bus.pinned');
    if (s == null || s.isEmpty) return [];
    final j = jsonDecode(s);
    return [for (final x in (j is List ? j : const [])) Stop.fromJson(x)].whereType<Stop>().toList();
  } catch (_) {
    return [];
  }
}

Future<void> setPinned(List<Stop> l) => prefSet('bus.pinned', jsonEncode([for (final s in l) s.toJson()]));

Future<bool> togglePin(Stop s) async {
  final l = await pinnedStops();
  final i = l.indexWhere((x) => x.id == s.id);
  if (i >= 0) {
    l.removeAt(i);
  } else {
    l.insert(0, s);
  }
  await setPinned(l.take(8).toList());
  return i < 0;
}

// 이 단지에서 보여 줄 정류장 순서: 고정한 정류장(1.5km 안) → 가까운 순
Future<List<Stop>> stopsFor(Complex c) async {
  final near = await stopsNear(c);
  final pins = (await pinnedStops()).where((p) => meters(c.pos, p.pos) <= 1500).toList();
  return [...pins, ...near.where((s) => !pins.any((p) => p.id == s.id))];
}

String errText(BusErr e) => switch (e) {
      BusErr.noKey => '실시간 열쇠를 준비하고 있어요',
      BusErr.blocked => '실시간 도착은 휴대폰 앱에서 보여요',
      _ => '도착 정보를 불러오지 못했어요',
    };
