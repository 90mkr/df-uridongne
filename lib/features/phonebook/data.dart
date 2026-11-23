// 동네 전화번호부 — 자료 (이 폴더는 전화번호부 담당 방만 고침)
// 업체: web/data/<동네>.json (collector/collect.py 가 카카오에서 모음)
// 콕플 맛집: 같은 동네 id 의 콕플 자료를 붙여 「콕플 맛집」 표시·구글 별점을 보여 줌
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

class Cat {
  final String id, name, desc;
  const Cat(this.id, this.name, this.desc);
}

// 업종 (아이콘 이름 = id). 앞의 8개가 단지 홈 카드에 나온다.
const kCats = [
  Cat('laundry', '세탁소', '세탁·빨래방'),
  Cat('repair', '수선·열쇠', '옷 수선·열쇠·구두'),
  Cat('ricecake', '떡집·반찬', '떡집·반찬가게'),
  Cat('hair', '미용실', '미용실·헤어'),
  Cat('acad', '학원', '학원·교습소'),
  Cat('kids', '어린이집', '어린이집·유치원'),
  Cat('hosp', '병원', '의원·치과·한의원'),
  Cat('realty', '부동산', '공인중개사'),
  Cat('food', '음식점', '밥집·분식·배달'),
  Cat('cafe', '카페', '커피·디저트'),
  Cat('mart', '마트·편의점', '장보기'),
  Cat('pharm', '약국', '약국'),
  Cat('flower', '꽃집', '꽃·화원'),
  Cat('hardware', '철물·설비', '철물·인테리어·설비'),
  Cat('bank', '은행', '은행·금융'),
  Cat('car', '자동차', '주유·세차·정비'),
  Cat('pet', '반려동물', '동물병원·애견미용'),
  Cat('public', '공공기관', '주민센터·우체국'),
];

Cat catOf(String id) => kCats.firstWhere((c) => c.id == id, orElse: () => kCats.first);

class Kok {
  final double grate;
  final int greviews;
  final int yt;
  const Kok(this.grate, this.greviews, this.yt);
}

class Shop {
  final String id, name, sub, addr, tel;
  final List<String> cats;
  final double lat, lng;
  Kok? kok;
  Shop(this.id, this.name, this.cats, this.sub, this.addr, this.tel, this.lat, this.lng);
  LatLng get pos => LatLng(lat, lng);
  String get kakaoUrl => 'https://place.map.kakao.com/$id';
}

final Map<String, List<Shop>> _cache = {};
final Map<String, List<Shop>> _kokTops = {};
final Map<String, String> _updated = {};

String updatedOf(String areaId) => _updated[areaId] ?? '';
List<Shop> kokTops(String areaId) => _kokTops[areaId] ?? const [];

Future<List<Shop>> shopsOf(String areaId) async {
  final have = _cache[areaId];
  if (have != null) return have;
  final r = await Future.wait([getJson('$dataBase$areaId.json'), getJson('$kKokpleDataUrl$areaId.json')]);
  final j = r[0] is Map ? r[0] as Map : const {};
  final list = <Shop>[
    for (final s in (j['shops'] as List? ?? const []))
      if (s is Map && s['y'] != null && s['x'] != null)
        Shop('${s['id']}', '${s['n'] ?? ''}', [for (final c in (s['c'] as List? ?? const [])) '$c'], '${s['s'] ?? ''}', '${s['a'] ?? ''}', '${s['t'] ?? ''}',
            (s['y'] as num).toDouble(), (s['x'] as num).toDouble())
  ];
  _updated[areaId] = '${j['updated'] ?? ''}';
  final byId = {for (final s in list) s.id: s};
  final tops = <Shop>[];
  final k = r[1] is Map ? r[1] as Map : const {};
  for (final p in (k['places'] as List? ?? const [])) {
    if (p is! Map) continue;
    final id = '${p['id']}';
    final kok = Kok((p['grate'] as num?)?.toDouble() ?? 0, (p['greviews'] as num?)?.toInt() ?? 0, (p['vids'] is List) ? (p['vids'] as List).length : 0);
    var s = byId[id];
    if (s == null) {
      final lat = (p['lat'] as num?)?.toDouble(), lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      s = Shop(id, '${p['name'] ?? ''}', [p['kind'] == 'cafe' ? 'cafe' : 'food'], '${p['cat'] ?? ''}', '${p['addr'] ?? ''}', '${p['tel'] ?? ''}', lat, lng);
      list.add(s);
      byId[id] = s;
    }
    s.kok = kok;
    tops.add(s);
  }
  double score(Shop s) => s.kok!.grate * math.log(s.kok!.greviews + 2);
  tops.sort((a, b) => score(b).compareTo(score(a)));
  _kokTops[areaId] = tops;
  _cache[areaId] = list;
  return list;
}
