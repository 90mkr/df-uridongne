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
  List<MapPoint> pts = [];
  bool loading = false;
  String? forComplex;

  // 지도에 둘 필요 없는 기능 (대표님 11-23: 날씨·쓰레기 뺌)
  static const _skip = {'weather', 'trash'};
  static const _short = {'bus': '버스', 'pharmacy': '약국', 'phonebook': '전화번호부', 'lotto': '복권방', 'postcode': '우체국'};
  List<Feature> get mapFeatures => features.where((f) => f.ready && !_skip.contains(f.id)).toList()..sort((a, b) => a.order.compareTo(b.order));

  Future<void> _show(Feature f, Complex c) async {
    setState(() {
      on = f;
      loading = true;
    });
    final p = await f.mapPoints(c);
    if (!mounted || on != f) return;
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
            DongneMap(key: ValueKey(c.id), center: c.pos, points: pts, controller: ctl, pinFill: on?.tint ?? kSoft, icon: on?.icon ?? ''),
            // 기능 고르기: 두 줄로 펼친 색 아이콘 단추
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final f in fs)
                    GestureDetector(
                      onTap: () => _show(f, c),
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
            if (loading) const Positioned(right: 16, bottom: 16, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 1.6, color: kBlue))),
          ]),
        );
      },
    );
  }
}
