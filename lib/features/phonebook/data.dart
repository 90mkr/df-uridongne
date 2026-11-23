// 동네 전화번호부 — 자료 (이 폴더는 전화번호부 담당 방만 고침)
// 업체: web/data/<동네>.json (collector/collect.py 가 카카오에서 모음)
// 콕플 맛집: 같은 동네 id 의 콕플 자료를 붙여 「콕플 맛집」 표시·구글 별점·영업시간을 보여 줌
// 이웃 추천: 파이어베이스 dn_recs (가게마다 한 사람 한 표 + 추천 스티커 최대 3개)
// 사장님 직접 관리: 파이어베이스 dn_owned (관리자가 사장님 확인 후 켬)
// 근처 주차장: 주차장 기능이 모아 둔 web/data/parking/t/<칸>.json 을 읽기만 함 (자료 모양은 주차장 방과 약속)
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/fb.dart';

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
  Cat('flower', '꽃집', '꽃·화원'),
  Cat('food', '음식점', '밥집·분식·배달'),
  Cat('cafe', '카페', '커피·디저트'),
  Cat('mart', '마트·편의점', '장보기'),
  Cat('pharm', '약국', '약국'),
  Cat('hardware', '철물·설비', '철물·인테리어·설비'),
  Cat('bank', '은행', '은행·금융'),
  Cat('car', '자동차', '주유·세차·정비'),
  Cat('pet', '반려동물', '동물병원·애견미용'),
  Cat('public', '공공기관', '주민센터·우체국'),
  Cat('realty', '부동산', '공인중개사'),
];

Cat catOf(String id) => kCats.firstWhere((c) => c.id == id, orElse: () => kCats.first);

class Kok {
  final double grate;
  final int greviews;
  final int yt;
  const Kok(this.grate, this.greviews, this.yt);
}

// 영업 상태
enum Open { open, closing, closed, unknown }

class Shop {
  final String id, name, sub, addr, tel;
  final List<String> cats;
  final double lat, lng;
  Kok? kok;
  List<List<int>> hours = const []; // [여는 요일, 여는 시각(HHMM), 닫는 요일, 닫는 시각] — 요일 0=일요일
  bool owned = false; // 사장님 직접 관리
  String photo = ''; // 대표 사진 주소 (사장님 등록 때)
  Shop(this.id, this.name, this.cats, this.sub, this.addr, this.tel, this.lat, this.lng);
  LatLng get pos => LatLng(lat, lng);
  String get kakaoUrl => 'https://place.map.kakao.com/$id';

  // 지금 영업 중인지 (영업시간 자료가 있을 때만)
  Open openAt(DateTime now) {
    if (hours.isEmpty) return Open.unknown;
    final w = now.weekday % 7; // 0=일
    final t = w * 2400 + now.hour * 100 + now.minute;
    for (final h in hours) {
      if (h.length < 4) continue;
      final a = h[0] * 2400 + h[1];
      var b = h[2] * 2400 + h[3];
      if (b <= a) b += 7 * 2400; // 일요일 밤 → 월요일 새벽
      for (final tt in [t, t + 7 * 2400]) {
        if (tt >= a && tt < b) {
          // 30분 안에 닫으면 「곧 마감」
          final left = _minutes(b) - _minutes(tt);
          return left <= 30 ? Open.closing : Open.open;
        }
      }
    }
    return Open.closed;
  }

  static int _minutes(int v) => (v ~/ 2400) * 1440 + ((v % 2400) ~/ 100) * 60 + v % 100;
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
    final h = p['hours'];
    if (h is List) {
      s.hours = [
        for (final x in h)
          if (x is List && x.length >= 4) [for (final v in x.take(4)) (v as num).toInt()]
      ];
    }
    tops.add(s);
  }
  double score(Shop s) => s.kok!.grate * math.log(s.kok!.greviews + 2);
  tops.sort((a, b) => score(b).compareTo(score(a)));
  _kokTops[areaId] = tops;
  _cache[areaId] = list;
  // 사장님 직접 관리 표시 (있으면)
  _loadOwned(areaId, byId);
  return list;
}

Future<void> _loadOwned(String areaId, Map<String, Shop> byId) async {
  if (!await fbReady()) return;
  try {
    final q = await db.collection('dn_owned').where('area', isEqualTo: areaId).limit(500).get();
    for (final d in q.docs) {
      final s = byId[d.id];
      if (s == null) continue;
      s.owned = true;
      final ph = d.data()['photo'];
      if (ph is String) s.photo = ph;
    }
    recTick.value++;
  } catch (_) {}
}

// ---------------- 이웃 추천 ----------------
// 한 사람이 가게마다 한 표 (문서 이름 = 가게id_회원id), 스티커 최대 3개

class Sticker {
  final String id, text;
  const Sticker(this.id, this.text);
}

const kStickers = [
  Sticker('kind', '친절해요'),
  Sticker('skill', '솜씨 좋아요'),
  Sticker('price', '가격이 착해요'),
  Sticker('fast', '빨라요'),
  Sticker('clean', '깨끗해요'),
  Sticker('regular', '단골이에요'),
];

String stickerText(String id) => kStickers.firstWhere((s) => s.id == id, orElse: () => const Sticker('', '')).text;

class RecSum {
  int n = 0;
  final Map<String, int> st = {};
  bool mine = false;
  List<String> myStickers = const [];
  List<String> get topStickers {
    final e = st.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final x in e.take(3)) x.key];
  }
}

final Map<String, Map<String, RecSum>> _recs = {}; // 동네 → 가게 → 합계
final recTick = ValueNotifier<int>(0); // 추천·사장님 표시가 새로 오면 화면을 다시 그림

Map<String, RecSum> recsOf(String areaId) => _recs[areaId] ?? const {};

Future<void> loadRecs(String areaId) async {
  if (!await fbReady()) return;
  try {
    final q = await db.collection('dn_recs').where('area', isEqualTo: areaId).limit(3000).get();
    final out = <String, RecSum>{};
    final uid = me?.uid;
    for (final d in q.docs) {
      final m = d.data();
      final sid = '${m['sid'] ?? ''}';
      if (sid.isEmpty) continue;
      final r = out.putIfAbsent(sid, () => RecSum());
      r.n++;
      final st = [for (final x in (m['st'] as List? ?? const [])) '$x'];
      for (final x in st) {
        r.st[x] = (r.st[x] ?? 0) + 1;
      }
      if (uid != null && m['uid'] == uid) {
        r.mine = true;
        r.myStickers = st;
      }
    }
    _recs[areaId] = out;
    recTick.value++;
  } catch (_) {}
}

// 추천하기 · 고치기 (로그인 필요). 반환: 실패 이유 (성공이면 null)
Future<String?> saveRec(Shop s, String areaId, List<String> stickers) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  try {
    await db.collection('dn_recs').doc('${s.id}_${u.uid}').set({
      'sid': s.id,
      'area': areaId,
      'uid': u.uid,
      'st': stickers.take(3).toList(),
      'at': fs.FieldValue.serverTimestamp(),
    });
    await loadRecs(areaId);
    return null;
  } catch (_) {
    return '저장하지 못했어요';
  }
}

Future<String?> removeRec(Shop s, String areaId) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  try {
    await db.collection('dn_recs').doc('${s.id}_${u.uid}').delete();
    await loadRecs(areaId);
    return null;
  } catch (_) {
    return '지우지 못했어요';
  }
}

// ---------------- 근처 주차장 (주차장 자료 읽기만) ----------------
class NearLot {
  final String name, fee;
  final double m;
  const NearLot(this.name, this.fee, this.m);
}

final Map<String, List<(String, String, LatLng)>> _lotTiles = {};

Future<void> loadLotsAround(LatLng p) async {
  const tile = 10;
  final keys = <String>{};
  for (final y in [p.latitude - 0.03, p.latitude, p.latitude + 0.03]) {
    for (final x in [p.longitude - 0.035, p.longitude, p.longitude + 0.035]) {
      keys.add('${(y * tile).floor()}_${(x * tile).floor()}');
    }
  }
  await Future.wait([
    for (final k in keys)
      if (!_lotTiles.containsKey(k))
        getJson('${dataBase}parking/t/$k.json').then((j) {
          _lotTiles[k] = [
            for (final x in (j is Map ? (j['p'] as List? ?? const []) : const []))
              if (x is Map && x['y'] != null && x['x'] != null)
                ('${x['n'] ?? ''}', _fee(x), LatLng((x['y'] as num).toDouble(), (x['x'] as num).toDouble()))
          ];
        }),
  ]);
}

String _fee(Map x) {
  final f = '${x['f'] ?? ''}';
  if (f.contains('무료') && !f.contains('유료')) return '무료';
  final bt = x['bt'], bc = x['bc'];
  if (bt is num && bc is num && bt > 0 && bc > 0) return '${bt.toInt()}분 ${bc.toInt()}원';
  return f.contains('유료') ? '유료' : '';
}

// 가게에서 가장 가까운 주차장 (700m 안, 없으면 null)
NearLot? nearestLot(LatLng p) {
  NearLot? best;
  for (final t in _lotTiles.values) {
    for (final (n, f, pos) in t) {
      final d = meters(p, pos);
      if (d <= 700 && (best == null || d < best.m)) best = NearLot(n, f, d);
    }
  }
  return best;
}
