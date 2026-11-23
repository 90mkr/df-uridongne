// 공용 지도 (본부 방만 고침): 오픈스트리트맵 바탕 + 단지 표시 + 점들. 모든 기능 지도는 이걸 쓴다.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';

class DongneMap extends StatefulWidget {
  final LatLng center;
  final List<MapPoint> points;
  final double zoom;
  final Color pinFill;
  final MapController? controller;
  const DongneMap({super.key, required this.center, this.points = const [], this.zoom = 15, this.pinFill = kSoft, this.controller});
  @override
  State<DongneMap> createState() => _DongneMapState();
}

class _DongneMapState extends State<DongneMap> {
  String? sel;
  @override
  Widget build(BuildContext context) {
    final c = complex.value;
    final pts = widget.points.take(500).toList();
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (_, __) => setState(() => sel = null),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
        MarkerLayer(markers: [
          if (c != null)
            Marker(
              point: c.pos,
              width: 120,
              height: 46,
              alignment: Alignment.topCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(14)),
                  child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                const SizedBox(height: 2),
                const LineIcon('apt', size: 20),
              ]),
            ),
          for (final p in pts)
            Marker(
              point: p.pos,
              width: sel == p.id ? 150 : (p.badge.isEmpty ? 32 : 18.0 + p.badge.length * 9),
              height: sel == p.id ? 70 : 38,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {
                  if (sel == p.id) {
                    p.onTap?.call(context);
                  } else {
                    setState(() => sel = p.id);
                  }
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (sel == p.id)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: cardBox(r: 9),
                      child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  if (p.badge.isEmpty)
                    LineIcon('pin', size: 32, fill: widget.pinFill)
                  else
                    _Badge(p.badge, on: sel == p.id),
                ]),
              ),
            ),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
      ],
    );
  }
}

// 핀 대신 쓰는 짧은 글자 알약 (아래 꼭지로 위치를 가리킴)
class _Badge extends StatelessWidget {
  final String text;
  final bool on;
  const _Badge(this.text, {this.on = false});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: on ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? kBlue : const Color(0xFFCDD3DD)),
            boxShadow: kShadow,
          ),
          child: Text(text, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1, color: on ? Colors.white : kInk)),
        ),
        CustomPaint(size: const Size(8, 5), painter: _Tail(on ? kBlue : const Color(0xFFCDD3DD))),
      ]);
}

class _Tail extends CustomPainter {
  final Color c;
  _Tail(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_Tail o) => o.c != c;
}
