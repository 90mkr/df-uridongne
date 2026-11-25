// 카카오 장소 찾기 — 「중간 다리」 /kk/ 경유 (본부 방만 고침)
// 카카오 정책: 장소 자료는 미리 긁어 모으지 말고 「필요한 순간에」 불러 쓴다.
// 카카오 결과는 저장·묶어 두기(캐시) 모두 안 됨 — 부를 때마다 새로 부르고 화면에만 보여 준다 (장소 번호·링크만 저장 가능).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'dg.dart';
import 'keys.dart';

/// 카카오 로컬 API 한 번 부르기. path 예: 'v2/local/search/keyword.json'
Future<Map?> kkGet(String path, Map<String, String> q, {int cache = 0}) async {
  if (kDataProxy.isEmpty) return null;
  final qs = Uri(queryParameters: {...q, if (cache > 0) '_c': '$cache'}).query;
  try {
    final r = await http.get(Uri.parse('$kDataProxy/kk/$path?$qs'), headers: dgHeaders).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j is Map ? j : null;
  } catch (_) {
    return null;
  }
}

/// 여러 쪽(최대 3쪽 × 15개)까지 모아 오기
Future<List<Map>> kkAll(String kind, Map<String, String> q, {int pages = 3, int cache = 0}) async {
  final out = <Map>[];
  for (var p = 1; p <= pages; p++) {
    final j = await kkGet('v2/local/search/$kind.json', {...q, 'page': '$p', 'size': '15'}, cache: cache);
    if (j == null) break;
    for (final d in (j['documents'] as List? ?? const [])) {
      if (d is Map) out.add(d);
    }
    if ((j['meta'] as Map?)?['is_end'] != false) break;
  }
  return out;
}

const _aptKinds = {'아파트', '주상복합', '오피스텔', '도시형생활주택'};
const _aptSkip = ['상가', '관리사무소', '부동산', '공인중개', '경로당', '어린이집', '주차', '놀이터', '독서실', '유치원', '헬스', '커뮤니티'];

// 단지가 어느 동네 소속인지: 준비된 동네 범위 안이면 그 동네, 아니면 빈칸(그 자리에서 불러오기 모드)
String areaIdAt(LatLng p) {
  final a = areaAt(p);
  return a != null && a.ready && a.contains(p) ? a.id : '';
}

/// 전국 어디든 단지 찾기 — 이름(q)으로, 또는 위치(near) 둘레로
Future<List<Complex>> kkComplexes({String q = '', LatLng? near}) async {
  await loadAreas();
  final docs = <Map>[];
  if (q.trim().isNotEmpty) {
    final t = q.trim();
    docs.addAll(await kkAll('keyword', {'query': t, if (near != null) 'x': '${near.longitude}', if (near != null) 'y': '${near.latitude}'}));
    if (!t.contains('아파트')) docs.addAll(await kkAll('keyword', {'query': '$t 아파트'}, pages: 2));
  } else if (near != null) {
    for (final kw in ['아파트', '주상복합', '오피스텔']) {
      docs.addAll(await kkAll('keyword', {'query': kw, 'x': '${near.longitude}', 'y': '${near.latitude}', 'radius': '2500', 'sort': 'distance'}, pages: kw == '아파트' ? 3 : 1));
    }
  }
  final seen = <String>{};
  final out = <Complex>[];
  for (final d in docs) {
    final name = '${d['place_name'] ?? ''}'.trim();
    final cname = '${d['category_name'] ?? ''}';
    final last = cname.split('>').last.trim();
    if (!_aptKinds.contains(last) || _aptSkip.any(name.contains)) continue;
    final id = '${d['id']}';
    final lat = double.tryParse('${d['y']}'), lng = double.tryParse('${d['x']}');
    if (lat == null || lng == null || !seen.add(id)) continue;
    final p = LatLng(lat, lng);
    out.add(Complex(id: id, name: name, addr: '${d['road_address_name'] ?? ''}'.isNotEmpty ? '${d['road_address_name']}' : '${d['address_name'] ?? ''}', areaId: areaIdAt(p), lat: lat, lng: lng));
  }
  if (near != null) out.sort((a, b) => meters(near, a.pos).compareTo(meters(near, b.pos)));
  return out;
}
