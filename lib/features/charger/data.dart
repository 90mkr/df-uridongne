// 충전소 자료 (이 폴더는 충전소 담당 방만 고침)
// ─ 충전소 목록·위치: 자동 제작이 모아 둔 web/data/charger/<동네>.json (collector/features/charger.py)
// ─ 충전기 상태: 앱이 화면을 열 때 가까운 충전소만 환경부 API에 바로 물어봄 (같은 곳은 30초 안에 다시 안 부름)
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/keys.dart';

// ---------------- 충전기 ----------------
// 상태: 1 통신이상 · 2 충전대기(빔) · 3 충전 중 · 4 운영중지 · 5 점검 중 · 9 상태 미확인
enum Use { free, busy, off, unknown }

Use useOf(int stat) => switch (stat) {
      2 => Use.free,
      3 => Use.busy,
      4 || 5 => Use.off,
      _ => Use.unknown,
    };

String useText(int stat) => switch (stat) {
      1 => '통신 끊김',
      2 => '비어 있음',
      3 => '충전 중',
      4 => '운영 중지',
      5 => '점검 중',
      _ => '상태 모름',
    };

// 충전기 종류 (환경부 코드)
String typeText(String t) => switch (t) {
      '01' => 'DC차데모',
      '02' => 'AC완속',
      '03' => 'DC차데모·AC3상',
      '04' => 'DC콤보',
      '05' => 'DC차데모·DC콤보',
      '06' => 'DC차데모·AC3상·DC콤보',
      '07' => 'AC3상',
      '08' => 'DC콤보(완속)',
      '09' => 'NACS',
      '10' => 'DC콤보·NACS',
      _ => '기타',
    };

class Charger {
  final String id, type;
  final int kw;
  int stat;
  String upd; // 상태 바뀐 시각 yyyyMMddHHmmss
  Charger(this.id, this.type, this.kw, this.stat, this.upd);
  // 완속: AC완속·DC콤보(완속), 또는 출력이 표시돼 있고 30kW 미만
  bool get fast => !(type == '02' || type == '08' || (kw > 0 && kw < 30));
  Use get use => useOf(stat);
}

// ---------------- 충전소 ----------------
class Station {
  final String id, name, addr, detail, owner, tel, hours, limit, kind, zcode;
  final bool parkFree;
  final LatLng pos;
  final List<Charger> chargers;
  DateTime? liveAt; // 실시간 상태를 받은 시각 (없으면 모아 둔 자료 기준)
  Station({
    required this.id,
    required this.name,
    required this.addr,
    required this.detail,
    required this.owner,
    required this.tel,
    required this.hours,
    required this.limit,
    required this.kind,
    required this.zcode,
    required this.parkFree,
    required this.pos,
    required this.chargers,
  });

  bool get limited => limit.isNotEmpty;
  bool get hasFast => chargers.any((c) => c.fast);
  bool get hasSlow => chargers.any((c) => !c.fast);
  int get maxKw => chargers.fold(0, (m, c) => c.kw > m ? c.kw : m);

  List<Charger> of(bool? fast) => fast == null ? chargers : chargers.where((c) => c.fast == fast).toList();
  int freeOf(bool? fast) => of(fast).where((c) => c.use == Use.free).length;

  static Station? fromJson(dynamic j) {
    if (j is! Map || j['y'] == null || j['x'] == null) return null;
    return Station(
      id: '${j['i']}',
      name: '${j['n'] ?? ''}',
      addr: '${j['a'] ?? ''}',
      detail: '${j['d'] ?? ''}',
      owner: '${j['b'] ?? ''}',
      tel: '${j['tel'] ?? ''}',
      hours: '${j['t'] ?? ''}',
      limit: '${j['l'] ?? ''}',
      kind: '${j['k'] ?? ''}',
      zcode: '${j['z'] ?? ''}',
      parkFree: j['p'] == 1,
      pos: LatLng((j['y'] as num).toDouble(), (j['x'] as num).toDouble()),
      chargers: [
        for (final c in (j['c'] as List? ?? const []))
          if (c is List && c.length >= 5) Charger('${c[0]}', '${c[1]}', (c[2] as num?)?.toInt() ?? 0, (c[3] as num?)?.toInt() ?? 9, '${c[4]}')
      ],
    );
  }
}

class StationSet {
  final List<Station> all;
  final String updated; // 모은 시각
  final bool live; // 충전소ID로 실시간 상태를 받을 수 있는지
  const StationSet(this.all, this.updated, this.live);
}

final Map<String, StationSet> _cache = {};

// 동네의 충전소 (자동 제작이 모아 둔 것)
Future<StationSet> stationsOf(String areaId) async {
  final have = _cache[areaId];
  if (have != null) return have;
  final j = await getJson('${dataBase}charger/$areaId.json');
  final set = StationSet(
    [for (final x in (j is Map ? (j['s'] as List? ?? const []) : const []))
      if (Station.fromJson(x) case final s?) s
    ],
    j is Map ? '${j['updated'] ?? ''}' : '',
    j is Map && j['live'] == true,
  );
  if (set.all.isNotEmpty) _cache[areaId] = set;
  return set;
}

// ---------------- 실시간 상태 ----------------
const _api = 'https://apis.data.go.kr/B552584/EvCharger/getChargerInfo';
String get _key => kEvKey.isNotEmpty ? kEvKey : kDataGoKrKey;

// 크롬 미리보기(웹)는 공공데이터 서버가 막혀 있어 부르지 않는다
bool get canLive => !kIsWeb && _key.isNotEmpty;

final Map<String, DateTime> _asked = {};

List _items(dynamic j) {
  dynamic x = j;
  if (x is Map && x['response'] is Map) x = (x['response'] as Map)['body'];
  if (x is Map) x = x['items'];
  if (x is Map) x = x['item'];
  if (x is List) return x;
  if (x is Map) return [x];
  return const [];
}

// 충전소 하나의 충전기 상태를 새로 받아 바꿔 넣는다. 바뀐 게 있으면 true.
Future<bool> refreshStation(Station s) async {
  if (!canLive) return false;
  final last = _asked[s.id];
  if (last != null && DateTime.now().difference(last).inSeconds < 30) return false;
  _asked[s.id] = DateTime.now();
  try {
    final k = _key.contains('%') ? _key : Uri.encodeQueryComponent(_key);
    final q = 'serviceKey=$k&pageNo=1&numOfRows=100&dataType=JSON&statId=${Uri.encodeQueryComponent(s.id)}'
        '${s.zcode.isNotEmpty ? '&zcode=${s.zcode}' : ''}';
    final r = await http.get(Uri.parse('$_api?$q')).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return false;
    final rows = _items(jsonDecode(utf8.decode(r.bodyBytes)));
    var hit = false;
    for (final row in rows) {
      if (row is! Map || '${row['statId']}' != s.id) continue;
      final c = s.chargers.where((c) => c.id == '${row['chgerId']}').firstOrNull;
      if (c == null) continue;
      c.stat = int.tryParse('${row['stat']}') ?? c.stat;
      c.upd = '${row['statUpdDt'] ?? c.upd}';
      hit = true;
    }
    if (hit) s.liveAt = DateTime.now();
    return hit;
  } catch (_) {
    return false;
  }
}

// 여러 곳을 한꺼번에 (최대 [max]곳)
Future<void> refreshMany(List<Station> list, {int max = 12}) async {
  if (!canLive) return;
  await Future.wait([for (final s in list.take(max)) refreshStation(s)]);
}

// 「12분 전」 같은 말
String agoText(String upd) {
  if (upd.length < 12) return '';
  final t = DateTime.tryParse('${upd.substring(0, 8)}T${upd.substring(8, 12)}');
  if (t == null) return '';
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return '방금';
  if (m < 60) return '$m분 전';
  if (m < 60 * 24) return '${m ~/ 60}시간 전';
  if (m < 60 * 24 * 30) return '${m ~/ (60 * 24)}일 전';
  return '오래전';
}
