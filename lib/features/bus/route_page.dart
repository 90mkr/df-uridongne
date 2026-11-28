// 단지 앞 버스 — 노선 화면 (대표님 시안 11-24) (이 폴더는 단지 앞 버스 담당 방만 고침)
// 위: 노선 지도 — 정류장을 이은 가는 선 · 작은 정류장 점 · 내 정류장 강조 · 지금 달리는 버스(30초마다, 부드럽게 이동)
//     왼쪽 위 「운행 n대 · 30초마다 갱신」, 오른쪽 위 「전체 노선 보기」「내 정류장으로」, 오른쪽 아래 확대·축소·내 정류장
// 아래: 파란 번호 칸 + 운행구간·도착까지·첫차·막차·배차 / 탭(정류장 목록 · 실시간 운행정보 · 노선 정보) / 즐겨찾기·도착알림·지도에서 보기
//
// 노선 경로 좌표(도로를 따라 그리는 선)는 TAGO 에 없어 정류장을 잇는다.
// 서울시 버스 API(노선 경로 좌표 제공)를 붙이면 서울은 도로를 따라 그린다 — 다음 단계.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/dnmap.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'widgets.dart';

const _every = Duration(seconds: 30);

class BusRoutePage extends StatefulWidget {
  final Stop stop;
  final Arrival arrival;
  const BusRoutePage({super.key, required this.stop, required this.arrival});
  @override
  State<BusRoutePage> createState() => _BusRoutePageState();
}

class _BusRoutePageState extends State<BusRoutePage> with SingleTickerProviderStateMixin {
  final _map = DnMapCtl();
  LatLng? _cam;
  double _z = 15;
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..addListener(() => setState(() {}));

  RouteInfo? info;
  List<RouteStop> list = [];
  List<BusOnRoute> buses = [];
  List<Arrival> arr = [];
  final Map<String, LatLng> _from = {}, _to = {};
  String? sel; // 고른 버스 번호판
  var loading = true;
  var ready = false;
  var tab = 0;
  var fav = false;
  var alert = false;
  var alerted = false;
  var before = 3, after = 12; // 정류장 목록: 내 정류장 앞뒤로 보여 줄 수
  Timer? _t;

  Stop get s => widget.stop;
  Arrival get a => widget.arrival;
  int get _here => list.indexWhere((r) => r.id == s.id);
  int get _hereOrd => _here < 0 ? -1 : list[_here].ord;
  Arrival get _first => arr.isEmpty ? a : arr.first;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(_every, (_) => _live());
    isFavRoute(s.city, a.routeId).then((v) {
      if (mounted) setState(() => fav = v);
    });
  }

  @override
  void dispose() {
    _t?.cancel(); // 화면을 닫으면 자동 갱신 멈춤
    _move.dispose();
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
  }

  // 버스 위치 + 이 정류장 도착 (같은 노선·정류장은 30초 안에 다시 안 부름 — data.dart)
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
      _move.forward(from: 0);
    }
    setState(() {});
    if (first && ready) _fitMine();
    // 도착알림 (이 화면을 열어 둔 동안)
    if (alert && !alerted && arr.isNotEmpty && arr.first.soon) {
      alerted = true;
      HapticFeedback.heavyImpact();
      if (mounted) toast(context, '${a.routeNo}번 버스가 곧 도착해요');
    }
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
    return buses.where((b) => b.ord > 0 && b.ord <= h).toList()..sort((x, y) => y.ord.compareTo(x.ord));
  }

  // 버스 하나 → 「○분 후 도착 · ○정거장 전」
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
        _map.fit(pts, const EdgeInsets.fromLTRB(40, 64, 60, 40), maxZoom: max);
      }
    } catch (_) {}
  }

  void _zoom(double d) {
    if (!ready) return;
    _z = (_z + d).clamp(6, 18).toDouble();
    _map.move(_cam ?? s.pos, _z);
  }

  void _goto(LatLng? p, {String? bus}) {
    if (p == null || !ready) return;
    _map.move(p, 16.5);
    if (bus != null) setState(() => sel = bus);
  }

  Future<void> _toggleFav() async {
    final on = await toggleFavRoute(s.city, a.routeId, a.routeNo, stop: s, type: a.type);
    if (!mounted) return;
    setState(() => fav = on);
    toast(context, on ? '즐겨찾기 버스로 고정했어요 · 단지 홈에도 이 버스가 보여요' : '즐겨찾기를 풀었어요');
  }

  void _share() {
    final i = info;
    final t = [
      '${a.routeNo}번 버스',
      if (i != null && i.start.isNotEmpty) '${i.start} ↔ ${i.end}',
      if (i != null && i.first.isNotEmpty) '첫차 ${i.first} · 막차 ${i.last}${i.gap.isEmpty ? '' : ' · 배차 ${i.gap}'}',
      '${s.name} ${_first.minsText} (${_first.leftText})',
      '— 우동콕 앱',
    ].join('\n');
    Clipboard.setData(ClipboardData(text: t));
    toast(context, '노선 정보를 복사했어요. 붙여 넣어 보내세요');
  }

  // ---- 화면 ----
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        body: Column(children: [
          BusHeader(
            title: '${a.routeNo}번 노선',
            actions: [
              IconButton(
                tooltip: fav ? '즐겨찾기 풀기' : '즐겨찾기',
                onPressed: _toggleFav,
                icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, size: 26, color: fav ? const Color(0xFFFFD84D) : Colors.white),
              ),
              IconButton(tooltip: '공유', onPressed: _share, icon: const Icon(Icons.share_outlined, size: 23, color: Colors.white)),
              const SizedBox(width: 4),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth >= 640;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 0), // 머리띠와 지도 사이 띄움 (대표님 11-25)
                      child: SizedBox(height: (box.maxHeight * (wide ? 0.42 : 0.38)).clamp(230.0, 440.0), child: _mapView()),
                    ),
                    Expanded(
                      child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 28), children: [
                        _infoCard(wide),
                        const SizedBox(height: 12),
                        if (wide)
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(flex: 3, child: _tabsPanel()),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _actions()),
                          ])
                        else ...[
                          _actions(),
                          const SizedBox(height: 12),
                          _tabsPanel(),
                        ],
                      ]),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ]),
      );

  // ---- 지도 ----
  Widget _mapView() {
    final line = [for (final r in list) if (r.pos != null) r.pos!];
    final selBus = buses.where((b) => b.vehicleNo == sel).firstOrNull;
    return Container(
      decoration: cardBox(r: 16),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // 네이버 지도 (대표님 11-28: 노선 상세만 옛날 지도로 나옴 → 버스 화면과 같은 네이버 지도)
        DnMap(
          center: s.pos,
          zoom: 15,
          ctl: _map,
          showComplex: false,
          onReady: () {
            ready = true;
            if (!loading) _fitMine();
          },
          onIdle: (c, z, _, __) {
            _cam = c;
            _z = z;
          },
          onMapTap: () => setState(() => sel = null),
          lines: [if (line.length > 1) DnLine(line, color: kBlue.withValues(alpha: 0.75), width: 4)],
          marks: [
            for (final r in list)
              if (r.pos != null && r.id != s.id)
                DnMark(
                  id: 'st_${r.id}',
                  pos: r.pos!,
                  key: 'rdot',
                  size: const Size(9, 9),
                  child: Container(width: 9, height: 9, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kBlue.withValues(alpha: 0.8), width: 1.5))),
                ),
            // 내 정류장
            DnMark(
              id: 'mine',
              pos: s.pos,
              key: 'mine|${s.name}',
              size: const Size(150, 50),
              z: 20,
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(gradient: kBusGrad, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white)),
                  child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 3),
                Container(width: 16, height: 16, decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white))),
              ]),
            ),
            // 달리는 버스
            for (final b in buses)
              if (_shown(b) case final p?)
                DnMark(
                  id: 'bus_${b.vehicleNo}',
                  pos: p,
                  key: 'bus|${sel == b.vehicleNo}',
                  size: const Size(34, 34),
                  z: 30,
                  onTap: () => setState(() => sel = sel == b.vehicleNo ? null : b.vehicleNo),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: kBusGrad,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: sel == b.vehicleNo ? kInk : Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, size: 20, color: Colors.white),
                  ),
                ),
            // 고른 버스 안내
            if (selBus != null && _shown(selBus) != null)
              DnMark(
                id: 'selinfo',
                pos: _shown(selBus)!,
                key: 'sel|${_busText(selBus)}|${selBus.vehicleNo}|${selBus.nodeName}',
                size: const Size(200, 96),
                z: 40,
                child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_busText(selBus), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: kInk)),
                      const SizedBox(height: 1),
                      Text([if (selBus.vehicleNo.isNotEmpty) selBus.vehicleNo, if (selBus.nodeName.isNotEmpty) selBus.nodeName].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                    ]),
                  ),
                ]),
              ),
          ],
        ),
        // 왼쪽 위: 운행 대수
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine), boxShadow: kShadow),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.sync_rounded, size: 16, color: kBlue),
              const SizedBox(width: 5),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(loading ? '불러오는 중…' : '운행 ${buses.length}대 · 30초마다 갱신', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        // 오른쪽 위: 범위 버튼
        Positioned(
          top: 10,
          right: 10,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            BusPillBtn('전체 노선 보기', Icons.directions_bus_outlined, _fitAll, iconColor: kBlue),
            const SizedBox(height: 8),
            BusPillBtn('내 정류장으로', Icons.location_on_rounded, _fitMine, iconColor: kBlue),
          ]),
        ),
        // 오른쪽 아래: 확대 · 축소 · 내 정류장
        Positioned(
          right: 10,
          bottom: 24,
          child: Column(children: [
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine), boxShadow: kShadow),
              child: Column(children: [
                _sq(Icons.add_rounded, () => _zoom(1)),
                Container(width: 22, height: 1, color: kLine),
                _sq(Icons.remove_rounded, () => _zoom(-1)),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine), boxShadow: kShadow),
              child: _sq(Icons.my_location_rounded, _fitMine),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sq(IconData ic, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 38, height: 38, child: Icon(ic, size: 21, color: kInk)),
      );

  // ---- 노선 칸 ----
  Widget _infoCard(bool wide) {
    final i = info;
    final f = _first;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(color: kBusTint, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        Flexible(child: Text('${s.name}까지', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub))),
        const SizedBox(width: 6),
        Text(f.soon ? '곧' : '${f.mins}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.8, height: 1.15)),
        Text(f.soon ? ' 도착' : '분', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlue)),
      ]),
    );
    Widget fact(IconData ic, String k, String v) => Expanded(
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(color: kBusTint, shape: BoxShape.circle),
              child: Icon(ic, size: 17, color: kBlue),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: wide
                  ? Text.rich(TextSpan(children: [
                      TextSpan(text: '$k  ', style: const TextStyle(fontSize: 12, color: kSub)),
                      TextSpan(text: v.isEmpty ? '-' : v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    ]))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k, style: T.tiny),
                      Text(v.isEmpty ? '-' : v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2)),
                    ]),
            ),
          ]),
        );
    final title = Text(i == null || i.start.isEmpty ? '${a.routeNo}번' : '${i.start} ↔ ${i.end}',
        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.3));
    // 큰 파란 노선 칸 대신 작은 노선 알약 (대표님 11-24: 노선 번호가 너무 큼)
    final col = busTypeColor(i?.type ?? a.type);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col.withValues(alpha: 0.85), col]), borderRadius: BorderRadius.circular(14)),
      child: Text(a.routeNo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2)),
    );
    return Container(
      decoration: cardBox(r: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          pill,
          const SizedBox(width: 6),
          Text(routeTypeShort(i?.type ?? a.type), style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(flex: 3, child: chip),
        ]),
        const SizedBox(height: 10),
        title,
        const SizedBox(height: 10),
        Container(height: 1, color: kLine),
        const SizedBox(height: 10),
        Row(children: [
          fact(Icons.calendar_today_outlined, '첫차', i?.first ?? ''),
          if (wide) busVLine() else const SizedBox(width: 4),
          fact(Icons.dark_mode_outlined, '막차', i?.last ?? ''),
          if (wide) busVLine() else const SizedBox(width: 4),
          fact(Icons.schedule_rounded, wide ? '배차간격' : '배차', i?.gap ?? ''),
        ]),
      ]),
    );
  }

  // ---- 즐겨찾기 · 도착알림 · 지도에서 보기 ----
  Widget _actions() {
    Widget btn(IconData ic, String t, bool on, VoidCallback onTap) => Expanded(
          child: Material(
            color: on ? kBusTint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? const Color(0xFFBFD3FB) : kLine), boxShadow: kShadow),
                child: Column(children: [
                  Icon(ic, size: 24, color: kBlue),
                  const SizedBox(height: 5),
                  Text(t, maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? kBlue : kInk)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      btn(fav ? Icons.star_rounded : Icons.star_outline_rounded, '즐겨찾기', fav, _toggleFav),
      const SizedBox(width: 10),
      btn(alert ? Icons.notifications_active_outlined : Icons.notifications_none_rounded, '도착알림', alert, () {
        setState(() {
          alert = !alert;
          alerted = false;
        });
        toast(context, alert ? '이 화면을 열어 두면 곧 도착할 때 알려 드려요' : '도착알림을 껐어요');
      }),
      const SizedBox(width: 10),
      btn(Icons.location_on_outlined, '지도에서 보기', false, _fitMine),
    ]);
  }

  // ---- 탭 ----
  Widget _tabsPanel() {
    const names = ['정류장 목록', '실시간 운행정보', '노선 정보'];
    const icons = [Icons.signpost_outlined, Icons.sensors_rounded, Icons.route_outlined];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var k = 0; k < 3; k++) ...[
          if (k > 0) const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => setState(() => tab = k),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: tab == k ? kBusGrad : null,
                  color: tab == k ? null : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: tab == k ? null : Border.all(color: kLine),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icons[k], size: 17, color: tab == k ? Colors.white : kInk),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(names[k],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tab == k ? Colors.white : kInk)),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ]),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          border: Border.all(color: kLine),
          boxShadow: kShadow,
        ),
        child: loading
            ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : switch (tab) {
                0 => _stopsTab(),
                1 => _liveTab(),
                _ => _infoTab(),
              },
      ),
    ]);
  }

  // 정류장 목록: 내 정류장 앞 3곳 ~ 뒤 12곳, 버튼으로 더 보기
  Widget _stopsTab() {
    if (list.isEmpty) return Padding(padding: const EdgeInsets.all(26), child: Text(errText(lastErr), textAlign: TextAlign.center, style: T.small));
    final h = _here < 0 ? 0 : _here;
    final from = (h - before).clamp(0, list.length);
    final to = (h + after).clamp(0, list.length - 1);
    Widget more(String t, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          child: Text(t, style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
        );
    return Column(children: [
      if (from > 0) more('이전 정류장 $from곳 더 보기', () => setState(() => before = list.length)),
      for (var k = from; k <= to; k++) _stopRow(k, first: k == from, last: k == to),
      if (to < list.length - 1) more('다음 정류장 ${list.length - 1 - to}곳 더 보기', () => setState(() => after = list.length)),
    ]);
  }

  Widget _stopRow(int k, {required bool first, required bool last}) {
    final r = list[k];
    final here = r.id == s.id;
    final busHere = buses.where((b) => b.ord == r.ord || (b.ord == 0 && b.nodeId == r.id)).toList();
    final turn = k > 0 && list[k - 1].updown != r.updown;
    return SizedBox(
      height: 56,
      child: Row(children: [
        SizedBox(
          width: 36,
          height: 56, // 칸 높이를 꽉 잡아야 정류장 사이 세로선이 이어짐 (대표님 11-25)
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Positioned(top: first ? 28 : 0, bottom: last ? 28 : 0, child: Container(width: 1.5, color: const Color(0xFFC3CDDC))),
            if (busHere.isNotEmpty)
              BusPulse(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(gradient: kBusGrad, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white)),
                  child: const Icon(Icons.directions_bus_rounded, size: 14, color: Colors.white),
                ),
              )
            else if (here)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kBlue)),
                child: Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle))),
              )
            else
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF8E97A8))),
              ),
          ]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Material(
            color: here ? kBusTint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _goto(r.pos),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                decoration: here || last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: here ? FontWeight.w800 : FontWeight.w600, letterSpacing: -0.3, height: 1.2)),
                        ),
                        if (turn) ...[const SizedBox(width: 6), const Pill('회차')],
                      ]),
                      const SizedBox(height: 2),
                      Text([if (r.no.isNotEmpty) r.no, if (here) '내 정류장', if (busHere.isNotEmpty) '버스 ${busHere.length}대 · ${_busText(busHere.first)}'].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: here ? kBlue : kSub, height: 1.2)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 22, color: kSub),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // 실시간 운행정보: 지금 달리는 버스 (내 정류장으로 오는 버스 먼저)
  Widget _liveTab() {
    if (buses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(26),
        child: Text(lastErr == BusErr.none ? '지금 운행 중인 버스가 없어요' : errText(lastErr), textAlign: TextAlign.center, style: T.small),
      );
    }
    final h = _hereOrd;
    final l = [...buses]..sort((x, y) {
        int key(BusOnRoute b) => h < 0 ? b.ord : (b.ord <= h ? h - b.ord : 10000 + b.ord);
        return key(x).compareTo(key(y));
      });
    return Column(children: [
      for (var k = 0; k < l.length; k++)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _goto(_posOf(l[k]), bus: l[k].vehicleNo),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 11, 4, 11),
            decoration: k == l.length - 1 ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(gradient: kBusGrad, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.directions_bus_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l[k].vehicleNo.isEmpty ? '버스' : l[k].vehicleNo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                  if (l[k].nodeName.isNotEmpty) Text('지금 ${l[k].nodeName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                ]),
              ),
              Text(_busText(l[k]),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: k == 0 && h >= 0 && l[k].ord <= h ? kBlue : kSub)),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kSub),
            ]),
          ),
        ),
    ]);
  }

  // 노선 정보
  Widget _infoTab() {
    final i = info;
    final rows = <(String, String)>[
      ('노선 번호', a.routeNo),
      ('노선 종류', routeTypeShort(i?.type ?? a.type)),
      ('기점', i?.start ?? ''),
      ('종점', i?.end ?? ''),
      ('첫차', i?.first ?? ''),
      ('막차', i?.last ?? ''),
      ('배차간격', i?.gap ?? ''),
      ('정류장 수', list.isEmpty ? '' : '${list.length}곳'),
      ('지금 운행', '${buses.length}대'),
      ('자료', '국토교통부 TAGO · 30초마다 갱신'),
    ];
    return Column(children: [
      for (var k = 0; k < rows.length; k++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: k == rows.length - 1 ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 86, child: Text(rows[k].$1, style: const TextStyle(fontSize: 12.5, color: kSub))),
            Expanded(child: Text(rows[k].$2.isEmpty ? '-' : rows[k].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35))),
          ]),
        ),
    ]);
  }
}
