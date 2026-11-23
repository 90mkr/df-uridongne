// 단지 앞 버스 — 상세 화면 · 노선 창 (이 폴더는 단지 앞 버스 담당 방만 고침)
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart' show MapPoint;
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'route_page.dart';

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
  var mapView = false;
  List<Arrival>? arr;
  var fetching = false;
  DateTime? at;
  String toward = '';
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
      if (at != null && _ago >= _refreshSec && !fetching) {
        _fetch();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
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
    loading = false;
    await _fetch();
  }

  Future<void> _fetch() async {
    final s = stop;
    if (s == null) {
      setState(() {});
      return;
    }
    fetching = true;
    final a = await arrivals(s);
    if (!mounted || stop?.id != s.id) return;
    fetching = false;
    arr = a;
    at = DateTime.now();
    setState(() {});
    if (a != null && a.isNotEmpty) {
      final t = await towardOf(s, a);
      if (mounted && stop?.id == s.id && t != toward) setState(() => toward = t);
    }
  }

  void _pick(int i) {
    if (i == sel && !mapView) return;
    setState(() {
      sel = i;
      arr = null;
      at = null;
      toward = '';
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
  Widget build(BuildContext context) => DetailPage(
        title: '단지 앞 버스',
        icon: 'bus',
        white: false,
        actions: [
          if (stops.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => mapView = !mapView),
              icon: LineIcon(mapView ? 'list' : 'map', size: 20),
              label: Text(mapView ? '목록' : '지도', style: const TextStyle(fontSize: 13, color: kInk, fontWeight: FontWeight.w600)),
            ),
        ],
        body: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : stops.isEmpty
                ? _empty()
                : mapView
                    ? _map()
                    : _list(),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LineIcon('bus', size: 54),
            const SizedBox(height: 14),
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
      child: ListView(padding: const EdgeInsets.fromLTRB(0, 14, 0, 30), children: [
        _tabs(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          child: Container(
            decoration: cardBox(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _head(s),
              _bar(),
              _arrivals(s),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: kPad),
          child: Text('지금 이 정류장으로 오고 있는 버스만 보여요. 노선을 누르면 지나는 정류장과 버스 위치를 볼 수 있어요. · 국토교통부 TAGO 자료', style: T.tiny),
        ),
      ]),
    );
  }

  // 둘레 정류장 고르기 (옆으로 밀기)
  Widget _tabs() => SizedBox(
        height: 54,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          itemCount: stops.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final s = stops[i], on = i == sel;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _pick(i),
              child: Container(
                constraints: const BoxConstraints(minWidth: 96, maxWidth: 168),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFEEF3FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: on ? kBlue : kLine),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (pins.contains(s.id)) ...[
                      Icon(Icons.star_rounded, size: 13, color: on ? kBlue : kSub),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(s.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? kBlue : kInk, height: 1.2)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text('${distText(meters(c.pos, s.pos))}${s.no.isEmpty ? '' : ' · ${s.no}'}', maxLines: 1, style: T.tiny),
                ]),
              ),
            );
          },
        ),
      );

  Widget _head(Stop s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.2)),
              if (toward.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('$toward 방면', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: kInk, height: 1.25)),
              ],
              const SizedBox(height: 5),
              Text('정류장 번호 ${s.no.isEmpty ? '-' : s.no} · 단지에서 ${distText(meters(c.pos, s.pos))}', style: T.small),
            ]),
          ),
          IconButton(
            tooltip: pins.contains(s.id) ? '고정 풀기' : '자주 타는 정류장으로 고정',
            onPressed: () => _pin(s),
            icon: Icon(pins.contains(s.id) ? Icons.star_rounded : Icons.star_outline_rounded, size: 24, color: pins.contains(s.id) ? kBlue : kSub),
          ),
        ]),
      );

  // 다음 새로고침까지 남은 시간
  Widget _bar() {
    final left = at == null ? _refreshSec : (_refreshSec - _ago).clamp(0, _refreshSec);
    return Column(children: [
      LinearProgressIndicator(value: at == null ? null : left / _refreshSec, minHeight: 1, color: kBlue.withValues(alpha: 0.55), backgroundColor: kLine),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 2),
        child: Row(children: [
          Expanded(
            child: Text(fetching && at == null ? '불러오는 중…' : (at == null ? '' : '${_ago < 5 ? '방금' : '$_ago초 전'} 갱신 · $left초 뒤 새로고침'), style: T.tiny),
          ),
          TextButton(
            onPressed: fetching ? null : _fetch,
            style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text('새로고침', style: TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ]);
  }

  Widget _arrivals(Stop s) {
    final a = arr;
    if (a == null) {
      if (fetching || at == null && lastErr == BusErr.none) {
        return const Padding(padding: EdgeInsets.all(28), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
      }
      return _note(errText(lastErr), lastErr == BusErr.blocked ? '크롬 미리보기는 공공데이터 서버가 막혀 있어요. 안드로이드 앱에서 확인해 주세요.' : '잠시 뒤 새로고침해 주세요.');
    }
    if (a.isEmpty) return _note('지금 오는 버스가 없어요', '첫차 전이거나 막차가 끊겼을 수 있어요.');
    final rows = byRoute(a);
    final secGone = _ago;
    return Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        Container(height: 1, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 16)),
        _ArrRow(r: rows[i], gone: secGone, onTap: () => openRoute(context, s, rows[i].first)),
      ],
      const SizedBox(height: 4),
    ]);
  }

  Widget _note(String t, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        child: Column(children: [
          Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: T.small),
        ]),
      );

  Widget _map() => DongneMap(
        center: c.pos,
        zoom: 16,
        points: [
          for (var i = 0; i < stops.length; i++)
            MapPoint(
              id: stops[i].id,
              name: '${stops[i].name} · ${distText(meters(c.pos, stops[i].pos))}',
              pos: stops[i].pos,
              onTap: (_) => _pick(i),
            ),
        ],
      );
}

class _ArrRow extends StatelessWidget {
  final RouteArrivals r;
  final int gone; // 마지막으로 불러온 뒤 지난 초 (화면에서 줄여 보여 줌)
  final VoidCallback onTap;
  const _ArrRow({required this.r, required this.gone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = r.first;
    final secs = (a.secs - gone).clamp(0, 99999);
    final soon = secs <= 120 || a.left <= 1;
    final mins = (secs / 60).ceil();
    final n = r.next;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
        child: Row(children: [
          SizedBox(
            width: 92,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.routeNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
              const SizedBox(height: 2),
              Text('${routeTypeShort(a.type)}${a.lowFloor ? ' · 저상' : ''}', maxLines: 1, style: T.tiny),
            ]),
          ),
          Expanded(
            child: n == null
                ? const SizedBox()
                : Text('다음 ${(n.secs / 60).ceil()}분 · ${n.left}정거장', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(soon ? '곧 도착' : '$mins분',
                style: TextStyle(fontSize: soon ? 15 : 17, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: soon ? kBlue : kInk, height: 1.15)),
            const SizedBox(height: 2),
            Text(a.leftText, style: T.tiny),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20, color: kMute),
        ]),
      ),
    );
  }
}

// ---------------- 노선 화면 (route_page.dart) ----------------
Future<void> openRoute(BuildContext context, Stop s, Arrival a) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusRoutePage(stop: s, arrival: a)));

// 다른 기능 화면에서 이 정류장 상세를 바로 열 때
void openBusStop(BuildContext context, Complex c, Stop s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusPage(complex: c, startStop: s.id)));

