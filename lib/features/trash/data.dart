// 쓰레기·분리수거 자료 (이 폴더는 쓰레기·분리수거 방만 고침)
// ─ 지자체 배출 정보: collector/features/trash.py 가 모아 둔 web/data/trash/g_<지자체코드>.json
// ─ 단지 → 관리구역 짝: web/data/trash/apt_<동네>.json (모으기 때 카카오로 행정동을 알아내 미리 짝지음)
// ─ 우리 단지 요일(주민·관리사무소 입력): 파이어베이스 dn_trash_days/<단지 id>
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';

import '../../core/data.dart';
import '../../core/fb.dart';

// 종류: g 일반(종량제) · f 음식물 · r 재활용 · b 대형(일시적 다량)
const kKinds = ['g', 'f', 'r'];
const kKindName = {'g': '일반쓰레기', 'f': '음식물', 'r': '재활용', 'b': '대형폐기물'};
const kKindShort = {'g': '일반', 'f': '음식물', 'r': '재활용', 'b': '대형'};
const kDays = '일월화수목금토';

String dayChar(DateTime d) => kDays[d.weekday % 7];

class Zone {
  final String id, name, target, placeType, place, bulkPlace, off, dept, tel, date;
  final Map<String, String> method, days;
  final Map<String, List<String>> hours;
  Zone.fromJson(Map j)
      : id = '${j['id'] ?? ''}',
        name = '${j['n'] ?? ''}',
        target = '${j['t'] ?? ''}',
        placeType = '${j['pt'] ?? ''}',
        place = '${j['pl'] ?? ''}',
        bulkPlace = '${j['bp'] ?? ''}',
        off = '${j['off'] ?? ''}',
        dept = '${j['dept'] ?? ''}',
        tel = '${j['tel'] ?? ''}',
        date = '${j['date'] ?? ''}',
        method = {for (final e in ((j['m'] as Map?) ?? const {}).entries) '${e.key}': '${e.value ?? ''}'},
        days = {for (final e in ((j['d'] as Map?) ?? const {}).entries) '${e.key}': '${e.value ?? ''}'},
        hours = {
          for (final e in ((j['h'] as Map?) ?? const {}).entries)
            '${e.key}': [for (final x in (e.value as List? ?? const [])) '$x']
        };

  // 화면에 보일 구역 이름: 「송도 1~5, 7공구」, 이름이 없으면 대상 지역
  String get label {
    final n = name.isNotEmpty ? name : target;
    if (target.isNotEmpty && target != n && target.length <= 40) return target;
    return n;
  }
}

class Gov {
  final String code, sido, gu, updated;
  final List<Zone> zones;
  Gov.fromJson(Map j)
      : code = '${j['code']}',
        sido = '${j['sido'] ?? ''}',
        gu = '${j['gu'] ?? ''}',
        updated = '${j['updated'] ?? ''}',
        zones = [for (final z in (j['zones'] as List? ?? const [])) if (z is Map) Zone.fromJson(z)];
}

// 주민·관리사무소가 넣은 우리 단지 요일
class AptDays {
  final Map<String, String> days; // g·f·r → '월수금'
  final String start, end, note, by;
  final DateTime? at;
  AptDays({required this.days, this.start = '', this.end = '', this.note = '', this.by = '', this.at});
  bool get any => days.values.any((v) => v.isNotEmpty);
}

class TrashInfo {
  final Gov? gov;
  final Zone? zone; // 고른(또는 짝지어진) 관리구역
  final List<String> picks; // 짝지을 때 후보 관리번호
  final String dong; // 단지 행정동 (알면)
  final AptDays? apt;
  TrashInfo({this.gov, this.zone, this.picks = const [], this.dong = '', this.apt});

  bool get needPick => zone == null && (gov?.zones.length ?? 0) > 1;
  bool get empty => zone == null && !(apt?.any ?? false);

  // 종류별 배출 요일 (주민 입력이 있으면 그걸 먼저)
  String daysOf(String k) {
    final a = apt;
    if (a != null && a.any) return a.days[k] ?? '';
    return zone?.days[k] ?? '';
  }

  List<String> hoursOf(String k) {
    final a = apt;
    if (a != null && a.any && a.start.isNotEmpty) return [a.start, a.end];
    return zone?.hours[k] ?? const [];
  }

  bool get fromApt => apt?.any ?? false;

  // 그날 내는 것
  List<String> kindsOn(DateTime d) => [for (final k in kKinds) if (daysOf(k).contains(dayChar(d))) k];

  // 다음에 무언가 내는 날 (오늘 다음부터 7일 안)
  DateTime? nextDay(DateTime from) {
    for (var i = 1; i <= 7; i++) {
      final d = from.add(Duration(days: i));
      if (kindsOn(d).isNotEmpty) return d;
    }
    return null;
  }
}

// ---------------- 시간 글 ----------------
String timeWord(String hm, {bool end = false}) {
  final p = hm.split(':');
  if (p.length < 2) return '';
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  if ((h == 0 && m == 0) || (h == 23 && m >= 59) || h == 24) return end ? '밤 12시' : '자정';
  final w = h < 6
      ? '새벽'
      : h < 12
          ? '아침'
          : h < 13
              ? '낮'
              : h < 18
                  ? '오후'
                  : h < 21
                      ? '저녁'
                      : '밤';
  final hh = h > 12 ? h - 12 : h;
  return m == 0 ? '$w $hh시' : '$w $hh시 $m분';
}

String rangeText(List<String> h) {
  if (h.length < 2 || h[0].isEmpty) return '';
  final s = timeWord(h[0]);
  final e = h[1].isEmpty ? '' : timeWord(h[1], end: true);
  return e.isEmpty ? '$s부터' : '$s ~ $e';
}

String daysText(String ds) {
  if (ds.isEmpty) return '-';
  if (ds.length == 7) return '매일';
  if (ds == '월화수목금') return '평일';
  return ds.split('').join('·');
}

// ---------------- 불러오기 ----------------
final Map<String, dynamic> _cache = {};

Future<dynamic> _get(String path) async {
  if (_cache.containsKey(path)) return _cache[path];
  final j = await getJson('${dataBase}trash/$path');
  if (j != null) _cache[path] = j;
  return j;
}

// 단지에 맞는 지자체 코드·후보 구역
Future<(String?, List<String>, String)> _codeOf(Complex c) async {
  final m = await _get('apt_${c.areaId}.json');
  final Map? apts = m is Map ? m['apts'] as Map? : null;
  final e = apts == null ? null : apts[c.id];
  if (e is Map && e['c'] != null) {
    return ('${e['c']}', [for (final z in (e['z'] as List? ?? const [])) '$z'], '${e['h'] ?? ''}');
  }
  // 직접 넣은 단지 등: 주소의 「인천 연수구」로 찾기
  final idx = await _get('index.json');
  final w = c.addr.trim().split(RegExp(r'\s+'));
  if (idx is Map && w.length >= 2) {
    final sido = w[0].length >= 2 ? w[0].substring(0, 2) : w[0];
    for (final g in (idx['gu'] as List? ?? const [])) {
      if (g is List && g.length >= 3 && '${g[1]}'.startsWith(sido) && ('${g[2]}' == w[1] || (w.length > 2 && '${g[2]}' == '${w[1]} ${w[2]}'))) {
        return ('${g[0]}', <String>[], '');
      }
    }
  }
  // 동네의 구 (인천은 2026년 7월 구 개편: 중구·동구 → 영종구·제물포구, 서구 → 서해구·검단구)
  final a = c.area;
  if (idx is Map && a != null) {
    const renamed = {'yeongjong': '영종구', 'sinpo': '제물포구', 'seogu': '서해구'};
    final names = [if (renamed[a.id] != null) renamed[a.id]!, a.gu];
    for (final n in names) {
      for (final g in (idx['gu'] as List? ?? const [])) {
        if (g is List && g.length >= 3 && '${g[1]}'.startsWith(a.sido.length >= 2 ? a.sido.substring(0, 2) : a.sido) && '${g[2]}' == n) {
          return ('${g[0]}', <String>[], '');
        }
      }
    }
  }
  return (null, <String>[], '');
}

Future<Gov?> govOf(String code) async {
  final j = await _get('g_$code.json');
  return j is Map ? Gov.fromJson(j) : null;
}

Future<AptDays?> aptDaysOf(Complex c) async {
  if (!await fbReady()) return null;
  try {
    final d = await db.collection('dn_trash_days').doc(c.id).get();
    final j = d.data();
    if (j == null) return null;
    return AptDays(
      days: {for (final k in kKinds) k: '${j[k] ?? ''}'},
      start: '${j['s'] ?? ''}',
      end: '${j['e'] ?? ''}',
      note: '${j['note'] ?? ''}',
      by: '${j['name'] ?? ''}',
      at: (j['at'] as dynamic)?.toDate(),
    );
  } catch (_) {
    return null;
  }
}

Future<bool> saveAptDays(Complex c, AptDays a) async {
  if (!await fbReady() || me == null) return false;
  try {
    await db.collection('dn_trash_days').doc(c.id).set({
      for (final k in kKinds) k: a.days[k] ?? '',
      's': a.start,
      'e': a.end,
      'note': a.note,
      'apt': c.name,
      'uid': me!.uid,
      'name': myName,
      'at': fs.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    debugPrint('쓰레기 요일 저장 실패: $e');
    return false;
  }
}

String _pickKey(Complex c) => 'trash.zone.${c.id}';

Future<void> pickZone(Complex c, Zone z) async {
  await prefSet(_pickKey(c), z.id);
  _infos.remove(c.id);
}

final Map<String, TrashInfo> _infos = {};
final trashTick = ValueNotifier<int>(0);

void forgetTrash(Complex c) {
  _infos.remove(c.id);
  trashTick.value++;
}

Future<TrashInfo> trashOf(Complex c) async {
  final have = _infos[c.id];
  if (have != null) return have;
  final (code, picks, dong) = await _codeOf(c);
  final gov = code == null ? null : await govOf(code);
  Zone? zone;
  if (gov != null) {
    final mine = await prefGet(_pickKey(c));
    zone = gov.zones.where((z) => z.id == mine).firstOrNull;
    if (zone == null && picks.length == 1) zone = gov.zones.where((z) => z.id == picks.first).firstOrNull;
    if (zone == null && gov.zones.length == 1) zone = gov.zones.first;
  }
  final apt = await aptDaysOf(c);
  final info = TrashInfo(gov: gov, zone: zone, picks: picks, dong: dong, apt: apt);
  _infos[c.id] = info;
  return info;
}
