// 실거래가 자료 (실거래가 방만 고침)
// collector/features/deals.py 가 시군구별로 모아 둔 web/data/deals/<시군구코드>.json 을 받아
// 고른 단지와 맞는 거래를 찾는다. 단지 정보(세대수 등)는 K-apt 에서 그 자리에서 부른다.
import 'dart:convert';

import '../../core/data.dart';
import '../../core/dg.dart';

class Sale {
  final int ymd, area100, floor, price; // price: 만원
  const Sale(this.ymd, this.area100, this.floor, this.price);
  double get area => area100 / 100;
  int get ym => ymd ~/ 100;
}

class Rent {
  final int ymd, area100, floor, deposit, monthly; // 만원
  final bool renew;
  const Rent(this.ymd, this.area100, this.floor, this.deposit, this.monthly, this.renew);
  double get area => area100 / 100;
  bool get jeonse => monthly == 0;
}

class DealApt {
  final String key, name, umd, jibun, road, kapt;
  String bjd = ''; // 법정동 코드 10자리 (건축물대장 부를 때)
  final int built;
  final bool officetel;
  final List<Sale> sales;
  final List<Rent> rents;
  DealApt(this.key, this.name, this.umd, this.jibun, this.road, this.kapt, this.built, this.officetel, this.sales, this.rents);

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static DealApt? from(dynamic a) {
    if (a is! Map) return null;
    final s = <Sale>[
      for (final x in (a['s'] as List? ?? const []))
        if (x is List && x.length >= 4) Sale(_i(x[0]), _i(x[1]), _i(x[2]), _i(x[3]))
    ];
    final e = <Rent>[
      for (final x in (a['e'] as List? ?? const []))
        if (x is List && x.length >= 6) Rent(_i(x[0]), _i(x[1]), _i(x[2]), _i(x[3]), _i(x[4]), _i(x[5]) == 1)
    ];
    return DealApt('${a['key'] ?? ''}', '${a['n'] ?? ''}', '${a['u'] ?? ''}', '${a['j'] ?? ''}', '${a['r'] ?? ''}', '${a['k'] ?? ''}', _i(a['b']),
        a['o'] == 1, s, e)
      ..bjd = '${a['d'] ?? ''}';
  }

  // 같은 단지가 지번 여러 개로 나뉘어 온 경우 하나로 합침
  DealApt mergeWith(DealApt o) => DealApt(key, name, umd, jibun, road.isNotEmpty ? road : o.road, kapt.isNotEmpty ? kapt : o.kapt,
      built > 0 ? built : o.built, officetel, [...sales, ...o.sales]..sort((a, b) => b.ymd.compareTo(a.ymd)), [...rents, ...o.rents]..sort((a, b) => b.ymd.compareTo(a.ymd)))
    ..bjd = bjd.isNotEmpty ? bjd : o.bjd;
}

class SggDeals {
  final String sgg, updated;
  final List<DealApt> apts;
  const SggDeals(this.sgg, this.updated, this.apts);
}

// 동네 id → 시군구 코드 (k28237 · k28237_2 → 28237, songdo → 28185 연수구)
String? sggOf(Complex c) {
  final id = c.areaId;
  if (id == 'songdo') return '28185';
  final m = RegExp(r'^k(\d{5})').firstMatch(id);
  if (m != null) return m.group(1);
  if (c.addr.contains('연수구')) return '28185';
  return null;
}

final Map<String, SggDeals?> _cache = {};

Future<SggDeals?> loadSgg(String sgg) async {
  if (_cache.containsKey(sgg) && _cache[sgg] != null) return _cache[sgg];
  final j = await getJson('${dataBase}deals/$sgg.json', timeout: const Duration(seconds: 30));
  if (j is! Map) return null;
  final list = <DealApt>[for (final a in (j['apts'] as List? ?? const [])) if (DealApt.from(a) case final d?) d];
  return _cache[sgg] = SggDeals(sgg, '${j['updated'] ?? ''}', list);
}

String normName(String s) => s
    .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
    .replaceAll(RegExp(r'아파트|오피스텔|APT|apt|단지|\s|-|·|,|\.'), '')
    .toLowerCase();

String _roadKey(String s) => s.replaceAll(RegExp(r'\s'), '');

// 고른 단지와 맞는 실거래 단지 (못 찾으면 null)
class Matched {
  final DealApt apt;
  final List<DealApt> sameUmd; // 같은 동네(법정동) 다른 단지
  final SggDeals all;
  const Matched(this.apt, this.sameUmd, this.all);
}

Future<Matched?> matchComplex(Complex c) async {
  final sgg = sggOf(c);
  if (sgg == null) return null;
  final all = await loadSgg(sgg);
  if (all == null || all.apts.isEmpty) return null;
  return matchIn(all, kapt: c.id, name: c.name, addr: c.addr);
}

Matched? matchIn(SggDeals all, {String kapt = '', required String name, String addr = ''}) {
  final wantOffi = name.contains('오피스텔');
  final n = normName(name);
  final rm = RegExp(r'(\S+(?:로|길))\s*(\d+(?:-\d+)?)').firstMatch(addr);
  final road = rm == null ? '' : _roadKey('${rm.group(1)}${rm.group(2)}');
  final jm = RegExp(r'(\S+[동리가])\s+(\d+(?:-\d+)?)').firstMatch(addr);

  int score(DealApt a) {
    var s = 0;
    if (kapt.isNotEmpty && a.kapt == kapt) s += 100;
    if (road.isNotEmpty && a.road.isNotEmpty && _roadKey(a.road) == road) s += 60;
    if (jm != null && a.umd == jm.group(1) && a.jibun == jm.group(2)) s += 60;
    final an = normName(a.name);
    if (an.isNotEmpty && n.isNotEmpty) {
      if (an == n) {
        s += 50;
      } else if ((n.contains(an) || an.contains(n)) && (an.length >= 3 && n.length >= 3)) {
        s += 30;
      }
    }
    if (s > 0 && a.officetel == wantOffi) s += 5;
    if (s > 0) s += (a.sales.length + a.rents.length).clamp(0, 4);
    return s;
  }

  DealApt? best;
  var bs = 0;
  for (final a in all.apts) {
    final s = score(a);
    if (s > bs) {
      bs = s;
      best = a;
    }
  }
  if (best == null || bs < 30) return null;
  // 같은 이름·같은 동네로 나뉜 지번들을 합침
  final bn = normName(best.name);
  var m = best;
  for (final a in all.apts) {
    if (identical(a, best)) continue;
    if (a.umd == best.umd && a.officetel == best.officetel && normName(a.name) == bn) m = m.mergeWith(a);
  }
  if (m.bjd.isEmpty) {
    // 오피스텔 자료엔 법정동 코드가 없어 같은 동 단지 코드를 빌려 씀 (건축물대장 부를 때)
    for (final a in all.apts) {
      if (a.umd == m.umd && a.bjd.length == 10) {
        m.bjd = a.bjd;
        break;
      }
    }
  }
  final same = [
    for (final a in all.apts)
      if (a.umd == m.umd && normName(a.name) != bn && a.sales.isNotEmpty) a
  ]..sort((a, b) => b.sales.first.ymd.compareTo(a.sales.first.ymd));
  return Matched(m, same, all);
}

// ---------------- 보기 좋게 ----------------

// 만원 → 「9억 2,000」 · 「8,500만」
String won(int man) {
  if (man <= 0) return '-';
  final eok = man ~/ 10000, rest = man % 10000;
  String c(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  if (eok == 0) return '${c(rest)}만';
  return rest == 0 ? '$eok억' : '$eok억 ${c(rest)}';
}

// 짧게 「9.2억」
String wonShort(int man) {
  if (man >= 10000) {
    final v = man / 10000;
    return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.0', '')}억';
  }
  return '${(man / 1000).toStringAsFixed(1).replaceAll('.0', '')}천';
}

String rentText(Rent r) => r.jeonse ? '전세 ${won(r.deposit)}' : '월세 ${won(r.deposit)} / ${r.monthly}';

// 전용면적 → 「84㎡」, 공급 평형 어림 「34평형」
String sqm(double a) => '${a.floor()}㎡';
String pyeong(double a) => '${(a * 1.33 / 3.3058).round()}평형';

// 평형 묶음 (전용면적 정수 ㎡ 기준)
int areaGroup(double a) => a.floor();

String ymdText(int ymd) => '${(ymd ~/ 10000) % 100}.${((ymd ~/ 100) % 100).toString().padLeft(2, '0')}.${(ymd % 100).toString().padLeft(2, '0')}';
String monthText(int ymd) => '${(ymd ~/ 100) % 100}월';

// ---------------- 단지 정보 (K-apt, 그 자리에서) ----------------

class AptInfo {
  final Map<String, dynamic> basis, detail;
  final String src; // 'K-apt' · '건축물대장'
  const AptInfo(this.basis, this.detail, {this.src = 'K-apt'});
  String s(String k) {
    final v = basis[k] ?? detail[k];
    return v == null ? '' : '$v'.trim();
  }

  int n(String k) => int.tryParse(s(k).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

final Map<String, AptInfo?> _info = {};

Future<Map<String, dynamic>> _item(String path, String code) async {
  try {
    final r = await dgGet('https://apis.data.go.kr/1613000/AptBasisInfoServiceV5/$path?kaptCode=$code&_type=json', cache: 43200);
    if (r.statusCode != 200) return const {};
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final it = (((j is Map ? j['response'] : null) ?? const {})['body'] ?? const {})['item'];
    return it is Map ? it.cast<String, dynamic>() : const {};
  } catch (_) {
    return const {};
  }
}

Future<AptInfo?> aptInfo(String kapt) async {
  if (kapt.isEmpty) return null;
  if (_info[kapt] != null) return _info[kapt];
  final res = await Future.wait([_item('getAphusBassInfoV5', kapt), _item('getAphusDtlInfoV5', kapt)]);
  if (res[0].isEmpty && res[1].isEmpty) return null;
  return _info[kapt] = AptInfo(res[0], res[1]);
}

// 고른 단지의 K-apt 코드: 단지 id 가 코드면 그대로, 아니면 실거래 자료에 붙여 둔 코드
String kaptOf(Complex c, Matched? m) {
  if (RegExp(r'^A\d{6,}$').hasMatch(c.id)) return c.id;
  return m?.apt.kapt ?? '';
}

// ---------------- 건축물대장 (K-apt 에 없는 오피스텔·작은 단지) ----------------
// 표제부를 동마다 받아 단지 하나로 묶는다: 세대(호)·동 수·최고 층·사용승인·승강기·주차·주용도·구조
final Map<String, AptInfo?> _bld = {};

Future<AptInfo?> bldInfo(String bjd, String jibun) async {
  if (bjd.length != 10 || jibun.isEmpty) return null;
  final k = '$bjd|$jibun';
  if (_bld[k] != null) return _bld[k];
  final san = jibun.startsWith('산');
  final p = jibun.replaceAll('산', '').trim().split('-');
  final bun = (int.tryParse(p[0]) ?? 0).toString().padLeft(4, '0');
  final ji = (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0).toString().padLeft(4, '0');
  try {
    final r = await dgGet(
        'https://apis.data.go.kr/1613000/BldRgstHubService/getBrTitleInfo?sigunguCd=${bjd.substring(0, 5)}&bjdongCd=${bjd.substring(5)}&platGbCd=${san ? 1 : 0}&bun=$bun&ji=$ji&numOfRows=100&pageNo=1&_type=json',
        cache: 43200);
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final raw = ((((j is Map ? j['response'] : null) ?? const {})['body'] ?? const {})['items'] ?? const {});
    final it = raw is Map ? raw['item'] : null;
    final items = <Map>[if (it is List) ...it.whereType<Map>() else if (it is Map) it];
    final main = items.where((x) => '${x['mainAtchGbCd']}' == '0').toList();
    if (main.isEmpty) return null;
    int n(Map x, String f) => x[f] is num ? (x[f] as num).toInt() : int.tryParse('${x[f] ?? ''}'.trim()) ?? 0;
    var hh = 0, ho = 0, top = 0, ev = 0, park = 0;
    var use = '';
    final purps = <String, int>{}, strct = <String, int>{};
    for (final x in main) {
      hh += n(x, 'hhldCnt');
      ho += n(x, 'hoCnt');
      if (n(x, 'grndFlrCnt') > top) top = n(x, 'grndFlrCnt');
      ev += n(x, 'rideUseElvtCnt') + n(x, 'emgenUseElvtCnt');
      final u = '${x['useAprDay'] ?? ''}'.trim();
      if (u.length >= 8 && (use.isEmpty || u.compareTo(use) < 0)) use = u;
      final pp = '${x['etcPurps'] ?? ''}'.contains('오피스텔') ? '오피스텔' : '${x['mainPurpsCdNm'] ?? ''}'.trim();
      if (pp.isNotEmpty) purps[pp] = (purps[pp] ?? 0) + 1;
      final st = '${x['strctCdNm'] ?? ''}'.trim();
      if (st.isNotEmpty) strct[st] = (strct[st] ?? 0) + 1;
    }
    for (final x in items) {
      park += n(x, 'indrMechUtcnt') + n(x, 'oudrMechUtcnt') + n(x, 'indrAutoUtcnt') + n(x, 'oudrAutoUtcnt');
    }
    String most(Map<String, int> m) => m.isEmpty ? '' : (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final basis = <String, dynamic>{
      if (hh > 0) 'kaptdaCnt': hh,
      if (hh == 0 && ho > 0) 'hoCnt': ho,
      'kaptDongCnt': main.length,
      if (top > 0) 'kaptTopFloor': top,
      if (use.isNotEmpty) 'kaptUsedate': use,
      if (ev > 0) 'kaptdEcnt': ev,
      if (park > 0) 'kaptdPcnt': park,
      if (most(purps).isNotEmpty) 'useNm': most(purps),
      if (most(strct).isNotEmpty) 'strctNm': most(strct),
    };
    return _bld[k] = AptInfo(basis, const {}, src: '건축물대장');
  } catch (_) {
    return null;
  }
}

// 단지 정보: K-apt 먼저, 없으면 건축물대장
Future<AptInfo?> infoFor(String kapt, DealApt? a) async {
  final k = kapt.isEmpty ? null : await aptInfo(kapt);
  if (k != null) return k;
  if (a == null) return null;
  return bldInfo(a.bjd, a.jibun);
}
