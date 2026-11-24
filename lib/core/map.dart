// 공용 지도 (본부 방만 고침): 오픈스트리트맵 바탕 + 단지 표시 + 점들. 모든 기능 지도는 이걸 쓴다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'nmap.dart';
import 'theme.dart';

class DongneMap extends StatefulWidget {
  final LatLng center;
  final List<MapPoint> points;
  final double zoom;
  final Color pinFill;
  final MapController? controller;
  final String icon; // 점 안에 넣을 기능 아이콘 (색 아이콘)
  final String focus; // 처음부터 고르고 그쪽으로 옮길 점 id
  const DongneMap({super.key, required this.center, this.points = const [], this.zoom = 15, this.pinFill = kSoft, this.controller, this.icon = '', this.focus = ''});
  @override
  State<DongneMap> createState() => _DongneMapState();
}

class _DongneMapState extends State<DongneMap> {
  String? sel;
  final nctl = DnMapCtl();
  String _focused = '';

  // 「지도로 보기」로 넘어온 점: 고르고 그쪽으로 (점이 다 들어온 뒤 한 번)
  void _applyFocus() {
    final f = widget.focus;
    if (f.isEmpty || f == _focused) return;
    final p = widget.points.where((x) => x.id == f).firstOrNull;
    if (p == null) return;
    _focused = f;
    sel = f;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = complex.value;
      final pts = [p.pos, if (c != null) c.pos];
      if (naverMapOn) {
        nctl.fit(pts, const EdgeInsets.fromLTRB(60, 190, 60, 80), maxZoom: 17);
      } else {
        try {
          widget.controller?.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(60, 190, 60, 80), maxZoom: 17));
        } catch (_) {}
      }
      if (mounted) setState(() {});
    });
  }
  @override
  Widget build(BuildContext context) {
    final c = complex.value;
    final pts = widget.points.take(500).toList();
    _applyFocus();
    // 휴대폰 앱: 네이버 지도 (첫 번 누르면 이름·설명, 두 번 누르면 그 곳 열기)
    if (naverMapOn) {
      return _withCard(naverMap(
        center: widget.center,
        zoom: widget.zoom,
        ctl: nctl,
        onReady: () {
          _focused = '';
          _applyFocus();
        },
        pins: [
          if (c != null) DnPin(id: '_apt', pos: c.pos, name: c.name, apt: true),
          for (final p in pts)
            DnPin(id: p.id, pos: p.pos, name: p.badge.isNotEmpty ? '${p.badge}  ${p.name}' : p.name, sub: p.sub, icon: p.icon.isNotEmpty ? p.icon : (widget.icon.isEmpty ? 'pin' : widget.icon), selected: sel == p.id),
        ],
        onMapTap: () => setState(() => sel = null),
        onIdle: (center, z, b, gesture) {
          if (gesture) _nearest(center, pts);
        },
        onPinTap: (id) {
          if (id == '_apt') return;
          if (pts.any((x) => x.id == id)) setState(() => sel = id);
        },
      ), pts);
    }
    return _withCard(FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (_, __) => setState(() => sel = null),
        onMapEvent: (e) {
          if ((e is MapEventMoveEnd || e is MapEventFlingAnimationEnd) && e.source != MapEventSource.mapController && e.source != MapEventSource.fitCamera) {
            _nearest(e.camera.center, pts);
          }
        },
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
    ), pts);
  }

  // 지도를 움직여 멈추면 가운데에 가장 가까운 곳으로 카드가 바뀜 (야놀자식, 대표님)
  void _nearest(LatLng center, List<MapPoint> pts) {
    if (pts.isEmpty) return;
    MapPoint? best;
    var bd = double.infinity;
    for (final p in pts) {
      final d = meters(center, p.pos);
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    if (best != null && best.id != sel) setState(() => sel = best!.id);
  }

  // 아래 작은 카드 (지도는 그대로 움직일 수 있음)
  Widget _withCard(Widget map, List<MapPoint> pts) {
    final p = sel == null ? null : pts.where((x) => x.id == sel).firstOrNull;
    void close() => setState(() => sel = null);
    return Stack(children: [
      Positioned.fill(child: map),
      if (p != null)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(p.id),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.42),
                child: p.card != null ? SingleChildScrollView(child: p.card!(context, close)) : _PlainCard(p, close),
              ),
            ),
          ),
        ),
    ]);
  }

  // 점 하나: 흰 둥근 칸 안에 기능 색 아이콘 + 꼭지 (고르면 파랑 + 위에 이름 카드)
  Marker _marker(MapPoint p) {
    final on = sel == p.id;
    return Marker(
      point: p.pos,
      width: p.badge.isEmpty ? 44 : 44.0 + p.badge.length * 8.5,
      height: 52,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => setState(() => sel = p.id),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (p.badge.isEmpty) _IconPin(p.icon.isNotEmpty ? p.icon : (widget.icon.isEmpty ? 'pin' : widget.icon), on: on) else _Badge(p.badge, on: on, icon: widget.icon),
          ]),
        ),
      ),
    );
  }
}

// 지도 아래 기본 카드: 이름·설명 + 자세히
class _PlainCard extends StatelessWidget {
  final MapPoint p;
  final VoidCallback close;
  const _PlainCard(this.p, this.close);
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: p.onTap == null ? null : () => p.onTap!(context),
          child: Ink(
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.badge.isNotEmpty && !p.name.contains(p.badge) ? '${p.name}  ${p.badge}' : p.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.3)),
                  if (p.sub.isNotEmpty) ...[const SizedBox(height: 3), Text(p.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.small)],
                ]),
              ),
              if (p.onTap != null) const Text('자세히', style: TextStyle(fontSize: 12.5, color: kBlue, fontWeight: FontWeight.w700)),
              if (p.onTap != null) const Icon(Icons.chevron_right_rounded, color: kBlue, size: 20),
              IconButton(onPressed: close, icon: const Icon(Icons.close_rounded, size: 20, color: kMute)),
            ]),
          ),
        ),
      );
}

// 기능 아이콘 점 (아기자기하게: 흰 둥근 칸 + 색 아이콘 + 꼭지)
class _IconPin extends StatelessWidget {
  final String icon;
  final bool on;
  const _IconPin(this.icon, {this.on = false});
  @override
  Widget build(BuildContext context) {
    // 버스 정류장: 상자 없이 통통한 버스 + 정류장 기둥 (대표님 11-23)
    if (icon == 'bus') {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedScale(
          scale: on ? 1.25 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: (on ? kBlue : const Color(0xFF1C3A6E)).withValues(alpha: on ? 0.35 : 0.18), blurRadius: 10)]),
            child: const LineIcon('bus', size: 30),
          ),
        ),
        Container(width: 3, height: 7, decoration: BoxDecoration(color: on ? kBlue : const Color(0xFF24539F), borderRadius: BorderRadius.circular(2))),
        Container(width: 10, height: 3, decoration: BoxDecoration(color: (on ? kBlue : const Color(0xFF24539F)).withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2))),
      ]);
    }
    return _box();
  }

  Widget _box() => Column(mainAxisSize: MainAxisSize.min, children: [
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
