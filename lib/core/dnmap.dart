// 공용 자유 지도 (본부 방만 고침): 휴대폰 앱은 네이버 지도, 웹 미리보기는 오픈스트리트맵.
// 기능 방은 FlutterMap 대신 이것 하나로 — 점(DnMark: 내 위젯 그대로)·선(DnLine)·원(DnCircle)·조종(DnMapCtl).
//   DnMap(center: c.pos, zoom: 15, ctl: myCtl,
//     marks: [DnMark(id: s.id, pos: s.pos, key: '${s.id}|${s.price}|$selected', size: const Size(90, 44), child: _Bubble(...), onTap: () => ...)],
//     lines: [DnLine(routePoints)], circles: [DnCircle(c.pos, 1000)],
//     onMapTap: () => setState(() => sel = null),
//     onIdle: (center, zoom, bounds, gesture) { ... })
//   myCtl.move(pos, 16);  myCtl.fit([a, b], const EdgeInsets.all(60));
// 단지 표시(파란 이름표)는 자동으로 들어간다 (showComplex: false 로 끔).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'icons.dart';
import 'nmap.dart';
import 'theme.dart';

export 'nmap_common.dart';

class DnMap extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<DnMark> marks;
  final List<DnLine> lines;
  final List<DnCircle> circles;
  final VoidCallback? onMapTap, onReady;
  final DnIdle? onIdle;
  final DnMapCtl? ctl;
  final bool showComplex;
  const DnMap({super.key, required this.center, this.zoom = 15, this.marks = const [], this.lines = const [], this.circles = const [], this.onMapTap, this.onIdle, this.onReady, this.ctl, this.showComplex = true});
  @override
  State<DnMap> createState() => _DnMapState();
}

class _DnMapState extends State<DnMap> {
  final fm = MapController();
  bool _moved = false;

  List<DnMark> get _all {
    final c = complex.value;
    return [
      if (widget.showComplex && c != null)
        DnMark(id: '_apt', pos: c.pos, key: 'apt2|${c.name}', size: Size(math.min(170, c.name.length * 12.0 + 24), 80), z: 50, child: _AptTag(c.name)),
      ...widget.marks,
    ];
  }

  @override
  void initState() {
    super.initState();
    if (!naverMapOn && widget.ctl != null) {
      widget.ctl!.onMove = (p, zoom, animate) async => fm.move(p, zoom);
      widget.ctl!.onFit = (pts, pad, maxZoom) async {
        if (pts.isEmpty) return;
        fm.fitCamera(CameraFit.coordinates(coordinates: pts.length == 1 ? [pts.first, pts.first] : pts, padding: pad, maxZoom: maxZoom));
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (naverMapOn) {
      return naverRich(
        center: widget.center,
        zoom: widget.zoom,
        marks: _all,
        lines: widget.lines,
        circles: widget.circles,
        onMapTap: widget.onMapTap,
        onIdle: widget.onIdle,
        onReady: widget.onReady,
        ctl: widget.ctl,
      );
    }
    final ms = [..._all]..sort((a, b) => a.z.compareTo(b.z));
    return FlutterMap(
      mapController: fm,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (_, __) => widget.onMapTap?.call(),
        onMapReady: () => widget.onReady?.call(),
        onPositionChanged: (cam, gesture) {
          if (gesture) _moved = true;
        },
        onMapEvent: (e) {
          if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventScrollWheelZoom || e is MapEventDoubleTapZoomEnd) {
            final cam = e.camera;
            final g = _moved;
            _moved = false;
            widget.onIdle?.call(cam.center, cam.zoom, (cam.visibleBounds.southWest, cam.visibleBounds.northEast), g);
          }
        },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
        if (widget.circles.isNotEmpty)
          CircleLayer(circles: [
            for (final o in widget.circles) CircleMarker(point: o.pos, radius: o.meters, useRadiusInMeter: true, color: o.fill, borderColor: o.line, borderStrokeWidth: 1),
          ]),
        if (widget.lines.isNotEmpty)
          PolylineLayer(polylines: [
            for (final l in widget.lines)
              if (l.points.length > 1) Polyline(points: l.points, strokeWidth: l.width, color: l.color),
          ]),
        MarkerLayer(markers: [
          for (final m in ms)
            Marker(
              point: m.pos,
              width: m.size.width,
              height: m.size.height,
              alignment: Alignment.topCenter,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: m.onTap, child: m.child),
            ),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
      ],
    );
  }
}

// 우리 단지 표시: 웃는 집 + 아래 이름표 (대표님 11-24)
class _AptTag extends StatelessWidget {
  final String name;
  const _AptTag(this.name);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/icons/apt.png', width: 46, height: 46),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white, width: 1)),
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
          ),
          CustomPaint(size: const Size(10, 6), painter: _Tri()),
        ]),
      );
}

class _Tri extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => c.drawPath(
      (ui.Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width / 2, s.height)
        ..close()),
      Paint()..color = kBlue);
  @override
  bool shouldRepaint(_) => false;
}
