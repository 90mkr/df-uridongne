// 기념일 자료 (기념일 담당: 본부, 대표님 요청 11-24) — 이 휴대폰에만 저장 (prefs: anniv.list)
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:klc/klc.dart' as klc;

import '../../core/data.dart';
import '../../core/notify.dart';

class Anniv {
  final int id;
  final String title, kind; // kind: 생일 · 기념일 · 제사 · 기타
  final int month, day;
  final bool lunar;
  final int? year; // 처음 해 (몇 번째인지 셀 때, 없어도 됨)
  final List<int> remind; // 며칠 전에 알릴지: 0 당일 · 1 하루 전 · 7 일주일 전
  const Anniv({required this.id, required this.title, required this.kind, required this.month, required this.day, required this.lunar, this.year, this.remind = const [0, 1]});

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'k': kind, 'm': month, 'd': day, 'l': lunar, if (year != null) 'y': year, 'r': remind};
  static Anniv fromJson(Map j) => Anniv(
        id: (j['id'] as num).toInt(),
        title: '${j['t'] ?? ''}',
        kind: '${j['k'] ?? '기념일'}',
        month: (j['m'] as num).toInt(),
        day: (j['d'] as num).toInt(),
        lunar: j['l'] == true,
        year: (j['y'] as num?)?.toInt(),
        remind: [for (final x in (j['r'] as List? ?? const [0, 1])) (x as num).toInt()],
      );

  String get dateText => '${lunar ? '음력' : '양력'} $month월 $day일';

  /// 오늘 이후(오늘 포함) 다가오는 날 (양력)
  DateTime? next(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (final y in [now.year, now.year + 1, now.year + 2]) {
      final d = solarOf(y);
      if (d != null && !d.isBefore(today)) return d;
    }
    return null;
  }

  /// 그해의 양력 날짜 (음력이면 바꿔서). 없는 날(2월 30일 등)은 null
  DateTime? solarOf(int y) {
    if (!lunar) {
      final d = DateTime(y, month, day);
      return d.month == month ? d : DateTime(y, month + 1, 0); // 2월 29일 → 평년엔 2월 28일
    }
    return lunarToSolar(y, month, day);
  }

  int? nth(DateTime when) => year == null ? null : when.year - year!;
}

/// 음력 → 양력 (klc: 1391~2050년)
DateTime? lunarToSolar(int y, int m, int d) {
  try {
    klc.setLunarDate(y, m, d, false);
    final r = DateTime.tryParse(klc.getSolarIsoFormat()); // 2026-02-12
    if (r == null) return null;
    // 거꾸로 바꿔서 같은 음력 날이 나오는지 확인 (작은달 30일 같은 없는 날 걸러냄)
    klc.setSolarDate(r.year, r.month, r.day);
    final back = klc.getLunarIsoFormat();
    final want = '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    if (!back.startsWith(want)) return d == 30 ? lunarToSolar(y, m, 29) : null;
    return r;
  } catch (_) {
    return d == 30 ? lunarToSolar(y, m, 29) : null;
  }
}

int dday(DateTime when, DateTime now) => DateTime(when.year, when.month, when.day).difference(DateTime(now.year, now.month, now.day)).inDays;
String ddayText(int n) => n == 0 ? 'D-DAY' : 'D-$n';

final annivs = ValueNotifier<List<Anniv>>(const []);
bool _loaded = false;

Future<List<Anniv>> loadAnnivs() async {
  if (_loaded) return annivs.value;
  _loaded = true;
  try {
    final s = await prefGet('anniv.list');
    if (s != null && s.isNotEmpty) annivs.value = [for (final j in jsonDecode(s) as List) Anniv.fromJson(j as Map)];
  } catch (_) {}
  await rescheduleAnnivs();
  return annivs.value;
}

Future<void> saveAnnivs(List<Anniv> l) async {
  annivs.value = List.unmodifiable(l);
  await prefSet('anniv.list', jsonEncode([for (final a in l) a.toJson()]));
  await rescheduleAnnivs();
}

/// 다가오는 순
List<(Anniv, DateTime)> upcoming(DateTime now) {
  final out = <(Anniv, DateTime)>[];
  for (final a in annivs.value) {
    final d = a.next(now);
    if (d != null) out.add((a, d));
  }
  out.sort((x, y) => x.$2.compareTo(y.$2));
  return out;
}

// 알림: 기념일마다 다가오는 날 기준 「당일·하루 전·일주일 전」 아침 9시. 앱을 열 때마다 다시 맞춘다 (해가 바뀌어도 이어지게)
const _remindIdx = [0, 1, 3, 7];
Future<void> rescheduleAnnivs() async {
  if (!canNotify) return;
  final now = DateTime.now();
  for (final a in annivs.value) {
    for (var i = 0; i < _remindIdx.length; i++) {
      await cancelNote(500000 + a.id % 100000 * 10 + i);
    }
    final d = a.next(now);
    if (d == null) continue;
    for (final before in a.remind) {
      final i = _remindIdx.indexOf(before);
      if (i < 0) continue;
      final when = DateTime(d.year, d.month, d.day, 9).subtract(Duration(days: before));
      final n = a.nth(d);
      final what = '${a.title}${n != null && n > 0 ? ' ($n${a.kind == '생일' ? '번째 생일' : '주년'})' : ''}';
      await scheduleNote(
        500000 + a.id % 100000 * 10 + i,
        when,
        before == 0 ? '오늘은 $what' : '$before일 뒤 $what',
        '${d.month}월 ${d.day}일 · ${a.dateText}',
      );
    }
  }
}
