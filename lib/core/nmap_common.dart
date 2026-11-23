// 네이버 지도 공용 모양 (웹·앱 같이)
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

class DnPin {
  final String id, name, sub, icon;
  final LatLng pos;
  final bool selected, apt;
  const DnPin({required this.id, required this.pos, this.name = '', this.sub = '', this.icon = 'pin', this.selected = false, this.apt = false});
}

typedef DnIdle = void Function(LatLng center, double zoom, (LatLng, LatLng)? bounds, bool gesture);

// 지도 조종 (네이버·오픈스트리트맵 어느 쪽이든 같은 말로)
class DnMapCtl {
  Future<void> Function(LatLng p, double zoom, bool animate)? onMove;
  Future<void> Function(List<LatLng> pts, EdgeInsets pad, double maxZoom)? onFit;
  Future<void> move(LatLng p, double zoom, {bool animate = true}) async => onMove?.call(p, zoom, animate);
  Future<void> fit(List<LatLng> pts, EdgeInsets pad, {double maxZoom = 17}) async => onFit?.call(pts, pad, maxZoom);
}

// 자유 모양 점: 기능이 만든 위젯 그대로 (예: 주유소 가격 말풍선). 아래 가운데가 그 위치를 가리킨다.
// key: 모양이 같으면 같은 글자 (네이버 지도는 위젯을 그림으로 한 번 바꿔 쓰므로, 가격·선택 등 모양이 바뀌면 key 도 바꿔 주세요)
class DnMark {
  final String id, key;
  final LatLng pos;
  final Widget child;
  final Size size;
  final VoidCallback? onTap;
  final int z; // 클수록 위
  const DnMark({required this.id, required this.pos, required this.child, required this.size, required this.key, this.onTap, this.z = 0});
}

class DnLine {
  final List<LatLng> points;
  final Color color;
  final double width;
  const DnLine(this.points, {this.color = const Color(0xBF2563EB), this.width = 4});
}

class DnCircle {
  final LatLng pos;
  final double meters;
  final Color fill, line;
  const DnCircle(this.pos, this.meters, {this.fill = const Color(0x142563EB), this.line = const Color(0x592563EB)});
}
