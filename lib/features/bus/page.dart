// 단지 앞 버스 — 정류장 화면 (대표님 시안 11-24) (이 폴더는 단지 앞 버스 담당 방만 고침)
// 그림 머리 · 둘레 정류장 카드 · 정류장 카드(방면·번호·거리, 갱신 줄, 노선별 도착 카드) · 안내 · 노선 정보 카드
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart' show MapPoint;
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'go_page.dart';
import 'route_page.dart';
import 'widgets.dart';

const _refreshSec = 30;

class BusPage extends StatefulWidget {
  final Complex complex;
  final String? startStop;
  const BusPage({super.key, required this.complex, this.startStop});
  @override
  State<BusPage> createState() => _BusPageState();
}

class _BusPageState extends State<BusPage> {
  List<Stop> stops = [];
  Set<String> pins = {};
  var sel = 0;
  var loading = true;
  var mapView = true; // 대표님 11-25: 지도 + 아래 창이 첫 화면 (목록은 단추로)
  // 지도 화면: 아래 창에 보일 정류장들의 도착 정보 (정류장마다 따로 30초 새로 고침)
  List<Stop> pair = []; // 가까운 정류장 2곳 (양방향)
  Stop? picked; // 지도에서 누른 정류장
  final Map<String, List<Arrival>?> arrOf = {};
  final Map<String, DateTime> atOf = {};
  final Set<String> busy = {};
  final Map<String, String> towardMap = {};
  Set<String> favs = {}; // 'city/routeId'
  List<Arrival>? arr;
  var fetching = false;
  DateTime? at;
  String toward = '';
  RouteInfo? firstInfo;
  Timer? _tick;

  Complex get c => widget.complex;
  Stop? get stop => stops.isEmpty ? null : stops[sel.clamp(0, stops.length - 1)];
  int get _ago => at == null ? 0 : DateTime.now().difference(at!).inSeconds;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (mapView) {
        for (final s in _shown) {
          final t = atOf[s.id];
          if (t != null && DateTime.now().difference(t).inSeconds >= _refreshSec && !busy.contains(s.id)) _fetchOne(s);
        }
        setState(() {});
        return;
      }
      if (at != null && _ago >= _refreshSec && !fetching) {
        _fetch();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel(); // 화면을 닫으면 자동 갱신 멈춤
    super.dispose();
  }

  Future<void> _load() async {
    final list = await stopsFor(c);
    final p = await pinnedStops();
    if (!mounted) return;
    stops = list;
    pins = {for (final s in p) s.id};
    final i = widget.startStop == null ? -1 : list.indexWhere((s) => s.id == widget.startStop);
    sel = i >= 0 ? i : 0;
    pair = nearPair(list, c.pos);
    if (i >= 0) picked = list[i];
    favs = {for (final m in await favRoutes()) '${m['c']}/${m['r']}'};
    loading = false;
    if (mounted) setState(() {});
    for (final s in _shown) {
      _fetchOne(s);
    }
    _towards(list);
    await _fetch();
  }

  // 지도 화면 아래 창에 보이는 정류장
  List<Stop> get _shown => picked != null ? [picked!] : pair;

  Future<void> _fetchOne(Stop s) async {
    busy.add(s.id);
    if (mounted) setState(() {});
    var a = await arrivals(s);
    if (a == null) {
      // 공공 자료가 잠깐 막히는 일(동시 접속 한도 등)이 잦아 — 2초 쉬고 한 번 더 (대표님 11-26 「불러오지 못했어요」)
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      a = await arrivals(s);
    }
    busy.remove(s.id);
    if (!mounted) return;
    setState(() {
      // 그래도 못 받으면 직전에 받은 도착 정보를 그대로 둔다 (빈 오류 칸보다 낫게)
      if (a != null || arrOf[s.id] == null) arrOf[s.id] = a;
      if (a != null) atOf[s.id] = DateTime.now();
    });
  }

  // 정류장마다 「○○ 방면」 (같은 이름 정류장 구분) — 하나씩 천천히 (노선 목록은 12시간 묶음이라 부담 적음)
  Future<void> _towards(List<Stop> list) async {
    final order = [...pair, ...list.where((s) => !pair.any((p) => p.id == s.id))];
    for (final s in order) {
      final t = await towardOf(s, arrOf[s.id] ?? const []);
      if (!mounted) return;
      if (t.isNotEmpty) setState(() => towardMap[s.id] = t);
    }
  }

  void _pickOnMap(String? id) {
    final s = id == null ? null : stops.where((x) => x.id == id).firstOrNull;
    if (s?.id == picked?.id) return;
    setState(() => picked = s);
    if (s != null && (atOf[s.id] == null || DateTime.now().difference(atOf[s.id]!).inSeconds >= _refreshSec)) _fetchOne(s);
  }

  Future<void> _fav(Stop s, Arrival a) async {
    final on = await toggleFavRoute(s.city, a.routeId, a.routeNo, stop: s, type: a.type);
    if (!mounted) return;
    setState(() => on ? favs.add('${s.city}/${a.routeId}') : favs.remove('${s.city}/${a.routeId}'));
    toast(context, on ? '${a.routeNo}번을 즐겨찾기 버스로 고정했어요 · 단지 홈에도 보여요' : '즐겨찾기를 풀었어요');
  }

  Future<void> _fetch() async {
    final s = stop;
    if (s == null) {
      setState(() {});
      return;
    }
    fetching = true;
    if (mounted) setState(() {});
    final a = await arrivals(s);
    if (!mounted || stop?.id != s.id) return;
    fetching = false;
    arr = a;
    at = DateTime.now();
    setState(() {});
    if (a != null && a.isNotEmpty) {
      final t = await towardOf(s, a);
      final first = byRoute(a).first.first;
      final info = firstInfo?.id == first.routeId ? firstInfo : await routeInfo(s.city, first.routeId);
      if (mounted && stop?.id == s.id) {
        setState(() {
          toward = t;
          firstInfo = info;
        });
      }
    }
  }

  void _pick(int i) {
    if (i == sel && !mapView) return;
    setState(() {
      sel = i;
      arr = null;
      at = null;
      toward = '';
      firstInfo = null;
      mapView = false;
    });
    _fetch();
  }

  Future<void> _pin(Stop s) async {
    final on = await togglePin(s);
    if (!mounted) return;
    setState(() => on ? pins.add(s.id) : pins.remove(s.id));
    toast(context, on ? '자주 타는 정류장으로 고정했어요' : '고정을 풀었어요');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        body: Column(children: [
          BusHeader(
            title: '단지 앞 버스',
            trailing: stops.isEmpty
                ? null
                : BusPillBtn(mapView ? '목록으로 보기' : '지도로 보기', mapView ? Icons.view_list_outlined : Icons.map_outlined, () {
                    setState(() => mapView = !mapView);
                    if (mapView) {
                      for (final s in _shown) {
                        _fetchOne(s);
                      }
                    } else {
                      _fetch();
                    }
                  }, glass: true),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : stops.isEmpty
                    ? _empty()
                    : mapView
                        ? _mapPanel()
                        : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _list())),
          ),
        ]),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(lastErr == BusErr.none ? '단지 둘레 800m 안에 정류장이 없어요' : '정류장 자료를 모으고 있어요', style: T.h2),
            const SizedBox(height: 6),
            const Text('서울은 서울시 버스 자료로 따로 준비하고 있어요.', textAlign: TextAlign.center, style: T.small),
          ]),
        ),
      );

  Widget _list() {
    final s = stop!;
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(padding: const EdgeInsets.fromLTRB(0, 18, 0, 30), children: [
        _tabs(),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: _stopCard(s)),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: _notice()),
        if (firstInfo != null && arr != null && arr!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: _routeCard(s, byRoute(arr!).first.first, firstInfo!)),
        ],
      ]),
    );
  }

  // 둘레 정류장 고르기 (옆으로 밀기)
  Widget _tabs() => SizedBox(
        height: 66,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 4),
          itemCount: stops.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = stops[i], on = i == sel;
            final fg = on ? Colors.white : kInk;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _pick(i),
              child: Container(
                width: 168,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: on
                    ? BoxDecoration(gradient: kBusGrad, borderRadius: BorderRadius.circular(14), boxShadow: kShadow)
                    : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine), boxShadow: kShadow),
                child: Row(children: [
                  Icon(Icons.directions_bus_outlined, size: 22, color: on ? Colors.white : kSub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg, height: 1.2)),
                      const SizedBox(height: 3),
                      Text(
                        '${pins.contains(s.id) ? '★ ' : ''}${distText(meters(c.pos, s.pos))}${s.no.isEmpty ? '' : ' · ${s.no}'}',
                        maxLines: 1,
                        style: TextStyle(fontSize: 11.5, color: on ? Colors.white.withValues(alpha: 0.85) : kSub, height: 1.2),
                      ),
                    ]),
                  ),
                  if (on) const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                ]),
              ),
            );
          },
        ),
      );

  Widget _stopCard(Stop s) => Container(
        decoration: cardBox(r: 16),
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.location_on_rounded, size: 24, color: kBlue)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.25)),
            ),
            IconButton(
              tooltip: pins.contains(s.id) ? '고정 풀기' : '자주 타는 정류장으로 고정',
              visualDensity: VisualDensity.compact,
              onPressed: () => _pin(s),
              icon: Icon(pins.contains(s.id) ? Icons.star_rounded : Icons.star_outline_rounded, size: 26, color: pins.contains(s.id) ? kBlue : kSub),
            ),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BusDotLine([
              if (toward.isNotEmpty) TextSpan(text: '$toward 방면'),
              TextSpan(text: '정류장 번호 ${s.no.isEmpty ? '-' : s.no}'),
              TextSpan(children: [
                const TextSpan(text: '단지에서 '),
                TextSpan(text: distText(meters(c.pos, s.pos)), style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800)),
              ]),
            ], size: 12.5),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(children: [
              Container(height: 1, color: kLine),
              Container(height: 1, width: 64, color: kBlue),
            ]),
          ),
          const SizedBox(height: 10),
          _refreshRow(),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(right: 8), child: _arrivals(s)),
        ]),
      );

  Widget _refreshRow() {
    final left = at == null ? _refreshSec : (_refreshSec - _ago).clamp(0, _refreshSec);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: kBusTint, shape: BoxShape.circle),
          child: fetching
              ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 1.6))
              : const Icon(Icons.refresh_rounded, size: 18, color: kBlue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: at == null
              ? Text(fetching ? '불러오는 중…' : '', style: T.small)
              : BusDotLine([TextSpan(text: _ago < 5 ? '방금 갱신' : '$_ago초 전 갱신'), TextSpan(text: '$left초 뒤 새로고침')], size: 12),
        ),
        OutlinedButton.icon(
          onPressed: fetching ? null : _fetch,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('새로고침'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kBlue,
            side: const BorderSide(color: Color(0xFFBFD3FB)),
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _arrivals(Stop s) {
    final a = arr;
    if (a == null) {
      if (fetching || at == null && lastErr == BusErr.none) {
        return const Padding(padding: EdgeInsets.all(26), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
      }
      return _note(errText(lastErr), '잠시 뒤 새로고침해 주세요.');
    }
    if (a.isEmpty) return _note('지금 오는 버스가 없어요', '첫차 전이거나 막차가 끊겼을 수 있어요.');
    final rows = byRoute(a);
    return Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _ArrCard(r: rows[i], gone: _ago, onTap: () => openRoute(context, s, rows[i].first)),
      ],
    ]);
  }

  Widget _note(String t, String sub) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
        child: Column(children: [
          Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: T.small),
        ]),
      );

  Widget _notice() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: const Color(0xFFE9F0FB), borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, size: 24, color: kBlue),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('지금 이 정류장으로 오고 있는 버스만 보여요.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
              SizedBox(height: 2),
              Text('노선을 누르면 지나는 정류장과 버스 위치를 볼 수 있어요.  |  국토교통부 TAGO 자료', style: T.tiny),
            ]),
          ),
        ]),
      );

  // 먼저 오는 노선 정보
  Widget _routeCard(Stop s, Arrival a, RouteInfo i) {
    Widget head(IconData ic, String t) => Row(children: [
          Icon(ic, size: 20, color: kBlue),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]);
    const v = TextStyle(fontSize: 12.5, color: kInk, height: 1.35);
    const b = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openRoute(context, s, a),
      child: Container(
        decoration: cardBox(r: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            child: Row(children: [
              Container(
                width: 34,
                height: 24,
                decoration: BoxDecoration(gradient: kBusGrad, borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.route_outlined, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('${a.routeNo}번 노선 정보', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
              const Icon(Icons.chevron_right_rounded, size: 24, color: kSub),
            ]),
          ),
          Container(height: 1, color: kLine),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 5,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    head(Icons.alt_route_rounded, '운행구간'),
                    const SizedBox(height: 8),
                    Text('${i.start} ↔ ${i.end}', maxLines: 2, overflow: TextOverflow.ellipsis, style: v),
                  ]),
                ),
                const VerticalDivider(width: 22, thickness: 1, color: kLine),
                Expanded(
                  flex: 4,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    head(Icons.schedule_rounded, '운행시간'),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: '첫차 ', style: v),
                      TextSpan(text: i.first.isEmpty ? '-' : i.first, style: b),
                    ])),
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: '막차 ', style: v),
                      TextSpan(text: i.last.isEmpty ? '-' : i.last, style: b),
                    ])),
                  ]),
                ),
                const VerticalDivider(width: 22, thickness: 1, color: kLine),
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    head(Icons.timer_outlined, '배차간격'),
                    const SizedBox(height: 8),
                    Text(i.gap.isEmpty ? '-' : i.gap, style: b),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------- 지도 + 아래 창 (대표님 11-25) ----------------
  // 열자마자 가까운 정류장 2곳(양방향) 도착 정보가 아래 창에. 지도 정류장은 작은 버스 아이콘만, 누르면 이름·방면
  Widget _mapPanel() => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 760;
        final map = DongneMap(
          center: c.pos,
          zoom: 16.6,
          icon: 'bus',
          names: false,
          pick: picked?.id,
          onPick: _pickOnMap,
          points: [
            for (final s in stops)
              MapPoint(
                id: s.id,
                name: s.name,
                sub: [if ((towardMap[s.id] ?? '').isNotEmpty) '${towardMap[s.id]} 방면', distText(meters(c.pos, s.pos))].join(' · '),
                pos: s.pos,
              ),
          ],
        );
        if (wide) {
          // 태블릿: 왼쪽 창 · 오른쪽 지도
          return Row(children: [
            SizedBox(width: (box.maxWidth * 0.42).clamp(360.0, 460.0), child: Container(color: kBg, child: _panel(top: 14))),
            Container(width: 1, color: kLine),
            Expanded(child: map),
          ]);
        }
        final mh = (box.maxHeight * 0.4).clamp(200.0, 360.0);
        return Stack(children: [
          Positioned(left: 0, right: 0, top: 0, height: mh + 20, child: map),
          Positioned.fill(
            top: mh,
            child: Container(
              decoration: const BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Color(0x1A0B2A5B), blurRadius: 14)],
              ),
              child: Column(children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFD3DAE5), borderRadius: BorderRadius.circular(2))),
                Expanded(child: _panel(top: 10)),
              ]),
            ),
          ),
        ]);
      });

  Widget _panel({double top = 10}) {
    final shown = _shown;
    final t = shown.map((s) => atOf[s.id]).whereType<DateTime>().fold<DateTime?>(null, (m, x) => m == null || x.isBefore(m) ? x : m);
    final left = t == null ? _refreshSec : (_refreshSec - DateTime.now().difference(t).inSeconds).clamp(0, _refreshSec);
    final anyBusy = shown.any((s) => busy.contains(s.id));
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([for (final s in shown) _fetchOne(s)]);
      },
      child: ListView(padding: EdgeInsets.fromLTRB(kPad, top, kPad, 28), children: [
        GoBar(c: widget.complex),
        const SizedBox(height: 14),
        Row(children: [
          if (picked != null)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pickOnMap(null),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(2, 6, 8, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chevron_left_rounded, size: 20, color: kBlue),
                  Text('가까운 정류장', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlue)),
                ]),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('단지 앞 가까운 정류장', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.3)),
            ),
          const Spacer(),
          if (anyBusy)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
          else
            Text('$left초 뒤 새로 고침', style: const TextStyle(fontSize: 11.5, color: kSub)),
        ]),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (w, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a), child: w),
          ),
          child: Column(
            key: ValueKey(shown.map((s) => s.id).join(',')),
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _stopBlock(shown[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('지도의 버스 아이콘을 누르면 그 정류장 도착 정보가 보여요  ·  국토교통부 TAGO', textAlign: TextAlign.center, style: T.tiny),
      ]),
    );
  }

  // 정류장 한 곳: 이름 · 방면 · 거리 / 버스별 한 줄 「103 · 3분 후 · 2정거장 전」
  Widget _stopBlock(Stop s) {
    final a = arrOf[s.id];
    final gone = atOf[s.id] == null ? 0 : DateTime.now().difference(atOf[s.id]!).inSeconds;
    final tw = towardMap[s.id] ?? '';
    Widget body;
    if (a == null) {
      body = busy.contains(s.id) || atOf[s.id] == null
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          : _quiet(errText(lastErr));
    } else if (a.isEmpty) {
      body = _quiet('지금 오는 버스 정보가 없어요');
    } else {
      final rows = byRoute(a);
      body = Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEFF2F6)),
          _busLine(s, rows[i].first, gone),
        ],
      ]);
    }
    return Container(
      decoration: cardBox(r: 16),
      padding: const EdgeInsets.fromLTRB(16, 13, 6, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 1), child: LineIconBus()),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.25)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  if (tw.isNotEmpty) TextSpan(text: '$tw 방면', style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                  if (tw.isNotEmpty) const TextSpan(text: '  ·  '),
                  TextSpan(text: '단지에서 ${distText(meters(c.pos, s.pos))}'),
                  if (s.no.isNotEmpty) TextSpan(text: '  ·  ${s.no}'),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kSub, height: 1.3),
              ),
            ]),
          ),
          IconButton(
            tooltip: pins.contains(s.id) ? '고정 풀기' : '자주 타는 정류장으로 고정',
            visualDensity: VisualDensity.compact,
            onPressed: () => _pin(s),
            icon: Icon(pins.contains(s.id) ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 19, color: pins.contains(s.id) ? kBlue : kMute),
          ),
        ]),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.only(right: 10), child: body),
      ]),
    );
  }

  Widget _quiet(String t) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w600)),
      );

  Widget _busLine(Stop s, Arrival a, int gone) {
    final secs = (a.secs - gone).clamp(0, 99999);
    final soon = secs <= 120 || a.left <= 1;
    final col = busTypeColor(a.type);
    final fav = favs.contains('${s.city}/${a.routeId}');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openRoute(context, s, a),
      child: SizedBox(
        height: 48,
        child: Row(children: [
          Container(
            constraints: const BoxConstraints(minWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)),
            child: Text(a.routeNo, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: soon ? '곧 도착' : '${(secs / 60).ceil()}분 후', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: soon ? const Color(0xFFE5484D) : kBlue, letterSpacing: -0.4)),
                TextSpan(text: '  ·  ${a.leftText}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF5A6475))),
                if (a.lowFloor) const TextSpan(text: '  ·  저상', style: TextStyle(fontSize: 11.5, color: kSub)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: fav ? '즐겨찾기 풀기' : '즐겨찾기 버스로 고정 (단지 홈에 이 버스만)',
            visualDensity: VisualDensity.compact,
            onPressed: () => _fav(s, a),
            icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, size: 22, color: fav ? const Color(0xFFFFB020) : const Color(0xFFB4BCC9)),
          ),
        ]),
      ),
    );
  }
}

// 정류장 머리 작은 버스 아이콘
class LineIconBus extends StatelessWidget {
  const LineIconBus({super.key});
  @override
  Widget build(BuildContext context) => const LineIcon('bus', size: 26);
}

// 노선 하나 도착 카드: 파란 번호 칸 | 도착 예정 큰 분 · 남은 정거장 막대
class _ArrCard extends StatelessWidget {
  final RouteArrivals r;
  final int gone; // 마지막으로 불러온 뒤 지난 초 (화면에서 줄여 보여 줌)
  final VoidCallback onTap;
  const _ArrCard({required this.r, required this.gone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = r.first;
    final secs = (a.secs - gone).clamp(0, 99999);
    final soon = secs <= 120 || a.left <= 1;
    final mins = (secs / 60).ceil();
    final n = r.next;
    // 막대: 30정거장 전부터 정류장까지
    final prog = (1 - a.left / 30).clamp(0.04, 1.0);
    // 홈 카드와 같은 모양 (대표님 11-24): 왼쪽 작은 노선 알약 · 가운데 막대 · 오른쪽 도착 시간 알약
    final col = busTypeColor(a.type);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6EBF3))),
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col.withValues(alpha: 0.85), col]), borderRadius: BorderRadius.circular(14)),
              child: Text(a.routeNo, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2)),
            ),
            const SizedBox(height: 3),
            Text(routeTypeShort(a.type) + (a.lowFloor ? '·저상' : ''), style: const TextStyle(fontSize: 10.5, color: kSub)),
          ]),
          const SizedBox(width: 12),
          Expanded(child: _Track(p: prog, label: n == null ? a.leftText : '${a.leftText} · 다음 ${(n.secs / 60).ceil()}분')),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.directions_bus_rounded, size: 15, color: Color(0xFF5B78B0)),
              const SizedBox(width: 5),
              Text(soon ? '곧 도착' : '$mins분', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kBlue)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: kSub),
        ]),
      ),
    );
  }
}


class _Track extends StatelessWidget {
  final double p;
  final String label;
  const _Track({required this.p, required this.label});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final x = (w * p - 12).clamp(0.0, w - 24);
        return SizedBox(
          height: 40,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 18,
              child: Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFDCE7FB), borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              left: 0,
              top: 18,
              child: Container(width: (w * p).clamp(8.0, w), height: 6, decoration: BoxDecoration(color: const Color(0xFF7FA8F5), borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(left: x, top: 0, child: const Icon(Icons.directions_bus_filled_rounded, size: 18, color: kBlue)),
            Positioned(left: 0, right: 0, top: 26, child: Text(label, textAlign: TextAlign.center, style: T.tiny)),
          ]),
        );
      });
}

// ---------------- 노선 화면 (route_page.dart) ----------------
Future<void> openRoute(BuildContext context, Stop s, Arrival a) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusRoutePage(stop: s, arrival: a)));

// 다른 기능 화면에서 이 정류장 상세를 바로 열 때
void openBusStop(BuildContext context, Complex c, Stop s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusPage(complex: c, startStop: s.id)));
