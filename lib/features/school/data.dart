// 학교 급식·학사일정 자료 (학교 담당: 본부, 대표님 요청 11-24)
// web/data/school/sc_<동네>.json — collector/features/school.py 가 모음 (나이스 공개 자료: 학교가 미리 올린 식단·일정)
// 「우리 아이 학교」는 이 휴대폰에만 저장 (prefs: school.mine)
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

class Meal {
  final List<String> dishes;
  final String cal;
  const Meal(this.dishes, this.cal);
}

class School {
  final String name, kind, code; // kind: 초·중·고
  final LatLng pos;
  final Map<String, Meal> meals; // YYYYMMDD
  final List<(String, String)> events; // (YYYYMMDD, 행사)
  const School({required this.name, required this.kind, required this.code, required this.pos, required this.meals, required this.events});

  String get id => code.isEmpty ? name : code;
  bool get hasData => meals.isNotEmpty || events.isNotEmpty;

  /// 오늘(또는 다음 급식일) 급식
  (DateTime, Meal)? mealOn(DateTime from, {int look = 7}) {
    for (var i = 0; i <= look; i++) {
      final d = DateTime(from.year, from.month, from.day + i);
      final m = meals[ymd(d)];
      if (m != null) return (d, m);
    }
    return null;
  }

  /// 앞으로 n일 안의 쉬는 날·주요 행사
  List<(DateTime, String)> eventsWithin(DateTime from, int days) {
    final out = <(DateTime, String)>[];
    final end = DateTime(from.year, from.month, from.day + days);
    final start = DateTime(from.year, from.month, from.day);
    for (final (d, n) in events) {
      final t = DateTime.tryParse(d);
      if (t == null || t.isBefore(start) || t.isAfter(end)) continue;
      out.add((t, n));
    }
    return out;
  }
}

String ymd(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
bool isOff(String ev) => RegExp('휴업|방학|휴교|개교기념|재량').hasMatch(ev);

final Map<String, List<School>> _cache = {};

Future<List<School>> schoolsOf(String areaId) async {
  if (areaId.isEmpty) return const [];
  final have = _cache[areaId];
  if (have != null) return have;
  final j = await getJson('${dataBase}school/sc_$areaId.json');
  final out = <School>[];
  for (final x in (j is Map ? (j['sc'] as List? ?? const []) : const [])) {
    if (x is! Map) continue;
    final lat = (x['y'] as num?)?.toDouble(), lng = (x['x'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    final meals = <String, Meal>{};
    final m = x['meal'];
    if (m is Map) {
      m.forEach((k, v) {
        if (v is Map) meals['$k'] = Meal([for (final d in (v['m'] as List? ?? const [])) '$d'], '${v['cal'] ?? ''}');
      });
    }
    final ev = <(String, String)>[for (final e in (x['ev'] as List? ?? const [])) if (e is List && e.length > 1) ('${e[0]}', '${e[1]}')];
    out.add(School(name: '${x['n'] ?? ''}', kind: '${x['k'] ?? ''}', code: '${x['c'] ?? ''}', pos: LatLng(lat, lng), meals: meals, events: ev));
  }
  _cache[areaId] = out;
  return out;
}

Future<List<School>> nearSchools(Complex c, {double km = 3}) async {
  final all = await schoolsOf(c.areaId);
  return all.where((s) => meters(c.pos, s.pos) <= km * 1000).toList()..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
}

// 우리 아이 학교 (여러 곳 가능)
final mySchools = ValueNotifier<List<String>>(const []);
bool _loaded = false;

Future<List<String>> loadMySchools() async {
  if (_loaded) return mySchools.value;
  _loaded = true;
  try {
    final s = await prefGet('school.mine');
    if (s != null && s.isNotEmpty) mySchools.value = List<String>.from(jsonDecode(s));
  } catch (_) {}
  return mySchools.value;
}

Future<void> setMySchools(List<String> ids) async {
  mySchools.value = List.unmodifiable(ids);
  await prefSet('school.mine', jsonEncode(ids));
}

Future<List<School>> mySchoolList(Complex c) async {
  final ids = await loadMySchools();
  if (ids.isEmpty) return const [];
  final all = await schoolsOf(c.areaId);
  return [for (final id in ids) ...all.where((s) => s.id == id)];
}

// 급식 알림 (학교마다): 켜면 아침 「지금 우리 단지」 카드에 오늘 급식을 맨 위로 (11-25)
Future<bool> mealAlarmOn(String id) async => (await prefGet('school.alarm.$id')) == '1';
Future<void> setMealAlarm(String id, bool on) => prefSet('school.alarm.$id', on ? '1' : '');
