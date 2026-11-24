// 주변 행사·축제 자료 (행사 담당: 본부, 대표님 요청 11-24)
// ① 자동 수집: web/data/events/ev_<동네>.json (collector/features/events.py — 한국관광공사 행사정보 · 전국문화축제표준데이터, 매일 새벽)
// ② 동네 소식: 파이어베이스 dn_events (이용자 「행사 알리기」 → 관리자 승인 st=ok 뒤 공개)
//    scope 'apt' = 그 단지에만, 'near' = 근처 단지 모두(30km 안)
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/fb.dart';

const kEvKinds = ['축제', '공연', '전시', '동네 소식'];

class Ev {
  final String id, title, place, kind, src, tel, desc, fee, time;
  final DateTime start, end;
  final LatLng pos;
  final String img; // 원본 사진 주소 (자동 수집)
  final List<String> thumbs, photos; // base64 (동네 소식)
  final String st, uid, name, scope, cid;
  const Ev({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.place,
    required this.pos,
    required this.kind,
    this.img = '',
    this.thumbs = const [],
    this.photos = const [],
    this.src = '',
    this.tel = '',
    this.desc = '',
    this.fee = '',
    this.time = '',
    this.st = 'ok',
    this.uid = '',
    this.name = '',
    this.scope = 'near',
    this.cid = '',
  });

  bool get local => kind == '동네 소식';
  bool get hasPhoto => img.isNotEmpty || thumbs.isNotEmpty;
  bool get free => fee.contains('무료') || (fee.isEmpty && local);
  Uint8List? get thumb => thumbs.isEmpty ? null : base64Decode(thumbs.first);

  String get period {
    String d(DateTime t) => '${t.month}.${t.day}';
    if (start.year == end.year && start.month == end.month && start.day == end.day) return '${start.year}.${d(start)}';
    return '${d(start)} ~ ${d(end)}';
  }

  bool liveAt(DateTime now) {
    final t = DateTime(now.year, now.month, now.day);
    return !t.isBefore(start) && !t.isAfter(end);
  }

  bool overlaps(DateTime a, DateTime b) => !end.isBefore(a) && !start.isAfter(b);
}

DateTime? _ymd(String s) {
  if (s.length < 8) return null;
  return DateTime.tryParse('${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}');
}

String _kindOf(String t) {
  if (RegExp('공연|콘서트|뮤지컬|연극|음악회|오페라|발레|국악|버스킹').hasMatch(t)) return '공연';
  if (RegExp('전시|展|아트페어|비엔날레|미술|사진전|박람회').hasMatch(t)) return '전시';
  return '축제';
}

final Map<String, List<Ev>> _auto = {};

Future<List<Ev>> autoEvents(String areaId) async {
  if (areaId.isEmpty) return const [];
  final have = _auto[areaId];
  if (have != null) return have;
  final j = await getJson('${dataBase}events/ev_$areaId.json');
  final out = <Ev>[];
  final today = DateTime.now();
  for (final x in (j is Map ? (j['ev'] as List? ?? const []) : const [])) {
    if (x is! Map) continue;
    final s = _ymd('${x['s'] ?? ''}'), e = _ymd('${x['e'] ?? ''}');
    final lat = (x['y'] as num?)?.toDouble(), lng = (x['x'] as num?)?.toDouble();
    if (s == null || e == null || lat == null || lng == null) continue;
    if (e.isBefore(DateTime(today.year, today.month, today.day))) continue; // 끝난 행사 숨김
    final t = '${x['t'] ?? ''}';
    out.add(Ev(
      id: 'a${x['id'] ?? t.hashCode}',
      title: t,
      start: s,
      end: e,
      place: '${x['p'] ?? ''}',
      pos: LatLng(lat, lng),
      kind: _kindOf(t),
      img: '${x['img'] ?? ''}'.replaceFirst('http://', 'https://'),
      src: '${x['src'] ?? ''}',
      tel: '${x['tel'] ?? ''}',
      desc: '${x['info'] ?? ''}',
    ));
  }
  _auto[areaId] = out;
  return out;
}

Ev _fromDoc(String id, Map<String, dynamic> d) {
  DateTime t(dynamic v) => DateTime.tryParse('$v') ?? DateTime.now();
  return Ev(
    id: id,
    title: '${d['t'] ?? ''}',
    start: t(d['s']),
    end: t(d['e']),
    time: '${d['time'] ?? ''}',
    place: '${d['place'] ?? ''}',
    pos: LatLng((d['y'] as num?)?.toDouble() ?? 0, (d['x'] as num?)?.toDouble() ?? 0),
    kind: '동네 소식',
    desc: '${d['desc'] ?? ''}',
    fee: '${d['fee'] ?? ''}',
    thumbs: [for (final x in (d['th'] as List? ?? const [])) '$x'],
    photos: [for (final x in (d['ph'] as List? ?? const [])) '$x'],
    st: '${d['st'] ?? 'new'}',
    uid: '${d['uid'] ?? ''}',
    name: '${d['name'] ?? ''}',
    scope: '${d['scope'] ?? 'near'}',
    cid: '${d['cid'] ?? ''}',
    src: '이웃 제보',
  );
}

/// 승인된 동네 소식 (이 단지 것 + 근처 30km)
Future<List<Ev>> localEvents(Complex c) async {
  if (!await fbReady()) return const [];
  try {
    final q = await db.collection('dn_events').where('st', isEqualTo: 'ok').limit(200).get();
    final today = DateTime.now();
    return [
      for (final d in q.docs)
        if (_fromDoc(d.id, d.data()) case final e)
          if (!e.end.isBefore(DateTime(today.year, today.month, today.day)) &&
              ((e.scope == 'apt' && e.cid == c.id) || (e.scope == 'near' && meters(c.pos, e.pos) <= 30000)))
            e,
    ];
  } catch (_) {
    return const [];
  }
}

/// 내가 올린 것 (승인 전 포함)
Future<List<Ev>> myPosts() async {
  final u = me;
  if (u == null || !await fbReady()) return const [];
  try {
    final q = await db.collection('dn_events').where('uid', isEqualTo: u.uid).limit(30).get();
    return [for (final d in q.docs) _fromDoc(d.id, d.data())];
  } catch (_) {
    return const [];
  }
}

/// 관리자: 승인 기다리는 것
Future<List<Ev>> pendingPosts() async {
  if (!isAdmin || !await fbReady()) return const [];
  try {
    final q = await db.collection('dn_events').where('st', isEqualTo: 'new').limit(50).get();
    return [for (final d in q.docs) _fromDoc(d.id, d.data())];
  } catch (_) {
    return const [];
  }
}

Future<bool> setPostState(String id, String st) async {
  try {
    await db.collection('dn_events').doc(id).update({'st': st});
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> deletePost(String id) async {
  try {
    await db.collection('dn_events').doc(id).delete();
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> sendPost({
  required Complex c,
  required String title,
  required DateTime start,
  required DateTime end,
  required String time,
  required String place,
  required LatLng pos,
  required String desc,
  required String fee,
  required String scope,
  required List<Uint8List> photos,
  required List<Uint8List> thumbs,
}) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  if (!await fbReady()) return '서버에 연결하지 못했어요';
  String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  try {
    await db.collection('dn_events').add({
      't': title,
      's': ymd(start),
      'e': ymd(end),
      'time': time,
      'place': place,
      'y': pos.latitude,
      'x': pos.longitude,
      'desc': desc,
      'fee': fee,
      'kind': 'local',
      'scope': scope,
      'cid': c.id,
      'area': c.areaId,
      'uid': u.uid,
      'name': myName,
      'st': 'new',
      'at': fs.FieldValue.serverTimestamp(),
      'ph': [for (final p in photos) base64Encode(p)],
      'th': [for (final p in thumbs) base64Encode(p)],
    });
    return null;
  } catch (e) {
    return '올리지 못했어요 (${'$e'.length > 60 ? '$e'.substring(0, 60) : e})';
  }
}

/// 거르기
enum EvWhen { week, weekend, month }

(DateTime, DateTime) whenRange(EvWhen w, DateTime now) {
  final t = DateTime(now.year, now.month, now.day);
  switch (w) {
    case EvWhen.week:
      return (t, t.add(Duration(days: 7 - t.weekday)));
    case EvWhen.weekend:
      final sat = t.weekday >= 6 ? t : t.add(Duration(days: 6 - t.weekday));
      final from = t.weekday == 7 ? t : sat;
      return (from, t.weekday == 7 ? t : sat.add(const Duration(days: 1)));
    case EvWhen.month:
      return (t, DateTime(t.year, t.month + 1, 0));
  }
}
