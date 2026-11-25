// 우리 동네 지원금·혜택 — 자료 (이 폴더는 지원금·혜택 방만 고침)
// collector/features/benefit.py 가 매일 web/data/benefit/ 에 모아 둔 것만 읽는다.
//  l_<시군구>.json 우리 구 · s_<시도>.json 시·도 · n.json 전국 · d_<칸>.json 자세히 · y_<시군구>.json·y_n.json 청년정책
import 'dart:convert';
import 'dart:math' as math;

import '../../core/data.dart';

class Benefit {
  final String id, title, sum, field, kind, org, deadline, end, reg;
  final int views;
  final List<String> tags;
  final List<int>? age; // [최소, 최대] (없으면 나이 제한 모름)
  final String scope; // 'gu' 우리 구 · 'sido' 시·도 · 'nat' 전국 · 'youth' 청년정책
  final Map<String, dynamic>? inline; // 청년정책은 자세히가 목록에 같이 들어 있음
  Benefit(this.id, this.title, this.sum, this.field, this.kind, this.org, this.deadline, this.end, this.reg, this.views, this.tags, this.age, this.scope, this.inline);

  static Benefit? from(dynamic j, String scope) {
    if (j is! Map) return null;
    final a = j['a'];
    return Benefit(
      '${j['i'] ?? ''}',
      '${j['t'] ?? ''}',
      '${j['s'] ?? ''}',
      '${j['f'] ?? ''}',
      '${j['k'] ?? ''}',
      '${j['o'] ?? ''}',
      '${j['d'] ?? ''}',
      '${j['e'] ?? ''}',
      '${j['r'] ?? ''}',
      (j['v'] as num?)?.toInt() ?? 0,
      [for (final t in (j['g'] as List? ?? const [])) '$t'],
      a is List && a.length == 2 ? [(a[0] as num).toInt(), (a[1] as num).toInt()] : null,
      scope,
      j['x'] is Map ? Map<String, dynamic>.from(j['x']) : null,
    );
  }

  bool get isYouth => scope == 'youth';

  // 등록한 지 2주 안 → 「새로」
  bool get isNew {
    if (reg.length != 8) return false;
    final d = DateTime.tryParse('${reg.substring(0, 4)}-${reg.substring(4, 6)}-${reg.substring(6, 8)}');
    return d != null && DateTime.now().difference(d).inDays <= 14;
  }

  // 청년정책 마감까지 남은 날 (모르면 null)
  int? get dday {
    if (end.length != 8) return null;
    final d = DateTime.tryParse('${end.substring(0, 4)}-${end.substring(4, 6)}-${end.substring(6, 8)}');
    if (d == null) return null;
    final t = DateTime.now();
    return d.difference(DateTime(t.year, t.month, t.day)).inDays;
  }
}

// 단지의 동네 → 시군구 코드 (k28185 · k11440_1 → 11440 · 송도 → 28185)
String sggOf(String areaId) {
  if (areaId == 'songdo') return '28185';
  final m = RegExp(r'k(\d{5})').firstMatch(areaId);
  return m?.group(1) ?? '';
}

String guName(Complex c) {
  final a = c.area;
  if (a != null && a.gu.isNotEmpty) return a.gu.split(' ').last;
  final w = c.addr.split(' ');
  return w.length > 1 ? w[1] : '우리 구';
}

String sidoName(Complex c) => c.area?.sido ?? '';

class BenefitSet {
  final List<Benefit> gu, sido, nat, youth;
  final String updated;
  BenefitSet(this.gu, this.sido, this.nat, this.youth, this.updated);
  bool get empty => gu.isEmpty && sido.isEmpty && nat.isEmpty && youth.isEmpty;
}

final Map<String, BenefitSet> _cache = {};

Future<List<Benefit>> _rows(String file, String scope) async {
  final j = await getJson('${dataBase}benefit/$file');
  if (j is! Map) return const [];
  return [for (final r in (j['rows'] as List? ?? const [])) Benefit.from(r, scope)].whereType<Benefit>().toList();
}

Future<BenefitSet> loadBenefits(Complex c) async {
  final sgg = sggOf(c.areaId);
  final hit = _cache[sgg];
  if (hit != null) return hit;
  final sd = sgg.length >= 2 ? sgg.substring(0, 2) : '';
  final r = await Future.wait([
    sgg.isEmpty ? Future.value(const <Benefit>[]) : _rows('l_$sgg.json', 'gu'),
    sd.isEmpty ? Future.value(const <Benefit>[]) : _rows('s_$sd.json', 'sido'),
    _rows('n.json', 'nat'),
    sgg.isEmpty ? Future.value(const <Benefit>[]) : _rows('y_$sgg.json', 'youth'),
    _rows('y_n.json', 'youth'),
    getJson('${dataBase}benefit/meta.json'),
  ]);
  final meta = r[5];
  final set = BenefitSet(r[0] as List<Benefit>, r[1] as List<Benefit>, r[2] as List<Benefit>, [...r[3] as List<Benefit>, ...r[4] as List<Benefit>],
      meta is Map ? '${meta['updated'] ?? ''}' : '');
  if (!set.empty) _cache[sgg] = set;
  return set;
}

// 자세히 (청년정책은 목록 안에 들어 있음)
final Map<String, Map<String, dynamic>> _detail = {};

String _bucket(String id) {
  // collector 와 같은 crc32 % 64
  var crc = 0xFFFFFFFF;
  for (final b in utf8.encode(id)) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  crc ^= 0xFFFFFFFF;
  return (crc % 64).toString().padLeft(2, '0');
}

Future<Map<String, dynamic>?> loadDetail(Benefit b) async {
  if (b.inline != null) return b.inline;
  final k = _bucket(b.id);
  if (!_detail.containsKey(k)) {
    final j = await getJson('${dataBase}benefit/d_$k.json');
    if (j is! Map) return null;
    _detail[k] = Map<String, dynamic>.from(j);
  }
  final d = _detail[k]![b.id];
  return d is Map ? Map<String, dynamic>.from(d) : null;
}

// ---------------- 「나에게 맞는 것만」 ----------------
// 본인인증 없이 직접 고르는 것이라 「해당될 수 있는 혜택」으로만 거른다.
const kAges = ['청년', '중장년', '어르신'];
const kAgeRange = {'청년': [19, 39], '중장년': [40, 64], '어르신': [65, 120]};
const kFamily = ['임신출산', '영유아', '학생', '다자녀'];
const kEtc = ['장애', '저소득', '사장님'];
const kTagName = {
  '청년': '청년 (19~39세)',
  '중장년': '중장년 (40~64세)',
  '어르신': '어르신 (65세~)',
  '임신출산': '임신·출산',
  '영유아': '영유아 자녀',
  '학생': '학생 자녀',
  '다자녀': '다자녀',
  '장애': '장애',
  '저소득': '저소득·한부모',
  '사장님': '가게 사장님',
};
// 「누구를 위한 혜택」 꼬리표 (주거는 대상이 아니라 분야라 뺌)
const _targetTags = {'청년', '어르신', '임신출산', '영유아', '학생', '장애', '저소득', '사장님', '다자녀'};

class Me {
  final String age; // '' = 안 고름
  final Set<String> picks;
  const Me(this.age, this.picks);
  bool get isSet => age.isNotEmpty || picks.isNotEmpty;
  Set<String> get all => {if (age.isNotEmpty && age != '중장년') age, ...picks};
  String get label => [if (age.isNotEmpty) kTagName[age]!.split(' ').first, for (final p in picks) kTagName[p]!].join(' · ');

  String encode() => jsonEncode({'a': age, 'p': picks.toList()});
  static Me decode(String? s) {
    try {
      final j = jsonDecode(s ?? '');
      return Me('${j['a'] ?? ''}', {for (final p in (j['p'] as List? ?? const [])) '$p'});
    } catch (_) {
      return const Me('', {});
    }
  }
}

Future<Me> loadMe() async => Me.decode(await prefGet('benefit.me'));
Future<void> saveMe(Me m) => prefSet('benefit.me', m.encode());

// 0 = 딱 나를 위한 것 · 1 = 누구나 받을 수 있는 것 · -1 = 해당 안 됨
int fit(Benefit b, Me me) {
  if (!me.isSet) return 1;
  if (me.age.isNotEmpty && b.age != null) {
    final r = kAgeRange[me.age]!;
    if (b.age![1] < r[0] || b.age![0] > r[1]) return -1;
  }
  final tt = b.tags.where(_targetTags.contains).toSet();
  if (tt.isEmpty) return 1;
  // 청년정책 목록은 청년만
  if (b.isYouth && me.age.isNotEmpty && me.age != '청년') return -1;
  return tt.intersection(me.all).isNotEmpty ? 0 : -1;
}

List<Benefit> filterFor(List<Benefit> l, Me me, String field) {
  final out = <(int, int, Benefit)>[];
  for (var i = 0; i < l.length; i++) {
    final b = l[i];
    if (field.isNotEmpty && b.field != field) continue;
    final f = fit(b, me);
    if (f < 0) continue;
    out.add((f, i, b));
  }
  out.sort((x, y) => x.$1 != y.$1 ? x.$1 - y.$1 : x.$2 - y.$2);
  return [for (final o in out) o.$3];
}

// 정부24 서비스 분야 (자료에 있는 것만 칩으로)
List<String> fieldsOf(List<Benefit> l) {
  final m = <String, int>{};
  for (final b in l) {
    if (b.field.isEmpty) continue;
    m[b.field] = (m[b.field] ?? 0) + 1;
  }
  final k = m.keys.toList()..sort((a, b) => m[b]!.compareTo(m[a]!));
  return k.take(math.min(k.length, 10)).toList();
}
