// 공용 지도 (본부 방만 고침): 오픈스트리트맵 바탕 + 단지 표시 + 점들. 모든 기능 지도는 이걸 쓴다.
import 'dart:ui' as ui;

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
  final String icon; // 점 안에 넣을 기능 아이콘 (색 아이콘)
  const DongneMap({super.key, required this.center, this.points = const [], this.zoom = 15, this.pinFill = kSoft, this.controller, this.icon = ''});
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
              width: 170,
              height: 40,
              alignment: Alignment.topCenter,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 170),
                    padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
                    decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: kBlue.withValues(alpha: 0.35), blurRadius: 12)]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const LineIcon('apt', size: 16, line: Colors.white, fill: Color(0x40FFFFFF)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2))),
                    ]),
                  ),
                  CustomPaint(size: const Size(10, 6), painter: _Tail(kBlue)),
                ]),
              ),
            ),
          for (final p in pts.where((p) => p.id != sel)) _marker(p),
          for (final p in pts.where((p) => p.id == sel)) _marker(p),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
      ],
    );
  }

  // 점 하나: 흰 둥근 칸 안에 기능 색 아이콘 + 꼭지 (고르면 파랑 + 위에 이름 카드)
  Marker _marker(MapPoint p) {
    final on = sel == p.id;
    return Marker(
      point: p.pos,
      width: on ? 190 : (p.badge.isEmpty ? 40 : 40.0 + p.badge.length * 8.5),
      height: on ? 92 : 48,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          if (on) {
            p.onTap?.call(context);
          } else {
            setState(() => sel = p.id);
          }
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (on)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                decoration: cardBox(r: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      if (p.sub.isNotEmpty) Text(p.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: kSub)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: kMute),
                ]),
              ),
            if (p.badge.isEmpty) _IconPin(widget.icon.isEmpty ? 'pin' : widget.icon, on: on) else _Badge(p.badge, on: on, icon: widget.icon),
          ]),
        ),
      ),
    );
  }
}

// 기능 아이콘 점 (아기자기하게: 흰 둥근 칸 + 색 아이콘 + 꼭지)
class _IconPin extends StatelessWidget {
  final String icon;
  final bool on;
  const _IconPin(this.icon, {this.on = false});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: on ? 40 : 34,
          height: on ? 40 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(on ? 13 : 11),
            border: Border.all(color: on ? kBlue : const Color(0xFFD5DCE8)),
            boxShadow: [BoxShadow(color: (on ? kBlue : const Color(0xFF1C3A6E)).withValues(alpha: on ? 0.35 : 0.16), blurRadius: on ? 14 : 8)],
          ),
          child: Container(
            width: on ? 32 : 28,
            height: on ? 32 : 28,
            decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: LineIcon(icon, size: on ? 26 : 24),
          ),
        ),
        CustomPaint(size: const Size(10, 6), painter: _Tail(on ? kBlue : Colors.white)),
      ]);
}

// (이 아래는 점 모양)
// 핀 대신 쓰는 짧은 글자 알약 (아래 꼭지로 위치를 가리킴)
class _Badge extends StatelessWidget {
  final String text;
  final bool on;
  final String icon;
  const _Badge(this.text, {this.on = false, this.icon = ''});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
          decoration: BoxDecoration(
            color: on ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? kBlue : const Color(0xFFCDD3DD)),
            boxShadow: kShadow,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon.isNotEmpty && !on) ...[LineIcon(icon, size: 15), const SizedBox(width: 3)],
            Text(text, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.1, color: on ? Colors.white : kInk)),
          ]),
        ),
        CustomPaint(size: const Size(8, 5), painter: _Tail(on ? kBlue : const Color(0xFFCDD3DD))),
      ]);
}

class _Tail extends CustomPainter {
  final Color c;
  _Tail(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_Tail o) => o.c != c;
}
