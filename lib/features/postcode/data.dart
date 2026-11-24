// 택배·우편 자료 (이 폴더는 택배·우편 담당 방만 고침)
// - 택배 목록 · 저장 주소: 휴대폰 안에만 저장 (prefGet/prefSet 'postcode.…')
// - 우리 단지 우편번호 · 우체국/편의점 위치: 자동 제작이 모아 둔 web/data/postcode/
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/theme.dart';

// ---------------- 검색 화면 주소 (web/postcode.html) ----------------
String postcodeUrl({String q = '', bool save = false}) {
  final base = kIsWeb && Uri.base.host.endsWith('github.io') ? 'postcode.html' : '${kSiteUrl}postcode.html';
  final p = <String, String>{if (q.trim().isNotEmpty) 'q': q.trim(), if (save) 'save': '1'};
  return p.isEmpty ? base : '$base?${Uri(queryParameters: p).query}';
}

// 검색 화면의 「요기콕에 저장」 단추가 복사해 주는 글 머리
const kAddrClipHead = '[요기콕 주소] ';

// ---------------- 우리 단지 우편번호 ----------------
final Map<String, Map<String, dynamic>> _zips = {};

// [우편번호, 도로명, 지번, 건물 이름] — 아직 못 모은 단지는 null
Future<List<String>?> complexZip(Complex c) async {
  if (c.areaId.isEmpty) return null;
  var m = _zips[c.areaId];
  if (m == null) {
    final j = await getJson('${dataBase}postcode/${c.areaId}.json');
    m = j is Map && j['z'] is Map ? Map<String, dynamic>.from(j['z'] as Map) : <String, dynamic>{};
    _zips[c.areaId] = m;
  }
  final v = m[c.id];
  if (v is List && v.isNotEmpty && '${v[0]}'.isNotEmpty) return [for (final x in v) '$x'];
  return null;
}

// ---------------- 주소 하나 ----------------
class Addr {
  String name; // 「부모님 댁」 (저장할 때만)
  String zip, road, jibun, eng, bname, dong, ho;
  Addr({this.name = '', required this.zip, required this.road, this.jibun = '', this.eng = '', this.bname = '', this.dong = '', this.ho = ''});

  String get unitKo => [if (dong.isNotEmpty) '$dong동', if (ho.isNotEmpty) '$ho호'].join(' ');
  String get unitEn => dong.isNotEmpty && ho.isNotEmpty ? '$dong-$ho' : (ho.isNotEmpty ? '#$ho' : (dong.isNotEmpty ? 'Bldg $dong' : ''));

  // 택배에 쓰는 한글 전체 주소
  String get fullKo => '${zip.isEmpty ? '' : '($zip) '}$road${unitKo.isEmpty ? '' : ', $unitKo'}${bname.isEmpty ? '' : ' ($bname)'}';

  EngParts get en => EngParts.parse(eng, unit: unitEn, zip: zip);

  Map<String, dynamic> toJson() => {'n': name, 'z': zip, 'r': road, 'j': jibun, 'e': eng, 'b': bname, 'd': dong, 'h': ho};
  static Addr? fromJson(dynamic j) {
    if (j is! Map || '${j['r'] ?? ''}'.isEmpty) return null;
    String s(String k) => '${j[k] ?? ''}';
    return Addr(name: s('n'), zip: s('z'), road: s('r'), jibun: s('j'), eng: s('e'), bname: s('b'), dong: s('d'), ho: s('h'));
  }

  // 검색 화면이 복사해 준 글에서 주소 꺼내기
  static Addr? fromClip(String? t) {
    if (t == null || !t.startsWith(kAddrClipHead)) return null;
    try {
      final j = jsonDecode(t.substring(kAddrClipHead.length));
      return Addr.fromJson({'n': '', 'z': j['zip'], 'r': j['road'], 'j': j['jibun'], 'e': j['eng'], 'b': j['bname'], 'd': j['dong'] ?? '', 'h': j['ho'] ?? ''});
    } catch (_) {
      return null;
    }
  }
}

// ---------------- 영문 주소 칸 나누기 ----------------
// 「113, Landmark-ro, Yeonsu-gu, Incheon」 → Address1 「113, Landmark-ro」 · City 「Yeonsu-gu」 · State 「Incheon」
// 「12, Pangyo-ro, Bundang-gu, Seongnam-si, Gyeonggi-do」 → City 「Seongnam-si」, 구는 Address1 에 남김
class EngParts {
  final String a1, a2, city, state, zip;
  const EngParts(this.a1, this.a2, this.city, this.state, this.zip);
  static const country = 'Republic of Korea';

  static EngParts parse(String eng, {String unit = '', String zip = ''}) {
    var t = eng.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (t.isNotEmpty && RegExp(r'korea', caseSensitive: false).hasMatch(t.last)) t.removeLast();
    if (t.length < 3) return EngParts(t.join(', '), unit, '', '', zip);
    final state = t.removeLast();
    final city = t.removeLast();
    return EngParts(t.join(', '), unit, city, state, zip);
  }

  bool get ok => city.isNotEmpty;
  String get oneLine => [if (a2.isNotEmpty) a2, a1, city, state, zip, country].where((e) => e.isNotEmpty).join(', ');
}

// ---------------- 저장 주소 (휴대폰 안에만) ----------------
Future<List<Addr>> loadAddrs() async {
  try {
    final s = await prefGet('postcode.addrs');
    if (s == null || s.isEmpty) return [];
    return [for (final x in jsonDecode(s) as List) Addr.fromJson(x)].whereType<Addr>().toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveAddrs(List<Addr> l) => prefSet('postcode.addrs', jsonEncode([for (final a in l) a.toJson()]));

// ---------------- 택배사 ----------------
class Carrier {
  final String id, name;
  final String Function(String no)? url; // 택배사 조회 화면 (없으면 네이버 검색)
  const Carrier(this.id, this.name, [this.url]);
  String trackUrl(String no) => url?.call(no) ?? 'https://search.naver.com/search.naver?query=${Uri.encodeQueryComponent('$name $no')}';
}

final kCarriers = <Carrier>[
  Carrier('cj', 'CJ대한통운', (n) => 'https://trace.cjlogistics.com/next/tracking.html?wblNo=$n'),
  Carrier('epost', '우체국택배', (n) => 'https://service.epost.go.kr/trace.RetrieveDomRigiTraceList.comm?sid1=$n'),
  Carrier('hanjin', '한진택배', (n) => 'https://www.hanjin.com/kor/CMS/DeliveryMgr/WaybillResult.do?mCode=MN038&schLang=KR&wblnumText2=$n'),
  Carrier('lotte', '롯데택배', (n) => 'https://www.lotteglogis.com/home/reservation/tracking/linkView?InvNo=$n'),
  Carrier('logen', '로젠택배', (n) => 'https://www.ilogen.com/web/personal/trace/$n'),
  const Carrier('cu', 'CU 편의점택배'),
  const Carrier('gs', 'GS25 반값택배'),
  const Carrier('kdexp', '경동택배'),
  const Carrier('daesin', '대신택배'),
  const Carrier('ilyang', '일양로지스'),
  const Carrier('hapdong', '합동택배'),
  const Carrier('coupang', '쿠팡 로켓배송'),
  const Carrier('etc', '그 밖의 택배사'),
];

Carrier carrierById(String id) => kCarriers.firstWhere((c) => c.id == id, orElse: () => kCarriers.last);

// 운송장 번호 모양으로 택배사 짐작 (앞쪽일수록 가능성 높음). 확실하지 않아 고를 수 있게 보여 준다.
List<String> guessCarriers(String no) {
  final n = no.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  final d = RegExp(r'^\d+$').hasMatch(n);
  if (!d) return ['etc'];
  switch (n.length) {
    case 13:
      return ['epost', 'cj', 'etc'];
    case 12:
      return ['cj', 'lotte', 'hanjin', 'coupang', 'cu', 'gs'];
    case 11:
      return ['logen', 'kdexp', 'etc'];
    case 10:
      return ['hanjin', 'cj', 'gs', 'cu'];
    default:
      return n.length > 13 ? ['coupang', 'etc'] : ['cj', 'hanjin', 'lotte', 'etc'];
  }
}

String cleanNo(String s) => s.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

// ---------------- 조회한 택배 (휴대폰 안에만) ----------------
// stage: -1 모름(택배 조회 연결 전) · 0 집하 · 1 이동 중 · 2 배송 출발 · 3 배송 완료
class Parcel {
  final String no, carrier;
  String memo;
  final int at;
  int stage;
  int doneAt;
  String where; // 현재 위치 (조회 연결 뒤)
  Parcel({required this.no, required this.carrier, this.memo = '', required this.at, this.stage = -1, this.doneAt = 0, this.where = ''});
  bool get done => stage >= 3;
  Carrier get c => carrierById(carrier);

  Map<String, dynamic> toJson() => {'no': no, 'c': carrier, 'm': memo, 'at': at, 's': stage, 'd': doneAt, 'w': where};
  static Parcel? fromJson(dynamic j) {
    if (j is! Map || '${j['no'] ?? ''}'.isEmpty) return null;
    return Parcel(
      no: '${j['no']}',
      carrier: '${j['c'] ?? 'etc'}',
      memo: '${j['m'] ?? ''}',
      at: (j['at'] as num?)?.toInt() ?? 0,
      stage: (j['s'] as num?)?.toInt() ?? -1,
      doneAt: (j['d'] as num?)?.toInt() ?? 0,
      where: '${j['w'] ?? ''}',
    );
  }
}

const kStages = ['집하', '이동 중', '배송 출발', '배송 완료'];

// 완료 7일 지난 것은 불러올 때 정리
Future<List<Parcel>> loadParcels() async {
  try {
    final s = await prefGet('postcode.parcels');
    if (s == null || s.isEmpty) return [];
    final cut = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final all = [for (final x in jsonDecode(s) as List) Parcel.fromJson(x)].whereType<Parcel>().toList();
    final keep = all.where((p) => !(p.done && p.doneAt > 0 && p.doneAt < cut)).toList();
    if (keep.length != all.length) await saveParcels(keep);
    return keep;
  } catch (_) {
    return [];
  }
}

Future<void> saveParcels(List<Parcel> l) => prefSet('postcode.parcels', jsonEncode([for (final p in l) p.toJson()]));

// ---------------- 우체국 · 택배 접수 편의점 ----------------
class PostPlace {
  final String id, kind, name, addr, tel; // kind: po 우체국 · cu · gs
  final double lat, lng;
  const PostPlace(this.id, this.kind, this.name, this.addr, this.tel, this.lat, this.lng);
  LatLng get pos => LatLng(lat, lng);
  bool get isPo => kind == 'po';
  String get label => isPo ? (name.contains('취급국') ? '우편취급국' : '우체국') : (kind == 'cu' ? 'CU 편의점택배' : 'GS25 택배');

  // 우체국 창구 기본 시간: 평일 09:00~18:00 (우체국마다 다를 수 있음). 편의점은 대부분 24시간.
  bool openAt(DateTime t) {
    if (!isPo) return true;
    if (t.weekday >= DateTime.saturday) return false;
    final m = t.hour * 60 + t.minute;
    return m >= 9 * 60 && m < 18 * 60;
  }

  String get hours => isPo ? '평일 09:00~18:00 · 주말·공휴일 쉼' : '매장 운영 시간 (대부분 24시간)';
}

final Map<String, List<PostPlace>> _places = {};

Future<List<PostPlace>> postPlaces(Complex c) async {
  if (c.areaId.isEmpty) return [];
  final have = _places[c.areaId];
  if (have != null) return have;
  final j = await getJson('${dataBase}postcode/po_${c.areaId}.json');
  final l = <PostPlace>[
    for (final x in (j is Map ? (j['po'] as List? ?? const []) : const []))
      if (x is Map && x['y'] != null)
        PostPlace('${x['id']}', '${x['k']}', '${x['n']}', '${x['a'] ?? ''}', '${x['t'] ?? ''}', (x['y'] as num).toDouble(), (x['x'] as num).toDouble()),
  ];
  if (l.isNotEmpty) _places[c.areaId] = l;
  return l;
}

// ---------------- 이 폴더 전용 그림 (가는 선 + 옅은 면) ----------------
// 본부 아이콘에 없는 것만 여기서 임시로 그린다 (WORKRULES 4).
const _head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="L" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';
const kPostIcons = {
  // 택배 상자
  'box': '<path d="M8 16l16-8 16 8v17l-16 8-16-8z" fill="F"/><path d="M8 16l16-8 16 8v17l-16 8-16-8z"/><path d="M8 16l16 8 16-8M24 24v17M16 12l16 8v6"/>',
  // 지구 (영문 주소)
  'globe': '<circle cx="24" cy="24" r="15" fill="F"/><circle cx="24" cy="24" r="15"/><path d="M9 24h30M24 9c4.5 4 6.5 9 6.5 15S28.5 35 24 39c-4.5-4-6.5-9-6.5-15S19.5 13 24 9z"/>',
  // 우체통
  'postbox': '<path d="M14 40V18a10 10 0 0 1 20 0v22z" fill="F"/><path d="M14 40V18a10 10 0 0 1 20 0v22z"/><path d="M19 21h10M10 40h28M24 28v5"/>',
  // 별표 집 (저장 주소)
  'saved': '<path d="M9 22L24 10l15 12v17H9z" fill="F"/><path d="M9 22L24 10l15 12v17H9z"/><path d="M24 23l2 4 4.5.6-3.3 3.1.8 4.4-4-2.1-4 2.1.8-4.4-3.3-3.1L22 27z"/>',
};

class PostIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color line, fill;
  const PostIcon(this.name, {super.key, this.size = 28, this.line = kInk, this.fill = kSoft});
  @override
  Widget build(BuildContext context) {
    String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg = '$_head${kPostIcons[name] ?? kPostIcons['box']!}</svg>'.replaceAll('"L"', '"${hex(line)}"').replaceAll('fill="F"', 'fill="${hex(fill)}"');
    return SvgPicture.string(svg, width: size, height: size);
  }
}
