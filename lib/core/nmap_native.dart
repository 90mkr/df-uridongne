// 휴대폰: 네이버 지도 (flutter_naver_map). 열쇠 kNaverMapId (공개용 Client ID)
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';

import 'icons.dart';
import 'keys.dart';
import 'nmap_common.dart';
import 'theme.dart';
export 'nmap_common.dart';

bool _ok = false;
bool get naverMapOn => _ok;

Future<void> initNaverMap() async {
  if (kNaverMapId.isEmpty) return;
  try {
    await FlutterNaverMap().init(clientId: kNaverMapId, onAuthFailed: (e) => debugPrint('네이버 지도 인증 실패: $e'));
    _ok = true;
  } catch (e) {
    debugPrint('네이버 지도 준비 실패: $e');
  }
}

NLatLng _n(LatLng p) => NLatLng(p.latitude, p.longitude);
LatLng _l(NLatLng p) => LatLng(p.latitude, p.longitude);

class DnMapCtl {
  NaverMapController? _c;
  Future<void> move(LatLng p, double zoom, {bool animate = true}) async {
    final u = NCameraUpdate.withParams(target: _n(p), zoom: zoom);
    if (animate) u.setAnimation(animation: NCameraAnimation.easing, duration: const Duration(milliseconds: 420));
    await _c?.updateCamera(u);
  }

  Future<void> fit(List<LatLng> pts, EdgeInsets pad, {double maxZoom = 17}) async {
    if (_c == null || pts.isEmpty) return;
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    final u = NCameraUpdate.fitBounds(NLatLngBounds(southWest: NLatLng(s, w), northEast: NLatLng(n, e)), padding: pad);
    u.setAnimation(animation: NCameraAnimation.easing, duration: const Duration(milliseconds: 450));
    await _c!.updateCamera(u);
    final cam = await _c!.getCameraPosition();
    if (cam.zoom > maxZoom) await move(_l(cam.target), maxZoom);
  }
}

Widget naverMap({Key? key, required LatLng center, double zoom = 15, List<DnPin> pins = const [], void Function(String id)? onPinTap, VoidCallback? onMapTap, DnIdle? onIdle, VoidCallback? onReady, DnMapCtl? ctl}) =>
    _NMap(key: key, center: center, zoom: zoom, pins: pins, onPinTap: onPinTap, onMapTap: onMapTap, onIdle: onIdle, onReady: onReady, ctl: ctl);

class _NMap extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<DnPin> pins;
  final void Function(String id)? onPinTap;
  final VoidCallback? onMapTap, onReady;
  final DnIdle? onIdle;
  final DnMapCtl? ctl;
  const _NMap({super.key, required this.center, required this.zoom, required this.pins, this.onPinTap, this.onMapTap, this.onIdle, this.onReady, this.ctl});
  @override
  State<_NMap> createState() => _NMapState();
}

class _NMapState extends State<_NMap> {
  NaverMapController? c;
  bool gesture = false;
  final Map<String, NOverlayImage> _img = {}; // 아이콘 그림 (한 번 만들어 계속 씀)
  String _sig = '';

  @override
  void didUpdateWidget(covariant _NMap old) {
    super.didUpdateWidget(old);
    _sync();
  }

  Future<NOverlayImage> _icon(String icon, bool sel, bool apt) async {
    final k = '$icon|$sel|$apt';
    final have = _img[k];
    if (have != null) return have;
    final w = apt
        ? Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white, width: 2)),
            child: const LineIcon('apt', size: 22, line: Colors.white, fill: Color(0x40FFFFFF)),
          )
        : icon == 'bus'
            ? SizedBox(width: sel ? 40 : 32, height: sel ? 40 : 32, child: const LineIcon('bus', size: 32))
            : Container(
                width: sel ? 40 : 32,
                height: sel ? 40 : 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(sel ? 13 : 10),
                  border: Border.all(color: sel ? kBlue : const Color(0xFFCFD7E4), width: sel ? 2 : 1),
                ),
                child: LineIcon(icon, size: sel ? 28 : 23),
              );
    final img = await NOverlayImage.fromWidget(widget: w, size: Size(sel ? 40 : (apt ? 34 : 32), sel ? 40 : (apt ? 34 : 32)), context: context);
    _img[k] = img;
    return img;
  }

  Future<void> _sync() async {
    final cc = c;
    if (cc == null || !mounted) return;
    final sig = widget.pins.map((p) => '${p.id}${p.selected ? 1 : 0}').join(',');
    if (sig == _sig) return;
    _sig = sig;
    final set = <NAddableOverlay>{};
    for (final p in widget.pins) {
      final m = NMarker(
        id: p.id,
        position: _n(p.pos),
        icon: await _icon(p.icon, p.selected, p.apt),
        caption: p.name.isEmpty
            ? null
            : NOverlayCaption(
                text: p.name,
                textSize: p.selected || p.apt ? 13 : 11,
                color: p.apt || p.selected ? kBlue : kInk,
                haloColor: Colors.white,
              ),
        subCaption: p.selected && p.sub.isNotEmpty ? NOverlayCaption(text: p.sub, textSize: 10, color: kSub, haloColor: Colors.white) : null,
        isHideCollidedCaptions: !(p.selected || p.apt),
        isForceShowCaption: p.selected || p.apt,
      );
      if (p.selected || p.apt) m.setGlobalZIndex(p.selected ? 250000 : 240000);
      m.setOnTapListener((_) => widget.onPinTap?.call(p.id));
      set.add(m);
      if (!mounted) return;
    }
    if (!mounted || sig != _sig) return;
    await cc.clearOverlays(type: NOverlayType.marker);
    await cc.addOverlayAll(set);
  }

  @override
  Widget build(BuildContext context) => NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(target: _n(widget.center), zoom: widget.zoom),
          locale: const Locale('ko'),
          logoClickEnable: false,
          rotationGesturesEnable: false,
          tiltGesturesEnable: false,
          minZoom: 8,
          maxZoom: 19,
        ),
        onMapReady: (ctl) {
          c = ctl;
          widget.ctl?._c = ctl;
          _sig = '';
          _sync();
          widget.onReady?.call();
        },
        onMapTapped: (_, __) => widget.onMapTap?.call(),
        onCameraChange: (reason, isGesture) {
          if (isGesture) gesture = true;
        },
        onCameraIdle: () async {
          final cc = c;
          if (cc == null) return;
          final g = gesture;
          gesture = false;
          final cam = await cc.getCameraPosition();
          final b = await cc.getContentBounds();
          widget.onIdle?.call(_l(cam.target), cam.zoom, (_l(b.southWest), _l(b.northEast)), g);
        },
      );
}
