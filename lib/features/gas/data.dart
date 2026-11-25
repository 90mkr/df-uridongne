// 주유소 자료 (주유소 담당 방만 고침)
// collector/features/gas.py 가 오피넷에서 모아 둔 web/data/gas/<동네id>.json 을 읽는다.
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

// 기름 종류 (오피넷 제품 코드)
const kFuels = [('B027', '휘발유'), ('D047', '경유'), ('K015', 'LPG'), ('B034', '고급휘발유')];
String fuelName(String code) => kFuels.firstWhere((f) => f.$1 == code, orElse: () => (code, code)).$2;

// 반경 고르기 (m)
const kRadii = [3000, 5000, 10000];

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
  final Map<String, String> up; // 기름별 가장 최근 받은 시각
  final String sido; // 평균 이름 (예: 인천, 없으면 전국)
  final Map<String, double> avg, diff;
  final List<GasStation> stations;
  GasData(this.up, this.sido, this.avg, this.diff, this.stations);

  String updatedFor(String fuel) => up[fuel] ?? (up.values.isEmpty ? '' : (up.values.toList()..sort()).last);

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

// ── 전국판 (0.3): 오피넷 지역별 최저가 20곳을 시군구·시도 파일로 모아 둠
//   index.json 의 범위(b)로 단지 위치를 품는 파일만 받아 합친다.
dynamic _index;
DateTime? _indexAt;
final Map<String, (DateTime, Map)> _files = {};

Future<Map?> _file(String code) async {
  final c = _files[code];
  if (c != null && DateTime.now().difference(c.$1).inMinutes < 30) return c.$2;
  final j = await getJson('${dataBase}gas/a/$code.json');
  if (j is! Map) return c?.$2;
  _files[code] = (DateTime.now(), j);
  return j;
}

Future<GasData?> loadGas(LatLng pos) async {
  if (_index == null || _indexAt == null || DateTime.now().difference(_indexAt!).inMinutes >= 30) {
    final j = await getJson('${dataBase}gas/index.json');
    if (j is Map) {
      _index = j;
      _indexAt = DateTime.now();
    }
  }
  final idx = _index;
  if (idx is! Map) return null;
  const m = 0.12; // 약 10km 밖 파일까지
  final hit = <Map>[];
  for (final a in (idx['list'] as List? ?? const [])) {
    if (a is! Map || a['b'] is! List || (a['b'] as List).length != 4) continue;
    final b = (a['b'] as List).map((v) => (v as num).toDouble()).toList();
    if (pos.longitude >= b[0] - m && pos.longitude <= b[2] + m && pos.latitude >= b[1] - m && pos.latitude <= b[3] + m) hit.add(a);
  }
  if (hit.isEmpty) return null;
  final files = await Future.wait([for (final a in hit.take(12)) _file('${a['c']}')]);
  final byId = <String, GasStation>{};
  final up = <String, String>{};
  for (final f in files.whereType<Map>()) {
    final u = f['up'];
    if (u is Map) {
      u.forEach((k, v) {
        final o = up['$k'];
        if (o == null || '$v'.compareTo(o) > 0) up['$k'] = '$v';
      });
    }
    for (final x in (f['st'] as List? ?? const [])) {
      final s = GasStation.fromJson(x);
      if (s == null) continue;
      final had = byId[s.id];
      if (had == null) {
        byId[s.id] = s;
      } else {
        had.prices.addAll(s.prices);
      }
    }
  }
  // 평균: 단지가 든 시군구의 시도 평균 → 없으면 전국
  String sidoCode = '';
  double best = double.infinity;
  for (final a in hit.where((a) => a['lv'] == 'sgg')) {
    final b = (a['b'] as List).map((v) => (v as num).toDouble()).toList();
    final inside = pos.longitude >= b[0] && pos.longitude <= b[2] && pos.latitude >= b[1] && pos.latitude <= b[3];
    final area = (b[2] - b[0]) * (b[3] - b[1]) + (inside ? 0 : 100);
    if (area < best) {
      best = area;
      sidoCode = '${a['sido']}';
    }
  }
  final avgs = idx['avg'] is Map ? idx['avg'] as Map : const {};
  final av = (avgs[sidoCode] ?? avgs['00']) as Map?;
  final avg = <String, double>{}, diff = <String, double>{};
  av?.forEach((k, v) {
    if (v is List && v.length == 2 && v[0] is num) {
      avg['$k'] = (v[0] as num).toDouble();
      diff['$k'] = v[1] is num ? (v[1] as num).toDouble() : 0;
    }
  });
  return GasData(up, '${av?['n'] ?? '전국'}', avg, diff, byId.values.toList());
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
