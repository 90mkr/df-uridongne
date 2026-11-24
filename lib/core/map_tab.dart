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
        height: 32,
        padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
        decoration: BoxDecoration(
          color: sel ? kBlue : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: sel ? kBlue : const Color(0xFFDCE3EE)),
          boxShadow: [BoxShadow(color: (sel ? kBlue : const Color(0xFF1C3A6E)).withValues(alpha: sel ? 0.3 : 0.1), blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: sel ? Colors.white : const Color(0xFFF1F5FB), shape: BoxShape.circle),
            child: LineIcon(ch.icon, size: 18),
          ),
          const SizedBox(width: 4),
          Text(ch.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: sel ? Colors.white : kInk)),
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
  bool folded = false; // 업종 칩 접기
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
    folded = true;
    _show(f, c, filter: a.filter, focus: a.focus);
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
        if (m.id == 'pharm') continue; // 약국은 앞 칸(문 연 약국)과 겹침
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
            DongneMap(key: ValueKey(c.id), center: c.pos, points: pts, controller: ctl, pinFill: on?.tint ?? kSoft, icon: on?.icon ?? '', focus: focus, names: on?.id != 'charger'),
            // 고르기: 줄바꿈으로 모두 보이게 (대표님 11-24) — 「접기」로 앞 칸만 남길 수 있음
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Wrap(spacing: 5, runSpacing: 5, children: [
                  for (final ch in cs)
                    if (!folded || _front.contains(ch.f.id) || (on == ch.f && filter == ch.filter))
                      KeyedSubtree(
                        key: _keys.putIfAbsent('${ch.f.id}|${ch.filter}', () => GlobalKey()),
                        child: _chipView(ch, on == ch.f && filter == ch.filter, () {
                          // 고르고 나면 업종 칸은 접어 지도를 넓게 (고른 칸은 남음)
                          setState(() => folded = true);
                          _show(ch.f, c, filter: ch.filter);
                        }),
                      ),
                  GestureDetector(
                    onTap: () => setState(() => folded = !folded),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(color: kInk.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(16)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(folded ? '업종 펼치기' : '접기', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        Icon(folded ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 17, color: Colors.white),
                      ]),
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
