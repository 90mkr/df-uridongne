// 웹: 네이버 지도 없음 (기존 지도를 쓴다)
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'nmap_common.dart';
export 'nmap_common.dart';

bool get naverMapOn => false;
Future<void> initNaverMap() async {}


Widget naverMap({Key? key, required LatLng center, double zoom = 15, List<DnPin> pins = const [], void Function(String id)? onPinTap, VoidCallback? onMapTap, DnIdle? onIdle, VoidCallback? onReady, DnMapCtl? ctl}) =>
    const SizedBox();

Widget naverRich({Key? key, required LatLng center, double zoom = 15, List<DnMark> marks = const [], List<DnLine> lines = const [], List<DnCircle> circles = const [], VoidCallback? onMapTap, DnIdle? onIdle, VoidCallback? onReady, DnMapCtl? ctl}) =>
    const SizedBox();
