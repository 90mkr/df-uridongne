// 가까운 화장실 — 자료 (본부 방, 11-25 대표님: 「못 찾을 때 진짜 필요」)
// 자료: 행정안전부 공중화장실정보 → 본부 「전국 자료」가 동네별 toilet_<동네>.json 으로 만듦 (storeBase)
// 인터넷이 약해도 뜨게: 받은 동네 파일은 휴대폰에 저장해 두고 먼저 그걸 보여 준다.
import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

class Toilet {
  final String id, name, kind, addr, hours, hoursDtl, org, tel;
  final int men, women;
  final bool disabled, diaper, bell, cctv;
  final LatLng pos;
  Toilet.fromJson(Map j)
      : id = '${j['id'] ?? ''}',
        name = '${j['n'] ?? ''}',
        kind = '${j['k'] ?? ''}',
        addr = '${j['a'] ?? ''}',
        hours = '${j['h'] ?? ''}',
        hoursDtl = '${j['hd'] ?? ''}',
        org = '${j['o'] ?? ''}',
        tel = '${j['t'] ?? ''}',
        men = (j['m'] as num?)?.toInt() ?? 0,
        women = (j['f'] as num?)?.toInt() ?? 0,
        disabled = j['d'] == true,
        diaper = j['b'] == true,
        bell = j['e'] == true,
        cctv = j['c'] == true,
        pos = LatLng((j['y'] as num).toDouble(), (j['x'] as num).toDouble());

  // 지금 열려 있나: true 열림 · false 닫힘 · null 모름
  bool? openAt(DateTime now) {
    final all = '$hours $hoursDtl';
    if (RegExp(r'상시|24\s*시|연중무휴|00:00\s*~\s*24:00|0?0:00\s*~\s*0?0:00').hasMatch(all)) return true;
    final m = RegExp(r'(\d{1,2})\s*[:시]\s*(\d{2})?\s*~\s*(\d{1,2})\s*[:시]\s*(\d{2})?').firstMatch(hoursDtl.isNotEmpty ? hoursDtl : hours);
    if (m == null) return null;
    final a = int.parse(m.group(1)!) * 60 + int.parse(m.group(2) ?? '0');
    var b = int.parse(m.group(3)!) * 60 + int.parse(m.group(4) ?? '0');
    final t = now.hour * 60 + now.minute;
    if (b <= a) return t >= a || t < b; // 밤을 넘기는 곳 (예: 06:00~02:00)
    return t >= a && t < b;
  }

  String get hoursText {
    if (RegExp(r'상시|24\s*시').hasMatch(hours)) return '24시간';
    if (hoursDtl.isNotEmpty) return hoursDtl;
    return hours;
  }
}

// 걸어서 몇 분 (분당 67m)
int walkMin(double m) => (m / 67).ceil().clamp(1, 999);

final Map<String, List<Toilet>> _cache = {};

Future<List<Toilet>> _area(String id, {bool fresh = true}) async {
  final have = _cache[id];
  if (have != null) return have;
  List<Toilet> parse(dynamic j) => [
        for (final x in (j is Map ? (j['toilets'] as List? ?? const []) : const []))
          if (x is Map && x['y'] != null && x['x'] != null) Toilet.fromJson(x)
      ];
  // 1) 휴대폰에 저장해 둔 것 먼저
  List<Toilet> list = const [];
  try {
    final s = await prefGet('toilet.a.$id');
    if (s != null && s.isNotEmpty) list = parse(jsonDecode(s));
  } catch (_) {}
  // 2) 새로 받기 (실패하면 저장본 그대로)
  if (fresh || list.isEmpty) {
    final j = await getJson('${storeBase}toilet_$id.json', timeout: const Duration(seconds: 12));
    if (j is Map) {
      final l = parse(j);
      if (l.isNotEmpty || list.isEmpty) list = l;
      try {
        await prefSet('toilet.a.$id', jsonEncode(j));
      } catch (_) {}
    }
  }
  _cache[id] = list;
  return list;
}

// 내 위치 둘레 화장실 (가까운 순) — 경계 근처면 옆 동네 파일도 함께
Future<List<(Toilet, double)>> toiletsNear(LatLng p, {double km = 3}) async {
  await loadAreas();
  final pad = km / 111.0;
  final ids = <String>{
    for (final a in areas)
      if (p.longitude >= a.bbox[0] - pad && p.longitude <= a.bbox[2] + pad && p.latitude >= a.bbox[1] - pad && p.latitude <= a.bbox[3] + pad) a.id
  };
  final at = areaAt(p);
  if (at != null) ids.add(at.id);
  final lists = await Future.wait([for (final id in ids.take(6)) _area(id)]);
  final seen = <String>{};
  final out = <(Toilet, double)>[];
  for (final l in lists) {
    for (final t in l) {
      if (!seen.add(t.id.isEmpty ? '${t.name}${t.pos}' : t.id)) continue;
      final m = meters(p, t.pos);
      if (m <= km * 1000) out.add((t, m));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

// 급할 때 순서: 열린 곳(또는 모름) 가까운 순 → 지금 닫힌 곳은 맨 아래
List<(Toilet, double)> urgentOrder(List<(Toilet, double)> v, DateTime now) {
  final open = [for (final x in v) if (x.$1.openAt(now) != false) x];
  final closed = [for (final x in v) if (x.$1.openAt(now) == false) x];
  return [...open, ...closed];
}
