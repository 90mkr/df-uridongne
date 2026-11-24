// 지도 탭 (본부 방만 고침): 기능마다 mapPoints() 로 준 점들을 칩으로 바꿔 가며 본다
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../features/registry.dart';
import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'map.dart';
import 'theme.dart';

class _Chip {
  final Feature f;
  final String filter, name, icon;
  const _Chip(this.f, this.filter, this.name, this.icon);
}

Widget _chipView(_Chip ch, bool sel, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.fromLTRB(6, 0, 13, 0),
        decoration: BoxDecoration(
          color: sel ? kBlue : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: sel ? kBlue : const Color(0xFFDCE3EE)),
          boxShadow: [BoxShadow(color: (sel ? kBlue : const Color(0xFF1C3A6E)).withValues(alpha: sel ? 0.3 : 0.1), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: sel ? Colors.white : const Color(0xFFF1F5FB), shape: BoxShape.circle),
            child: LineIcon(ch.icon, size: 21),
          ),
          const SizedBox(width: 6),
          Text(ch.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: sel ? Colors.white : kInk)),
        ]),
      ),
    );

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
  final _keys = <String, GlobalKey>{}; // 칩 자리 (다른 화면에서 넘어오면 그 칩이 보이게)
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys['${f.id}|${a.filter}']?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.4, duration: const Duration(milliseconds: 300));
    });
  }

  // 지도 칩 (대표님 11-24): 「전화번호부」라는 묶음 없이 모두 한 줄로 — 행사·주유소·약국… 다음에 업종(세탁소·수선·열쇠…)
  // 버스·지하철·룰렛·기념일·알람·급식·날씨·쓰레기·거래는 지도에 두지 않음
  static const _front = ['events', 'gas', 'pharmacy', 'charger', 'parking', 'postcode', 'lotto'];
  static const _short = {'events': '행사·축제', 'gas': '주유소', 'pharmacy': '약국', 'charger': '충전소', 'parking': '주차장', 'lotto': '복권방', 'postcode': '우체국'};
  List<Feature> get mapFeatures => features.where((f) => f.ready && (_front.contains(f.id) || f.id == 'phonebook')).toList();

  List<_Chip> get chips {
    final out = <_Chip>[];
    for (final id in _front) {
      final f = features.where((x) => x.id == id && x.ready).firstOrNull;
      if (f != null) out.add(_Chip(f, '', _short[id] ?? f.name, f.icon));
    }
    final pb = features.where((x) => x.id == 'phonebook' && x.ready).firstOrNull;
    if (pb != null) {
      for (final m in pb.mapFilters()) {
        out.add(_Chip(pb, m.id, m.name, m.icon));
      }
    }
    return out;
  }

  Future<void> _show(Feature f, Complex c, {String filter = '', String focus = ''}) async {
    // 전화번호부는 업종을 골라야만 (한꺼번에 다 띄우지 않음)
    if (f.id == 'phonebook' && filter.isEmpty) {
      final m = f.mapFilters().firstOrNull;
      if (m == null) return;
      filter = m.id;
    }
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
        final cs = chips;
        if (forComplex != c.id) {
          forComplex = c.id;
          pts = [];
          final first = on ?? cs.firstOrNull?.f;
          if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => _show(first, c, filter: on == null ? (cs.firstOrNull?.filter ?? '') : filter));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              ctl.move(c.pos, 15);
            } catch (_) {}
          });
        }
        return Scaffold(
          body: Stack(children: [
            DongneMap(key: ValueKey(c.id), center: c.pos, points: pts, controller: ctl, pinFill: on?.tint ?? kSoft, icon: on?.icon ?? '', focus: focus),
            // 고르기: 한 줄로 옆으로 넘김 (행사·주유소·약국… 다음에 업종)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 46,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), children: [
                    for (final ch in cs)
                      Padding(
                        key: _keys.putIfAbsent('${ch.f.id}|${ch.filter}', () => GlobalKey()),
                        padding: const EdgeInsets.only(right: 6),
                        child: _chipView(ch, on == ch.f && filter == ch.filter, () => _show(ch.f, c, filter: ch.filter)),
                      ),
                  ]),
                ),
              ),
            ),
            if (loading) const Positioned(right: 16, bottom: 16, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 1.6, color: kBlue))),
          ]),
        );
      },
    );
  }
}
