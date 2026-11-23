// 주유소 자료 (주유소 담당 방만 고침)
// collector/features/gas.py 가 오피넷에서 모아 둔 web/data/gas/<동네id>.json 을 읽는다.
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

// 기름 종류 (오피넷 제품 코드)
const kFuels = [('B027', '휘발유'), ('D047', '경유'), ('K015', 'LPG'), ('B034', '고급휘발유')];
String fuelName(String code) => kFuels.firstWhere((f) => f.$1 == code, orElse: () => (code, code)).$2;

// 반경 고르기 (m)
const kRadii = [2000, 3000, 5000];

const _brands = {
  'SKE': 'SK에너지',
  'GSC': 'GS칼텍스',
  'HDO': '현대오일뱅크',
  'SOL': 'S-OIL',
  'RTE': '알뜰주유소',
  'RTX': '고속도로알뜰',
  'NHO': '농협알뜰',
  'ETC': '자가상표',
  'E1G': 'E1',
  'SKG': 'SK가스',
};
String brandName(String code) => _brands[code] ?? '';

class GasStation {
  final String id, name, brand, tel, addr, lpg;
  final double lat, lng;
  final Map<String, int> prices;
  final bool wash, cvs, maint, kpetro;
  double dist = 0; // 고른 단지에서의 거리 (m)

  GasStation({
    required this.id,
    required this.name,
    required this.brand,
    required this.lat,
    required this.lng,
    required this.prices,
    this.tel = '',
    this.addr = '',
    this.lpg = '',
    this.wash = false,
    this.cvs = false,
    this.maint = false,
    this.kpetro = false,
  });

  LatLng get pos => LatLng(lat, lng);
  int? price(String fuel) => prices[fuel];
  bool get isCharger => lpg == 'Y'; // LPG 충전소 (주유소 아님)

  // 「셀프」는 상호에 들어 있는 경우가 많다
  bool get self => name.contains('셀프');

  static GasStation? fromJson(dynamic j) {
    if (j is! Map || j['y'] == null || j['x'] == null) return null;
    final p = <String, int>{};
    final raw = j['p'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num && v > 0) p['$k'] = v.round();
      });
    }
    return GasStation(
      id: '${j['id']}',
      name: '${j['n'] ?? ''}',
      brand: '${j['b'] ?? ''}',
      lat: (j['y'] as num).toDouble(),
      lng: (j['x'] as num).toDouble(),
      prices: p,
      tel: '${j['tel'] ?? ''}',
      addr: '${j['a'] ?? ''}',
      lpg: '${j['lpg'] ?? ''}',
      wash: j['wash'] == true,
      cvs: j['cvs'] == true,
      maint: j['maint'] == true,
      kpetro: j['kp'] == true,
    );
  }
}

class GasData {
  final String updated, sido;
  final Map<String, double> avg, diff;
  final List<GasStation> stations;
  GasData(this.updated, this.sido, this.avg, this.diff, this.stations);

  // 단지에서 반경 안, 그 기름을 파는 곳만 — 싼 순 (같으면 가까운 순)
  List<GasStation> around(LatLng base, String fuel, int radius) {
    for (final s in stations) {
      s.dist = meters(base, s.pos);
    }
    final list = stations.where((s) => s.dist <= radius && s.price(fuel) != null).toList()
      ..sort((a, b) {
        final c = a.price(fuel)!.compareTo(b.price(fuel)!);
        return c != 0 ? c : a.dist.compareTo(b.dist);
      });
    return list;
  }
}

final Map<String, GasData?> _cache = {};
final Map<String, DateTime> _at = {};

Future<GasData?> loadGas(String areaId) async {
  final t = _at[areaId];
  if (t != null && DateTime.now().difference(t).inMinutes < 10 && _cache[areaId] != null) return _cache[areaId];
  final j = await getJson('${dataBase}gas/$areaId.json');
  if (j is! Map) return _cache[areaId];
  Map<String, double> nums(dynamic m) => {
        if (m is Map)
          for (final e in m.entries)
            if (e.value is num) '${e.key}': (e.value as num).toDouble()
      };
  final st = (j['st'] as List? ?? const []).map(GasStation.fromJson).whereType<GasStation>().toList();
  final d = GasData('${j['updated'] ?? ''}', '${j['sido'] ?? ''}', nums(j['avg']), nums(j['diff']), st);
  _cache[areaId] = d;
  _at[areaId] = DateTime.now();
  return d;
}

// 1,598
String won(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// 「2026-11-23 18:10」 → 「11월 23일 18:10」
String whenText(String u) {
  final m = RegExp(r'^\d{4}-(\d{2})-(\d{2}) (\d{2}:\d{2})').firstMatch(u);
  if (m == null) return u;
  return '${int.parse(m.group(1)!)}월 ${int.parse(m.group(2)!)}일 ${m.group(3)}';
}
