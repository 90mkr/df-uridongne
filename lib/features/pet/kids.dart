// 우리 아이 수첩 — 자료와 알림 (반려동물 테마 방)
// 휴대폰 기억 칸 'pet.kids' 에 저장 → 본부 공통 백업(로그인 회원)이 함께 옮겨 준다 (requests/backup-1125)
// 챙길 것마다 「마지막으로 한 날 + 주기」 → 다음 날짜 계산 → 사흘 전·당일 아침 9시 알림
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/data.dart';
import '../../core/notify.dart';

class CareKind {
  final String id, name, desc;
  final int days; // 기본 주기 (일)
  final bool dogOnly, catOnly;
  const CareKind(this.id, this.name, this.desc, this.days, {this.dogOnly = false, this.catOnly = false});
}

// 수의사 권장 일반 주기 (병원마다 다를 수 있어 고칠 수 있게)
const kCares = [
  CareKind('heart', '심장사상충 예방', '매달 한 번', 30),
  CareKind('flea', '외부 구충', '진드기·벼룩, 매달', 30),
  CareKind('worm', '내부 구충', '석 달에 한 번', 90),
  CareKind('vacc', '종합 백신', '해마다 추가 접종', 365),
  CareKind('rabies', '광견병 접종', '해마다', 365, dogOnly: true),
  CareKind('check', '건강검진', '해마다 (노령은 반년)', 365),
  CareKind('scale', '스케일링', '해마다', 365),
  CareKind('groom', '미용', '두 달쯤', 60),
];

CareKind careById(String id) => kCares.firstWhere((c) => c.id == id, orElse: () => kCares.first);

class Care {
  String id;
  DateTime last;
  int days;
  Care(this.id, this.last, this.days);
  DateTime get next => last.add(Duration(days: days));
  Map toJson() => {'id': id, 'l': last.toIso8601String().substring(0, 10), 'd': days};
  static Care? fromJson(dynamic j) {
    if (j is! Map) return null;
    final l = DateTime.tryParse('${j['l']}');
    if (l == null) return null;
    return Care('${j['id']}', l, (j['d'] as num?)?.toInt() ?? careById('${j['id']}').days);
  }
}

class Kid {
  int id;
  String name, kind, breed; // kind: 강아지·고양이·그 밖
  DateTime? birth;
  double weight;
  String hosp; // 다니는 병원 이름
  String hospTel;
  List<Care> cares;
  Kid({required this.id, required this.name, this.kind = '강아지', this.breed = '', this.birth, this.weight = 0, this.hosp = '', this.hospTel = '', List<Care>? cares})
      : cares = cares ?? [];

  String get ageText {
    final b = birth;
    if (b == null) return '';
    final now = DateTime.now();
    var m = (now.year - b.year) * 12 + now.month - b.month;
    if (now.day < b.day) m--;
    if (m < 0) return '';
    if (m < 12) return '$m개월';
    return '${m ~/ 12}살${m % 12 > 0 ? ' ${m % 12}개월' : ''}';
  }

  Map toJson() => {
        'id': id,
        'n': name,
        'k': kind,
        'b': breed,
        if (birth != null) 'bd': birth!.toIso8601String().substring(0, 10),
        'w': weight,
        'h': hosp,
        'ht': hospTel,
        'c': [for (final c in cares) c.toJson()],
      };

  static Kid? fromJson(dynamic j) {
    if (j is! Map) return null;
    return Kid(
      id: (j['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      name: '${j['n'] ?? ''}',
      kind: '${j['k'] ?? '강아지'}',
      breed: '${j['b'] ?? ''}',
      birth: DateTime.tryParse('${j['bd'] ?? ''}'),
      weight: (j['w'] as num?)?.toDouble() ?? 0,
      hosp: '${j['h'] ?? ''}',
      hospTel: '${j['ht'] ?? ''}',
      cares: [for (final c in (j['c'] as List? ?? const [])) Care.fromJson(c)].whereType<Care>().toList(),
    );
  }
}

final kids = ValueNotifier<List<Kid>>(const []);
bool _loaded = false;

Future<void> loadKids() async {
  if (_loaded) return;
  _loaded = true;
  try {
    final s = await prefGet('pet.kids');
    if (s != null && s.isNotEmpty) {
      kids.value = [for (final k in (jsonDecode(s) as List)) Kid.fromJson(k)].whereType<Kid>().toList();
    }
  } catch (_) {}
}

Future<void> saveKids(List<Kid> list) async {
  kids.value = List.of(list);
  await prefSet('pet.kids', jsonEncode([for (final k in list) k.toJson()]));
  await rescheduleKids();
}

int dayDiff(DateTime d, DateTime now) => DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;

// 다가오는 챙길 것 (가까운 순)
List<(Kid, Care)> dueList(DateTime now) {
  final out = <(Kid, Care)>[
    for (final k in kids.value)
      for (final c in k.cares) (k, c)
  ];
  out.sort((a, b) => a.$2.next.compareTo(b.$2.next));
  return out;
}

// 알림 번호: 700000 + 아이·항목별 (사흘 전 0, 당일 1)
int _noteId(Kid k, Care c, int i) => 700000 + (k.id % 1000) * 40 + kCares.indexWhere((x) => x.id == c.id).clamp(0, 19) * 2 + i;

Future<void> rescheduleKids() async {
  if (!canNotify) return;
  final now = DateTime.now();
  for (final k in kids.value) {
    for (final c in k.cares) {
      for (var i = 0; i < 2; i++) {
        await cancelNote(_noteId(k, c, i));
      }
      final n = c.next;
      final name = careById(c.id).name;
      final before = DateTime(n.year, n.month, n.day, 9).subtract(const Duration(days: 3));
      final day = DateTime(n.year, n.month, n.day, 9);
      if (before.isAfter(now)) await scheduleNote(_noteId(k, c, 0), before, '사흘 뒤 ${k.name} $name', '${n.month}월 ${n.day}일 · 우리 아이 수첩');
      if (day.isAfter(now)) await scheduleNote(_noteId(k, c, 1), day, '오늘은 ${k.name} $name 날', '했다면 수첩에서 「오늘 했어요」를 눌러 주세요');
    }
  }
}
