// 지도 탭 (본부 방만 고침): 기능마다 mapPoints() 로 준 점들을 칩으로 바꿔 가며 본다
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../features/registry.dart';
import 'data.dart';
import 'feature.dart';
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

  List<Feature> get mapFeatures => features.where((f) => f.ready).toList()..sort((a, b) => a.order.compareTo(b.order));

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
            DongneMap(key: ValueKey(c.id), center: c.pos, points: pts, controller: ctl, pinFill: on?.tint ?? kSoft),
            SafeArea(
              child: SizedBox(
                height: 52,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), children: [
                  for (final f in fs)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _show(f, c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on == f ? kInk : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: on == f ? kInk : kLine),
                            boxShadow: kShadow,
                          ),
                          child: Text(f.name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on == f ? Colors.white : kInk)),
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
