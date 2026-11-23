// 웹: 네이버 지도 없음 (기존 지도를 쓴다)
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'nmap_common.dart';
export 'nmap_common.dart';

bool get naverMapOn => false;
Future<void> initNaverMap() async {}

class DnMapCtl {
  Future<void> move(LatLng p, double zoom, {bool animate = true}) async {}
  Future<void> fit(List<LatLng> pts, EdgeInsets pad, {double maxZoom = 17}) async {}
}

Widget naverMap({Key? key, required LatLng center, double zoom = 15, List<DnPin> pins = const [], void Function(String id)? onPinTap, VoidCallback? onMapTap, DnIdle? onIdle, VoidCallback? onReady, DnMapCtl? ctl}) =>
    const SizedBox();
