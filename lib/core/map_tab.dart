// 지도 탭 (본부 방만 고침): 기능마다 mapPoints() 로 준 점들을 칩으로 바꿔 가며 본다
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../features/registry.dart';
import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'map.dart';
import 'theme.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final ctl = MapController();
  Feature? on;
  String filter = ''; // 고른 기능 안의 거르기 (예: 전화번호부 업종)
  String focus = ''; // 처음 고를 점 (다른 화면의 「지도로 보기」)
  List<MapPoint> pts = [];
  bool loading = false;
  String? forComplex;

  @override
  void initState() {
    super.initState();
    mapAsk.addListener(_ask);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void dispose() {
    mapAsk.removeListener(_ask);
    super.dispose();
  }

  // 다른 화면에서 넘어온 요청: 그 기능·업종을 골라서 연다
  void _ask() {
    final a = mapAsk.value, c = complex.value;
    if (a == null || c == null || !mounted) return;
    mapAsk.value = null;
    final f = mapFeatures.where((x) => x.id == a.feature).firstOrNull;
    if (f == null) return;
    forComplex = c.id;
    _show(f, c, filter: a.filter, focus: a.focus);
  }

  // 지도에 둘 필요 없는 기능 (대표님 11-23: 날씨·쓰레기 뺌)
  static const _skip = {'weather', 'trash'};
  static const _short = {'bus': '버스', 'pharmacy': '약국', 'phonebook': '전화번호부', 'lotto': '복권방', 'postcode': '우체국'};
  List<Feature> get mapFeatures => features.where((f) => f.ready && !_skip.contains(f.id)).toList()..sort((a, b) => a.order.compareTo(b.order));

  Future<void> _show(Feature f, Complex c, {String filter = '', String focus = ''}) async {
    setState(() {
      on = f;
      this.filter = filter;
      this.focus = focus;
      loading = true;
    });
    final p = filter.isEmpty ? await f.mapPoints(c) : await f.mapPointsFor(c, filter);
    if (!mounted || on != f || this.filter != filter) return;
    setState(() {
      pts = p;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: complex,
      builder: (context, c, _) {
        if (c == null) return const Scaffold(body: Center(child: Text('먼저 우리 단지를 골라 주세요', style: T.small)));
        final fs = mapFeatures;
        if (forComplex != c.id) {
          forComplex = c.id;
          pts = [];
          final first = on ?? fs.firstOrNull;
          if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => _show(first, c));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              ctl.move(c.pos, 15);
            } catch (_) {}
          });
        }
        return Scaffold(
          body: Stack(children: [
            DongneMap(key: ValueKey(c.id), center: c.pos, points: pts, controller: ctl, pinFill: on?.tint ?? kSoft, icon: on?.icon ?? '', focus: focus),
            // 기능 고르기: 두 줄로 펼친 색 아이콘 단추
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final f in fs)
                    GestureDetector(
                      onTap: () => _show(f, c, filter: f == on ? filter : ''),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 38,
                        padding: const EdgeInsets.fromLTRB(6, 0, 13, 0),
                        decoration: BoxDecoration(
                          color: on == f ? kBlue : Colors.white,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: on == f ? kBlue : const Color(0xFFDCE3EE)),
                          boxShadow: [BoxShadow(color: (on == f ? kBlue : const Color(0xFF1C3A6E)).withValues(alpha: on == f ? 0.35 : 0.12), blurRadius: 12)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: on == f ? Colors.white : const Color(0xFFF1F5FB), shape: BoxShape.circle),
                            child: LineIcon(f.icon, size: 21),
                          ),
                          const SizedBox(width: 6),
                          Text(_short[f.id] ?? f.name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: on == f ? Colors.white : kInk)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
            // 고른 기능의 거르기 (예: 전화번호부 업종) — 옆으로 넘기는 줄
            if (on != null && on!.mapFilters().isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).padding.top + 10 + 38 * 2 + 6 + 10,
                child: SizedBox(
                  height: 34,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                    for (final m in on!.mapFilters())
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => _show(on!, c, filter: filter == m.id ? '' : m.id),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(5, 0, 11, 0),
                            decoration: BoxDecoration(
                              color: filter == m.id ? kInk : Colors.white,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(color: filter == m.id ? kInk : const Color(0xFFDCE3EE)),
                              boxShadow: kShadow,
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              LineIcon(m.icon, size: 22),
                              const SizedBox(width: 4),
                              Text(m.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: filter == m.id ? Colors.white : kInk)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            if (loading) const Positioned(right: 16, bottom: 16, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 1.6, color: kBlue))),
          ]),
        );
      },
    );
  }
}
