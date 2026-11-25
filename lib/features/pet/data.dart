// 우리 동네 반려동물 — 자료 (이 폴더는 반려동물 테마 방만 고침 · requests/pet-1125-반려동물-테마-방.md)
//
// 1) 동물병원·미용·호텔(돌봄)·용품: 본부 「전국 자료」의 동네 가게 파일(storeBase/<동네>.json) 중 분야 'pet'
//    (소상공인 상가정보 M11101 동물병원 · G22001 애완동물/용품 · S20704 + 인허가 전화번호)
//    동물약국: 같은 파일의 약국('pharm') 중 상호에 「동물」이 든 곳
// 2) 진료시간은 공공자료에 없다 → 상호의 「24시·응급·야간」으로 밤에도 여는 곳을 짚고,
//    밤·주말에는 카카오에서 「24시 동물병원」을 그 자리에서 찾아 화면에만 보여 준다 (카카오 자료는 저장하지 않음)
// 3) 같이 갈 수 있는 곳: 한국관광공사 반려동물 동반여행(KorPetTourService2)
//    목록은 collector/features/pet.py 가 web/data/pet/t_<위도칸>_<경도칸>.json 으로 모아 두고(0.5도 칸),
//    동반 조건(자세히)은 누를 때만 다리로 불러 12시간 묶어 둔다 (개발 계정 하루 1,000회)
import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/dg.dart';
import '../../core/kk.dart';

enum PetKind { hosp, groom, hotel, shop, pharm }

const kPetKinds = [
  (PetKind.hosp, '동물병원', 'hosp'),
  (PetKind.groom, '미용', 'pet'),
  (PetKind.hotel, '호텔·돌봄', 'pet'),
  (PetKind.shop, '용품', 'pet'),
  (PetKind.pharm, '동물약국', 'pharm'),
];

String petKindName(PetKind k) => kPetKinds.firstWhere((x) => x.$1 == k).$2;
String petKindIcon(PetKind k) => kPetKinds.firstWhere((x) => x.$1 == k).$3;

class PetPlace {
  final String id, name, sub, addr, tel;
  final PetKind kind;
  final double lat, lng;
  final bool fromKakao; // 그 자리에서 카카오로 찾은 곳 (저장 안 함)
  String liveTel = '', kakaoId = '';
  bool liveTried = false;
  PetPlace(this.id, this.name, this.kind, this.sub, this.addr, this.tel, this.lat, this.lng, {this.fromKakao = false, String kakao = ''}) {
    kakaoId = kakao;
  }
  LatLng get pos => LatLng(lat, lng);
  String get phone => tel.isNotEmpty ? tel : liveTel;
  // 상호로 짐작한 「밤에도 여는 곳」 (24시·응급·야간)
  bool get night => kind == PetKind.hosp && RegExp(r'24\s*시|24h|24H|이십사|응급|야간|365|올나잇').hasMatch(name);
  String get kakaoUrl => kakaoId.isNotEmpty ? 'https://place.map.kakao.com/$kakaoId' : 'https://map.kakao.com/link/search/${Uri.encodeComponent(name)}';
}

PetKind? kindOf(String name, String sub, List<String> cats) {
  if (cats.contains('pharm')) return name.contains('동물') ? PetKind.pharm : null;
  if (!cats.contains('pet')) return null;
  final s = '$sub $name';
  if (RegExp(r'동물병원|동물의료|동물메디|애니멀메디|애니멀클리닉|동물의원|수의|동물치과').hasMatch(s)) return PetKind.hosp;
  if (RegExp(r'호텔|유치원|위탁|데이케어|펫시터|돌봄|놀이터|캠프').hasMatch(s)) return PetKind.hotel;
  if (RegExp(r'미용|살롱|그루밍|스파|뷰티|트리밍').hasMatch(s)) return PetKind.groom;
  return PetKind.shop;
}

// ---------------- 동네 가게 파일에서 반려동물만 ----------------
final Map<String, List<PetPlace>> _areaCache = {};

Future<List<PetPlace>> _area(String id) async {
  final have = _areaCache[id];
  if (have != null) return have;
  final j = await getJson('$storeBase$id.json', timeout: const Duration(seconds: 25));
  final out = <PetPlace>[];
  for (final s in (j is Map ? (j['shops'] as List? ?? const []) : const [])) {
    if (s is! Map || s['y'] == null || s['x'] == null) continue;
    final cats = [for (final c in (s['c'] as List? ?? const [])) '$c'];
    if (!cats.contains('pet') && !cats.contains('pharm')) continue;
    final name = '${s['n'] ?? ''}', sub = '${s['s'] ?? ''}';
    final k = kindOf(name, sub, cats);
    if (k == null) continue;
    out.add(PetPlace('${s['id']}', name, k, sub, '${s['a'] ?? ''}', '${s['t'] ?? ''}', (s['y'] as num).toDouble(), (s['x'] as num).toDouble()));
  }
  if (j is Map) _areaCache[id] = out; // 받기 실패는 묶어 두지 않음 (다음에 다시)
  return out;
}

// 기준 위치 둘레 반려동물 업체 (가까운 순) — 경계 근처면 옆 동네 파일도 함께
Future<List<(PetPlace, double)>> petNear(LatLng p, {double km = 4}) async {
  await loadAreas();
  final pad = km / 111.0;
  final ids = <String>{
    for (final a in areas)
      if (p.longitude >= a.bbox[0] - pad && p.longitude <= a.bbox[2] + pad && p.latitude >= a.bbox[1] - pad && p.latitude <= a.bbox[3] + pad) a.id
  };
  if (ids.isEmpty) {
    final a = areaAt(p);
    if (a != null) ids.add(a.id);
  }
  final lists = await Future.wait(ids.take(6).map(_area));
  final seen = <String>{};
  final out = <(PetPlace, double)>[];
  for (final l in lists) {
    for (final x in l) {
      if (!seen.add('${x.name}|${x.addr}')) continue;
      final m = meters(p, x.pos);
      if (m <= km * 1000) out.add((x, m));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

// ---------------- 밤에도 여는 동물병원 (카카오, 화면에만) ----------------
String _norm(String t) => t.replaceAll(RegExp(r'[\s()·\-]'), '').toLowerCase();

Future<List<(PetPlace, double)>> nightVets(LatLng p) async {
  final out = <(PetPlace, double)>[];
  final seen = <String>{};
  for (final q in ['24시 동물병원', '응급 동물병원']) {
    final docs = await kkAll('keyword', {'query': q, 'x': '${p.longitude}', 'y': '${p.latitude}', 'radius': '20000', 'sort': 'distance'}, pages: 1);
    for (final d in docs) {
      final cat = '${d['category_name'] ?? ''}';
      final name = '${d['place_name'] ?? ''}';
      if (!cat.contains('동물병원') && !name.contains('동물')) continue;
      final y = double.tryParse('${d['y']}'), x = double.tryParse('${d['x']}');
      if (y == null || x == null || !seen.add(_norm(name))) continue;
      final pl = PetPlace('kk_${d['id']}', name, PetKind.hosp, '동물병원', '${d['road_address_name'] ?? d['address_name'] ?? ''}', '${d['phone'] ?? ''}', y, x,
          fromKakao: true, kakao: '${d['id'] ?? ''}');
      out.add((pl, meters(p, pl.pos)));
    }
  }
  out.removeWhere((x) => !x.$1.night);
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

// 전화번호가 없는 곳: 누르는 순간 카카오에서 찾아 화면에만 (저장하지 않음)
Future<String> petPhone(PetPlace s) async {
  if (s.phone.isNotEmpty || s.liveTried) return s.phone;
  s.liveTried = true;
  final n = _norm(s.name.split(' ').first);
  final docs = await kkAll('keyword', {'query': s.name, 'x': '${s.lng}', 'y': '${s.lat}', 'radius': '300', 'sort': 'distance'}, pages: 1);
  for (final d in docs) {
    final pn = _norm('${d['place_name'] ?? ''}');
    if (pn.isEmpty || n.isEmpty || !(pn.contains(n) || n.contains(pn))) continue;
    s.kakaoId = '${d['id'] ?? ''}';
    s.liveTel = '${d['phone'] ?? ''}'.trim();
    if (s.liveTel.isNotEmpty) break;
  }
  return s.phone;
}

// 밤·주말인가 (동물병원 보통 진료: 평일 9~20시 · 토 9~17시 · 일 휴진 많음)
bool petNightNow(DateTime t) {
  if (t.weekday == DateTime.sunday) return true;
  if (t.weekday == DateTime.saturday) return t.hour < 9 || t.hour >= 17;
  return t.hour < 9 || t.hour >= 20;
}

// ---------------- 같이 갈 수 있는 곳 (관광공사) ----------------
enum TripKind { all, spot, stay, food, shop }

const kTripKinds = [
  (TripKind.all, '전체'),
  (TripKind.spot, '관광지·체험'),
  (TripKind.stay, '숙소'),
  (TripKind.food, '식당·카페'),
  (TripKind.shop, '쇼핑'),
];

class Trip {
  final String id, title, type, addr, tel, img;
  final LatLng pos;
  Trip.fromJson(Map j)
      : id = '${j['id'] ?? ''}',
        title = '${j['t'] ?? ''}',
        type = '${j['ct'] ?? ''}',
        addr = '${j['a'] ?? ''}',
        tel = '${j['tel'] ?? ''}',
        img = '${j['img'] ?? ''}',
        pos = LatLng((j['y'] as num).toDouble(), (j['x'] as num).toDouble());

  TripKind get kind => switch (type) {
        '32' => TripKind.stay,
        '39' => TripKind.food,
        '38' => TripKind.shop,
        _ => TripKind.spot,
      };
  String get kindName => switch (type) {
        '12' => '관광지',
        '14' => '문화시설',
        '15' => '축제·행사',
        '25' => '여행코스',
        '28' => '레포츠',
        '32' => '숙소',
        '38' => '쇼핑',
        '39' => '식당·카페',
        _ => '관광지',
      };
}

final Map<String, List<Trip>> _tileCache = {};

Future<List<Trip>> _tile(int a, int b) async {
  final k = '${a}_$b';
  final have = _tileCache[k];
  if (have != null) return have;
  final j = await getJson('${dataBase}pet/t_$k.json');
  final l = <Trip>[
    for (final x in (j is Map ? (j['items'] as List? ?? const []) : const []))
      if (x is Map && x['y'] != null && x['x'] != null) Trip.fromJson(x)
  ];
  if (j != null) _tileCache[k] = l;
  return l;
}

// 기준 위치에서 km 안 (가까운 순). 칸은 0.5도(약 55km) — 둘레 칸까지 함께
Future<List<(Trip, double)>> tripsNear(LatLng p, {double km = 10}) async {
  final a0 = (p.latitude * 2).floor(), b0 = (p.longitude * 2).floor();
  final r = km > 40 ? 2 : 1;
  final tiles = await Future.wait([
    for (var a = a0 - r; a <= a0 + r; a++)
      for (var b = b0 - r; b <= b0 + r; b++) _tile(a, b)
  ]);
  final out = <(Trip, double)>[];
  for (final t in tiles) {
    for (final x in t) {
      final m = meters(p, x.pos);
      if (m <= km * 1000) out.add((x, m));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

// 동반 조건 (누를 때만, 12시간 묶어 둠)
const kTripFields = [
  ('acmpyTypeCd', '동반 구분'),
  ('acmpyPsblCpam', '동반 가능 동물'),
  ('acmpyNeedMtr', '꼭 챙길 것'),
  ('etcAcmpyInfo', '그 밖의 안내'),
  ('relaPosesFclty', '반려동물 시설'),
  ('relaFrnshPrdlst', '갖춰 둔 물품'),
  ('relaPurcPrdlst', '살 수 있는 물품'),
  ('relaRntlPrdlst', '빌릴 수 있는 물품'),
  ('relaAcdntRiskMtr', '사고 대비'),
];

Future<List<(String, String)>?> tripDetail(String id) async {
  for (final op in ['detailPetTour2', 'detailPetTour']) {
    try {
      final r = await dgGet('https://apis.data.go.kr/B551011/KorPetTourService2/$op?MobileOS=ETC&MobileApp=yogikok&_type=json&contentId=$id', cache: 43200);
      if (r.statusCode != 200) continue;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      var it = (((j is Map ? j['response'] : null) as Map?)?['body'] as Map?)?['items'];
      if (it is Map) it = it['item'];
      if (it is List) it = it.isEmpty ? null : it.first;
      if (it is! Map) return const [];
      return [
        for (final f in kTripFields)
          if ('${it[f.$1] ?? ''}'.trim().isNotEmpty) (f.$2, _clean('${it[f.$1]}'))
      ];
    } catch (_) {}
  }
  return null;
}

String _clean(String s) => s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();

// 걸어서·차로
String petDist(double m) => m < 1200 ? '걸어서 ${math.max(1, (m / 67).ceil())}분' : '차로 ${math.max(3, (m / 400).ceil())}분';
