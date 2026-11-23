// 네이버 지도 공용 모양 (웹·앱 같이)
import 'package:latlong2/latlong.dart';

class DnPin {
  final String id, name, sub, icon;
  final LatLng pos;
  final bool selected, apt;
  const DnPin({required this.id, required this.pos, this.name = '', this.sub = '', this.icon = 'pin', this.selected = false, this.apt = false});
}

typedef DnIdle = void Function(LatLng center, double zoom, (LatLng, LatLng)? bounds, bool gesture);
