// 충전소 자료 (이 폴더는 충전소 담당 방만 고침)
// ─ 충전소 목록·위치: 자동 제작이 모아 둔 web/data/charger/<동네>.json (collector/features/charger.py)
// ─ 충전기 상태: 앱이 화면을 열 때 가까운 충전소만 환경부 API에 바로 물어봄 (같은 곳은 30초 안에 다시 안 부름)
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
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
      '11' => '버스용 DC콤보',
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
  Set<String> get plugs => plugsOf(type);
  // 내 차 단자에 맞는지 (내 단자를 안 골랐으면 모두 맞음)
  bool fits(Set<String> mine) => type != '11' && (mine.isEmpty || plugs.any(mine.contains)); // 11 = 버스 차고지용
}

// ---------------- 충전 단자 ----------------
// 충전기 종류 코드 → 꽂을 수 있는 단자
const kPlugs = <(String, String, String)>[
  ('combo', 'DC콤보', '현대·기아·제네시스 등 요즘 전기차 대부분 (급속)'),
  ('ac', 'AC완속', '거의 모든 전기차 (완속, 5핀)'),
  ('chademo', 'DC차데모', '옛 레이EV·쏘울EV·리프 등 (급속)'),
  ('ac3', 'AC3상', '르노 SM3 Z.E.·조에 등 (급속)'),
  ('nacs', 'NACS', '테슬라 단자'),
];

String plugName(String id) => kPlugs.where((p) => p.$1 == id).firstOrNull?.$2 ?? id;

Set<String> plugsOf(String t) => switch (t) {
      '01' => {'chademo'},
      '02' => {'ac'},
      '03' => {'chademo', 'ac3'},
      '04' => {'combo'},
      '05' => {'chademo', 'combo'},
      '06' => {'chademo', 'ac3', 'combo'},
      '07' => {'ac3'},
      '08' => {'combo'},
      '09' => {'nacs'},
      '10' => {'combo', 'nacs'},
      _ => const {},
    };

// 내 차 단자 (휴대폰에 기억, 비어 있으면 모두 보기)
final myPlugs = ValueNotifier<Set<String>>({});
bool _plugsLoaded = false;

// 처음이면 true (한 번 물어봄)
Future<bool> loadMyPlugs() async {
  if (_plugsLoaded) return false;
  _plugsLoaded = true;
  final v = await prefGet('charger.plugs');
  if (v == null) return true;
  myPlugs.value = {for (final x in v.split(',')) if (x.isNotEmpty) x};
  return false;
}

Future<void> saveMyPlugs(Set<String> p) async {
  myPlugs.value = {...p};
  await prefSet('charger.plugs', p.join(','));
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

  // 고른 조건(급속만·내 단자)에 맞는 충전기
  List<Charger> pick({bool fastOnly = false, Set<String> plugs = const {}}) =>
      chargers.where((c) => (!fastOnly || c.fast) && c.fits(plugs)).toList();
  List<Charger> of(bool? fast) => fast == null ? chargers : chargers.where((c) => c.fast == fast).toList();
  int freeOf(bool? fast) => of(fast).where((c) => c.use == Use.free).length;

  bool get isPublicPrice => publicPriceFor(this);

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
  if (x is Map && x['response'] is Map) x = x['response'];
  if (x is Map && x['body'] is Map) x = x['body'];
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

// ---------------- 요금 ----------------
// 공공(기후에너지환경부) 충전요금 5단계 (2026-08-01 시행) — web/data/charger/prices.json 으로 바꿀 수 있게
class PriceBook {
  final List<(int, double)> tiers; // (이 출력 미만, 원/kWh) … 마지막은 그 이상
  final List<String> owners; // 이 운영기관 이름이 들어가면 공공요금
  final List<String> seoulOwners; // 서울(시도 11)에서만 공공요금
  final Map<String, (double, double)> ops; // 민간 운영기관 이름 → (급속, 완속) 원/kWh
  final String since, source;
  const PriceBook(this.tiers, this.owners, this.seoulOwners, this.ops, this.since, this.source);
}

const _builtinPrices = PriceBook(
  [(30, 295.0), (50, 307.2), (100, 325.6), (200, 348.4), (100000, 393.1)],
  ['환경부', '기후에너지환경부', '환경공단'],
  ['한국전력', '한전', '서울시', '서울특별시'],
  {},
  '2026-08-01',
  '기후에너지환경부 공공충전요금',
);

PriceBook prices = _builtinPrices;
bool _pricesLoaded = false;

Future<void> loadPrices() async {
  if (_pricesLoaded) return;
  _pricesLoaded = true;
  final j = await getJson('${dataBase}charger/prices.json');
  if (j is! Map) return;
  try {
    final tiers = [
      for (final t in (j['tiers'] as List)) ((t[0] as num).toInt(), (t[1] as num).toDouble()),
    ];
    final ops = <String, (double, double)>{
      for (final e in ((j['ops'] as Map?) ?? const {}).entries)
        if (e.value is List && (e.value as List).length >= 2) '${e.key}': (((e.value as List)[0] as num).toDouble(), ((e.value as List)[1] as num).toDouble()),
    };
    if (tiers.isEmpty) return;
    prices = PriceBook(tiers, [for (final x in (j['owners'] as List? ?? const [])) '$x'], [for (final x in (j['seoulOwners'] as List? ?? const [])) '$x'],
        ops, '${j['since'] ?? ''}', '${j['source'] ?? ''}');
  } catch (_) {}
}

bool publicPriceFor(Station s) =>
    prices.owners.any(s.owner.contains) || (s.zcode == '11' && prices.seoulOwners.any(s.owner.contains));

// 충전기 하나의 원/kWh (모르면 null)
double? priceOf(Station s, Charger c) {
  if (publicPriceFor(s)) {
    if (c.kw <= 0) return null;
    for (final t in prices.tiers) {
      if (c.kw < t.$1) return t.$2;
    }
    return prices.tiers.last.$2;
  }
  for (final e in prices.ops.entries) {
    if (s.owner.contains(e.key)) return c.fast ? e.value.$1 : e.value.$2;
  }
  return null;
}

// 충전소에서 고른 충전기 중 가장 싼 값
double? cheapest(Station s, List<Charger> list) {
  double? best;
  for (final c in list) {
    final p = priceOf(s, c);
    if (p != null && (best == null || p < best)) best = p;
  }
  return best;
}

String wonText(double p) => p == p.roundToDouble() ? '${p.toInt()}원' : '${p.toStringAsFixed(1)}원';

// ---------------- 고장 제보 (파이어베이스 dn_charger_reports) ----------------
// 문서 번호 = 충전소_충전기_사람_날짜 → 같은 사람은 한 충전기에 하루 한 번만 (규칙도 덮어쓰기 막음)
const kReportKinds = ['충전이 안 돼요', '화면·결제 고장', '케이블·커넥터 파손', '자리에 일반차', '기타'];

class Report {
  final String cid, kind, text;
  final DateTime at;
  const Report(this.cid, this.kind, this.text, this.at);
}

String _day(DateTime t) => '${t.year}${'${t.month}'.padLeft(2, '0')}${'${t.day}'.padLeft(2, '0')}';

Future<List<Report>> reportsOf(Station s) async {
  if (!await fbReady()) return const [];
  try {
    final q = await db.collection('dn_charger_reports').where('sid', isEqualTo: s.id).limit(40).get();
    final since = DateTime.now().subtract(const Duration(days: 7));
    final list = <Report>[
      for (final d in q.docs)
        if (d.data()['at'] != null)
          Report('${d.data()['cid'] ?? ''}', '${d.data()['kind'] ?? ''}', '${d.data()['text'] ?? ''}', (d.data()['at'] as dynamic).toDate() as DateTime),
    ]..retainWhere((r) => r.at.isAfter(since));
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  } catch (_) {
    return const [];
  }
}

// null 이면 잘 보냄, 아니면 안내 말
Future<String?> sendReport(Station s, Charger c, String kind, String text) async {
  if (!await fbReady()) return '지금은 보낼 수 없어요';
  final u = me;
  if (u == null) return 'login';
  final day = _day(DateTime.now());
  final id = '${s.id}_${c.id}_${u.uid}_$day';
  try {
    final ref = db.collection('dn_charger_reports').doc(id);
    if ((await ref.get()).exists) return '이 충전기는 오늘 이미 알려 주셨어요';
    await ref.set({'sid': s.id, 'cid': c.id, 'uid': u.uid, 'day': day, 'kind': kind, 'text': text, 'at': FieldValue.serverTimestamp()});
    return null;
  } catch (_) {
    return '보내지 못했어요. 잠시 뒤에 다시 해 주세요';
  }
}
