// 지금 문 연 약국 — 자료와 「지금 열었는지」 계산 (이 폴더는 약국 담당 방만 고침)
//
// 자료는 collector/features/pharmacy.py 가 매주 모아 web/data/pharmacy/ 에 둔다.
//   t_<위도×10>_<경도×10>.json  0.1도 칸마다 약국(p)·소아과(h)
//   er.json                      전국 응급실(e)
//   meta.json                    갱신 시각·공휴일
// 운영시간 h 는 8칸(월~일, 공휴일) "0900-2200" 또는 "" (쉼). 닫는 시각이 여는 시각 이하이면 다음 날 새벽까지.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

class Place {
  final String id, kind, name, addr, tel, tel2, div;
  final LatLng pos;
  final List<String> hours; // 8칸
  const Place({required this.id, required this.kind, required this.name, required this.addr, required this.tel, this.tel2 = '', this.div = '', required this.pos, required this.hours});

  bool get isPharm => kind == 'p';
  bool get isKids => kind == 'h';
  bool get isEr => kind == 'e';

  static Place? from(dynamic j) {
    if (j is! Map || j['y'] == null || j['x'] == null) return null;
    final h = j['h'];
    return Place(
      id: '${j['id'] ?? ''}',
      kind: '${j['k'] ?? 'p'}',
      name: '${j['n'] ?? ''}',
      addr: '${j['a'] ?? ''}',
      tel: '${j['t'] ?? ''}',
      tel2: '${j['t2'] ?? ''}',
      div: '${j['d'] ?? ''}',
      pos: LatLng((j['y'] as num).toDouble(), (j['x'] as num).toDouble()),
      hours: h is List && h.length == 8 ? [for (final x in h) '$x'] : List.filled(8, ''),
    );
  }

  // ---- 운영시간 ----
  // 하루 칸 → (여는 분, 닫는 분). 닫는 분은 다음 날로 넘어가면 1440을 넘는다.
  (int, int)? span(int idx) {
    final s = hours[idx];
    if (s.length != 9) return null;
    final o = _min(s.substring(0, 4)), c0 = _min(s.substring(5));
    if (o == null || c0 == null) return null;
    final c = c0 <= o ? c0 + 1440 : c0;
    return (o, c);
  }

  bool get hasSunday => hours[6].isNotEmpty;
  bool get hasHoliday => hours[7].isNotEmpty;

  // 어느 요일이든 밤 10시를 넘겨 여는 곳
  bool get lateAny => [for (var i = 0; i < 8; i++) span(i)].any((s) => s != null && s.$2 > 22 * 60);

  OpenState stateAt(DateTime now) => OpenState.of(this, now);
  OpenState stateBy(When w) => OpenState.by(this, w);
}

int? _min(String hhmm) {
  final h = int.tryParse(hhmm.substring(0, 2)), m = int.tryParse(hhmm.substring(2));
  if (h == null || m == null) return null;
  return h * 60 + m;
}

// ---- 공휴일 ----
Set<String> _holidays = {
  // 자료가 아직 없을 때 쓰는 기본 목록 (2026~2027, 대체공휴일 포함)
  '2026-01-01', '2026-02-16', '2026-02-17', '2026-02-18', '2026-03-01', '2026-03-02', '2026-05-05', '2026-05-24', '2026-05-25',
  '2026-06-03', '2026-06-06', '2026-08-15', '2026-08-17', '2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05',
  '2026-10-09', '2026-12-25', '2027-01-01', '2027-02-06', '2027-02-07', '2027-02-08', '2027-02-09', '2027-03-01', '2027-05-05',
  '2027-05-13', '2027-06-06', '2027-08-15', '2027-08-16', '2027-09-14', '2027-09-15', '2027-09-16', '2027-10-03', '2027-10-04',
  '2027-10-09', '2027-10-11', '2027-12-25', '2027-12-27',
};

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
bool isHoliday(DateTime d) => _holidays.contains(_ymd(d));

// 그 날짜에 쓸 운영시간 칸 (0=월 … 6=일, 7=공휴일)
int dayIdx(DateTime d) => isHoliday(d) ? 7 : d.weekday - 1;

const kDayNames = ['월', '화', '수', '목', '금', '토', '일', '공휴일'];

// 언제 기준으로 볼지: 지금(live) 또는 대표님이 고른 요일·시각
class When {
  final int idx; // 0=월 … 6=일, 7=공휴일
  final int prevIdx; // 전날 칸 (모르면 -1)
  final int min; // 0시 기준 분
  final DateTime? date; // 지금이면 실제 시각
  const When(this.idx, this.prevIdx, this.min, [this.date]);
  bool get live => date != null;

  factory When.now() {
    final n = DateTime.now();
    return When(dayIdx(n), dayIdx(n.subtract(const Duration(days: 1))), n.hour * 60 + n.minute, n);
  }
  factory When.pick(int idx, int min) => When(idx, idx == 7 ? -1 : (idx + 6) % 7, min);

  String get label => live ? '지금 ${_two(min ~/ 60)}:${_two(min % 60)}' : '${idx == 7 ? '공휴일' : '${kDayNames[idx]}요일'} ${clockText(min)}';
}

String _two(int v) => v.toString().padLeft(2, '0');

class OpenState {
  final bool open;
  final int closeMin; // 그날 0시 기준 닫는 분 (다음 날 새벽이면 1440 넘음)
  final int minsLeft; // 닫을 때까지 남은 분
  final String next; // 닫혀 있을 때: 다음에 여는 때 (예: 「내일 오전 9시」)
  final bool todayNone; // 그날 운영 정보 없음 (쉬는 날)
  const OpenState({required this.open, this.closeMin = 0, this.minsLeft = 0, this.next = '', this.todayNone = false});

  bool get closingSoon => open && minsLeft <= 30; // 30분 안에 닫음 → 「곧 마감」

  String get untilText => '${clockText(closeMin)}까지';

  // 요일 칸·시각만으로 (고른 시각 미리 보기에 씀)
  static OpenState at(Place p, int idx, int prevIdx, int nowMin) {
    final y = prevIdx < 0 ? null : p.span(prevIdx);
    if (y != null && y.$2 > 1440 && nowMin < y.$2 - 1440) {
      final c = y.$2 - 1440;
      return OpenState(open: true, closeMin: c, minsLeft: c - nowMin);
    }
    final t = p.span(idx);
    if (t != null && nowMin >= t.$1 && nowMin < t.$2) {
      return OpenState(open: true, closeMin: t.$2, minsLeft: t.$2 - nowMin);
    }
    if (t != null && nowMin < t.$1) return OpenState(open: false, next: clockText(t.$1));
    return OpenState(open: false, todayNone: t == null);
  }

  static OpenState of(Place p, DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    final s = at(p, dayIdx(now), dayIdx(now.subtract(const Duration(days: 1))), nowMin);
    if (s.open) return s;
    final t = p.span(dayIdx(now));
    if (t != null && nowMin < t.$1) return OpenState(open: false, next: '오늘 ${clockText(t.$1)}');
    for (var i = 1; i <= 7; i++) {
      final d = now.add(Duration(days: i));
      final sp = p.span(dayIdx(d));
      if (sp != null) {
        final when = i == 1 ? '내일' : (isHoliday(d) ? '${d.month}/${d.day}' : '${kDayNames[d.weekday - 1]}요일');
        return OpenState(open: false, next: '$when ${clockText(sp.$1)}', todayNone: t == null);
      }
    }
    return OpenState(open: false, todayNone: t == null);
  }

  static OpenState by(Place p, When w) => w.live ? of(p, w.date!) : at(p, w.idx, w.prevIdx, w.min);
}

// ---- 연휴 ----
bool isOff(DateTime d) => isHoliday(d) || d.weekday >= 6;
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

// 3일 안에 시작하는(또는 이미 시작한) 공휴일 낀 연휴 날짜들. 없으면 빈 목록.
List<DateTime> holidayRun(DateTime now) {
  final today = _day(now);
  for (var i = 0; i <= 12; i++) {
    final h = today.add(Duration(days: i));
    if (!isHoliday(h)) continue;
    var start = h;
    while (start.isAfter(today) && isOff(start.subtract(const Duration(days: 1)))) {
      start = start.subtract(const Duration(days: 1));
    }
    if (start.difference(today).inDays > 3) return const [];
    final out = <DateTime>[];
    for (var d = start; isOff(d); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }
  return const [];
}

String dateText(DateTime d) => '${d.month}/${d.day}(${kDayNames[d.weekday - 1]})';

// 분 → 「밤 10시」「새벽 1시 30분」「오전 9시」
String clockText(int min) {
  var m = min % 1440;
  if (min >= 1440 && m == 0) m = 1440;
  final h = m ~/ 60, mm = m % 60;
  final tail = mm == 0 ? '' : ' $mm분';
  if (h == 24) return '밤 12시$tail';
  if (h == 0) return '밤 12시$tail';
  if (h < 6) return '새벽 $h시$tail';
  if (h < 12) return '오전 $h시$tail';
  if (h == 12) return '낮 12시$tail';
  if (h < 18) return '오후 ${h - 12}시$tail';
  if (h < 21) return '저녁 ${h - 12}시$tail';
  return '밤 ${h - 12}시$tail';
}

// "0900-2200" → "09:00 – 22:00"
String spanText(String s) {
  if (s.length != 9) return '쉼';
  return '${s.substring(0, 2)}:${s.substring(2, 4)} – ${s.substring(5, 7)}:${s.substring(7)}';
}

// ---- 자료 받기 ----
final Map<String, Future<List<Place>>> _tiles = {};
Future<List<Place>>? _er;
Future<Map?>? _meta;

String get _base => '${dataBase}pharmacy/';

Future<Map?> loadMeta() => _meta ??= () async {
      final j = await getJson('${_base}meta.json');
      if (j is Map) {
        final h = j['holidays'];
        if (h is List && h.isNotEmpty) _holidays = {..._holidays, for (final x in h) '$x'};
        return j;
      }
      _meta = null; // 다음에 다시 시도
      return null;
    }();

Future<List<Place>> _tile(String key) => _tiles[key] ??= () async {
      final j = await getJson('$_base$key.json');
      return [for (final x in (j is Map ? (j['items'] as List? ?? const []) : const [])) Place.from(x)].whereType<Place>().toList();
    }();

// 기준점 둘레 r 미터 안에 걸치는 칸을 모두 받아 거리순으로
Future<List<Place>> placesNear(LatLng c, {double r = 5000}) async {
  await loadMeta();
  final dLat = r / 111000, dLng = r / (111000 * math.cos(c.latitude * math.pi / 180));
  final keys = <String>{};
  for (var a = ((c.latitude - dLat) * 10).floor(); a <= ((c.latitude + dLat) * 10).floor(); a++) {
    for (var b = ((c.longitude - dLng) * 10).floor(); b <= ((c.longitude + dLng) * 10).floor(); b++) {
      keys.add('t_${a}_$b');
    }
  }
  final all = (await Future.wait(keys.map(_tile))).expand((x) => x);
  final d = <Place, double>{};
  for (final p in all) {
    final m = meters(c, p.pos);
    if (m <= r) d[p] = m;
  }
  return d.keys.toList()..sort((a, b) => d[a]!.compareTo(d[b]!));
}

Future<List<Place>> ersNear(LatLng c, {int n = 4}) async {
  final list = await (_er ??= () async {
    final j = await getJson('${_base}er.json');
    final l = [for (final x in (j is Map ? (j['items'] as List? ?? const []) : const [])) Place.from(x)].whereType<Place>().toList();
    if (l.isEmpty) _er = null;
    return l;
  }());
  final s = [...list]..sort((a, b) => meters(c, a.pos).compareTo(meters(c, b.pos)));
  return s.take(n).toList();
}

// 상비약 파는 편의점: 본부가 모은 동네 업체 자료(web/data/<동네>.json)에서 편의점만
class Store {
  final String name, tel;
  final LatLng pos;
  const Store(this.name, this.tel, this.pos);
  bool get allDay => name.contains('24');
}

final Map<String, Future<List<Store>>> _stores = {};

Future<List<Store>> storesNear(Complex c, {int n = 8}) async {
  final list = await (_stores[c.areaId] ??= () async {
    final j = await getJson('$dataBase${c.areaId}.json');
    final out = <Store>[];
    for (final x in (j is Map ? (j['shops'] as List? ?? const []) : const [])) {
      if (x is! Map || x['y'] == null) continue;
      final name = '${x['n'] ?? ''}', sub = '${x['s'] ?? ''}';
      if (!RegExp(r'편의점|CU|GS25|세븐일레븐|이마트24|미니스톱|씨스페이스').hasMatch('$name $sub')) continue;
      out.add(Store(name, '${x['t'] ?? ''}', LatLng((x['y'] as num).toDouble(), (x['x'] as num).toDouble())));
    }
    if (out.isEmpty) _stores.remove(c.areaId);
    return out;
  }());
  final s = [...list]..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
  return s.take(n).toList();
}
