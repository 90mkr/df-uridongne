// 단지 앞 버스 — 노선 화면 (이 폴더는 단지 앞 버스 담당 방만 고침)
// 위: 노선 지도 — 정류장 순서대로 이은 가는 선 · 작은 정류장 점 · 내 정류장 강조 · 지금 달리는 버스(30초마다, 부드럽게 이동)
// 아래: 첫차·막차·배차와 정류장 순서 목록
//
// 노선 경로 좌표(도로를 따라 그리는 선)는 TAGO 에 없어 정류장을 잇는다.
// 서울시 버스 API(노선 경로 좌표 제공)를 붙이면 서울은 도로를 따라 그린다 — 다음 단계.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _every = Duration(seconds: 30);
const _rowH = 46.0;

class BusRoutePage extends StatefulWidget {
  final Stop stop;
  final Arrival arrival;
  const BusRoutePage({super.key, required this.stop, required this.arrival});
  @override
  State<BusRoutePage> createState() => _BusRoutePageState();
}

class _BusRoutePageState extends State<BusRoutePage> with SingleTickerProviderStateMixin {
  final _map = MapController();
  final _sc = ScrollController();
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..addListener(() => setState(() {}));

  RouteInfo? info;
  List<RouteStop> list = [];
  List<BusOnRoute> buses = [];
  List<Arrival> arr = [];
  final Map<String, LatLng> _from = {}, _to = {};
  String? sel; // 고른 버스 번호판
  var loading = true;
  var ready = false;
  DateTime? at;
  Timer? _t;

  Stop get s => widget.stop;
  Arrival get a => widget.arrival;

  int get _here {
    final i = list.indexWhere((r) => r.id == s.id);
    return i;
  }

  int get _hereOrd => _here < 0 ? -1 : list[_here].ord;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(_every, (_) => _live());
  }

  @override
  void dispose() {
    _t?.cancel(); // 화면을 닫으면 자동 갱신 멈춤
    _move.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Future.wait([routeInfo(s.city, a.routeId), routeStops(s.city, a.routeId)]);
    if (!mounted) return;
    info = r[0] as RouteInfo?;
    list = r[1] as List<RouteStop>;
    loading = false;
    setState(() {});
    await _live(first: true);
    final i = _here;
    if (i > 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients) _sc.jumpTo(((i - 2) * _rowH).clamp(0, _sc.position.maxScrollExtent));
      });
    }
  }

  // 버스 위치 + 이 정류장 도착 (같은 주소는 30초 안에 다시 안 부름 — data.dart)
  Future<void> _live({bool first = false}) async {
    final r = await Future.wait([busesOn(s.city, a.routeId), arrivals(s)]);
    if (!mounted) return;
    final b = r[0] as List<BusOnRoute>?;
    final ar = r[1] as List<Arrival>?;
    if (ar != null) arr = ar.where((x) => x.routeId == a.routeId).toList();
    if (b != null) {
      final snap = <String, LatLng>{};
      for (final x in buses) {
        final p = _shown(x);
        if (p != null) snap[x.vehicleNo] = p;
      }
      _from
        ..clear()
        ..addAll(snap);
      buses = b;
      _to
        ..clear()
        ..addAll({for (final x in b) if (_posOf(x) != null) x.vehicleNo: _posOf(x)!});
      at = DateTime.now();
      _move.forward(from: 0);
    }
    setState(() {});
    if (first && ready) _fitMine();
  }

  LatLng? _posOf(BusOnRoute b) {
    if (b.pos != null) return b.pos;
    for (final r in list) {
      if (r.ord == b.ord || r.id == b.nodeId) return r.pos;
    }
    return null;
  }

  // 지금 화면에 그릴 위치 (이전 → 새 위치 사이를 부드럽게)
  LatLng? _shown(BusOnRoute b) {
    final to = _to[b.vehicleNo] ?? _posOf(b);
    if (to == null) return null;
    final from = _from[b.vehicleNo];
    if (from == null) return to;
    final t = Curves.easeInOut.transform(_move.value);
    return LatLng(from.latitude + (to.latitude - from.latitude) * t, from.longitude + (to.longitude - from.longitude) * t);
  }

  // 내 정류장으로 오는 버스 (가까운 순)
  List<BusOnRoute> get _coming {
    final h = _hereOrd;
    if (h < 0) return [];
    final l = buses.where((b) => b.ord > 0 && b.ord <= h).toList()..sort((x, y) => y.ord.compareTo(x.ord));
    return l;
  }

  String _busText(BusOnRoute b) {
    final h = _hereOrd;
    if (h < 0 || b.ord <= 0) return b.nodeName.isEmpty ? '' : '${b.nodeName} 근처';
    if (b.ord > h) return '내 정류장을 지났어요';
    final left = h - b.ord;
    if (left == 0) return '곧 도착 · 정류장 도착';
    Arrival? m;
    for (final x in arr) {
      if ((x.left - left).abs() <= 1 && (m == null || (x.left - left).abs() < (m.left - left).abs())) m = x;
    }
    if (m != null) return '${m.soon ? '곧 도착' : '${m.mins}분 후 도착'} · $left정거장 전';
    return '$left정거장 전';
  }

  // ---- 지도 범위 ----
  void _fitMine() {
    final pts = <LatLng>[s.pos];
    final c = _coming.take(3).map(_posOf).whereType<LatLng>().toList();
    if (c.isNotEmpty) {
      pts.addAll(c);
    } else if (_here >= 0) {
      for (var k = (_here - 5).clamp(0, list.length); k <= (_here + 2).clamp(0, list.length - 1); k++) {
        final p = list[k].pos;
        if (p != null) pts.add(p);
      }
    }
    _fit(pts, max: 16.5);
  }

  void _fitAll() => _fit([for (final r in list) if (r.pos != null) r.pos!], max: 15);

  void _fit(List<LatLng> pts, {required double max}) {
    if (!ready || pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        _map.move(pts.first, 16);
      } else {
        _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(36, 56, 36, 36), maxZoom: max));
      }
    } catch (_) {}
  }

  // ---- 화면 ----
  @override
  Widget build(BuildContext context) => DetailPage(
        title: '${a.routeNo}번 노선',
        icon: 'bus',
        body: LayoutBuilder(
          builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: (box.maxHeight * 0.5).clamp(240.0, 460.0), child: _mapView()),
            Container(height: 1, color: kLine),
            _info(),
            Container(height: 1, color: kLine),
            Expanded(child: _stops()),
          ]),
        ),
      );

  Widget _mapView() {
    final line = [for (final r in list) if (r.pos != null) r.pos!];
    final selBus = buses.where((b) => b.vehicleNo == sel).firstOrNull;
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: s.pos,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: () {
            ready = true;
            if (!loading) _fitMine();
          },
          onTap: (_, __) => setState(() => sel = null),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
          if (line.length > 1) PolylineLayer(polylines: [Polyline(points: line, strokeWidth: 3, color: kBlue.withValues(alpha: 0.55))]),
          CircleLayer(circles: [
            for (final r in list)
              if (r.pos != null && r.id != s.id) CircleMarker(point: r.pos!, radius: 3.2, color: Colors.white, borderColor: const Color(0xFF8E939E), borderStrokeWidth: 1),
          ]),
          MarkerLayer(markers: [
            // 내 정류장
            Marker(
              point: s.pos,
              width: 120,
              height: 44,
              alignment: Alignment.topCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(12)),
                  child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white), boxShadow: kShadow),
                ),
              ]),
            ),
            // 달리는 버스
            for (final b in buses)
              if (_shown(b) case final p?)
                Marker(
                  point: p,
                  width: 30,
                  height: 30,
                  child: GestureDetector(
                    onTap: () => setState(() => sel = sel == b.vehicleNo ? null : b.vehicleNo),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel == b.vehicleNo ? kInk : kLine),
                        boxShadow: kShadow,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const LineIcon('bus', size: 24),
                    ),
                  ),
                ),
            // 고른 버스 안내
            if (selBus != null && _shown(selBus) != null)
              Marker(
                point: _shown(selBus)!,
                width: 190,
                height: 62,
                alignment: const Alignment(0, -1.6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: cardBox(r: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_busText(selBus), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 1),
                    Text([if (selBus.vehicleNo.isNotEmpty) selBus.vehicleNo, if (selBus.nodeName.isNotEmpty) selBus.nodeName].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                  ]),
                ),
              ),
          ]),
          const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
        ],
      ),
      Positioned(
        top: 10,
        right: 10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _mapBtn('전체 노선 보기', _fitAll),
          const SizedBox(height: 6),
          _mapBtn('내 정류장으로', _fitMine),
        ]),
      ),
      Positioned(
        left: 10,
        top: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: cardBox(r: 8),
          child: Text(
            loading ? '노선을 불러오는 중…' : '운행 ${buses.length}대 · 30초마다 갱신',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kSub),
          ),
        ),
      ),
    ]);
  }

  Widget _mapBtn(String t, VoidCallback onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: cardBox(r: 8),
            child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _info() {
    final i = info;
    final first = arr.isEmpty ? a : arr.first;
    Widget cell(String k, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: T.tiny),
            const SizedBox(height: 1),
            Text(v.isEmpty ? '-' : v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ]),
        );
    Widget gap() => Container(width: 1, height: 24, color: kLine, margin: const EdgeInsets.only(right: 12));
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(a.routeNo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 2), child: Pill(routeTypeShort(i?.type ?? a.type))),
          const Spacer(),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${s.name} ', style: const TextStyle(color: kSub)),
              TextSpan(text: first.minsText, style: TextStyle(fontWeight: FontWeight.w800, color: first.soon ? kBlue : kInk)),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
        ]),
        if (i != null && (i.start.isNotEmpty || i.end.isNotEmpty)) ...[
          const SizedBox(height: 4),
          Text('${i.start} ↔ ${i.end}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
        ],
        if (i != null) ...[
          const SizedBox(height: 10),
          Row(children: [cell('첫차', i.first), gap(), cell('막차', i.last), gap(), cell('배차', i.gap)]),
        ],
      ]),
    );
  }

  Widget _stops() {
    if (loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (list.isEmpty) return Padding(padding: const EdgeInsets.all(30), child: Text(errText(lastErr), textAlign: TextAlign.center, style: T.small));
    return ListView.builder(
      controller: _sc,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
      itemExtent: _rowH,
      itemCount: list.length,
      itemBuilder: (_, k) => _stopRow(k),
    );
  }

  Widget _stopRow(int k) {
    final r = list[k];
    final here = r.id == s.id;
    final busHere = buses.where((b) => b.ord == r.ord || (b.ord == 0 && b.nodeId == r.id)).toList();
    final turn = k > 0 && list[k - 1].updown != r.updown;
    return InkWell(
      onTap: r.pos == null || !ready ? null : () => _map.move(r.pos!, 16.5),
      child: Row(children: [
        SizedBox(
          width: 58,
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
              top: k == 0 ? _rowH / 2 : 0,
              bottom: k == list.length - 1 ? _rowH / 2 : 0,
              child: Container(width: 2, color: kLine),
            ),
            if (busHere.isNotEmpty)
              Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 2), child: const LineIcon('bus', size: 22))
            else
              Container(
                width: here ? 12 : 8,
                height: here ? 12 : 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: here ? kBlue : Colors.white, border: Border.all(color: here ? kBlue : const Color(0xFFB9BDC6))),
              ),
          ]),
        ),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: here ? FontWeight.w800 : FontWeight.w500, color: here ? kBlue : kInk, height: 1.2)),
              ),
              if (here) ...[const SizedBox(width: 6), const Pill('내 정류장', color: kBlue, bg: Color(0xFFEEF3FF))],
              if (turn) ...[const SizedBox(width: 6), const Pill('회차')],
            ]),
            const SizedBox(height: 1),
            Text([if (r.no.isNotEmpty) r.no, if (busHere.isNotEmpty) '버스 ${busHere.length}대 · ${_busText(busHere.first)}'].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
          ]),
        ),
        const SizedBox(width: kPad),
      ]),
    );
  }
}
