// 복권 — 자료 받기 · 등수 계산 · QR 읽기 (이 폴더는 복권 담당 방만 고침)
// 자료는 collector/features/lotto.py 가 매주 web/data/lotto/ 에 모아 둔다. 앱은 동행복권을 직접 부르지 않는다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

// ---------------- 당첨번호 ----------------
class Draw {
  final int no;
  final String date; // yyyy-mm-dd
  final List<int> nums;
  final int bonus;
  final List<List<int>> ranks; // [[인원, 1인당], …] 1~5등
  final List<int> how; // 1등 [자동, 수동, 반자동]
  const Draw(this.no, this.date, this.nums, this.bonus, this.ranks, this.how);

  static Draw? fromJson(dynamic d) {
    try {
      final l = d as List;
      return Draw(
        (l[0] as num).toInt(),
        '${l[1]}',
        [for (final x in l[2] as List) (x as num).toInt()],
        (l[3] as num).toInt(),
        [for (final r in l[4] as List) [for (final x in r as List) (x as num).toInt()]],
        [for (final x in (l.length > 5 ? l[5] as List : const [])) (x as num).toInt()],
      );
    } catch (_) {
      return null;
    }
  }

  int winners(int rank) => rank >= 1 && rank <= ranks.length ? ranks[rank - 1][0] : 0;
  int prize(int rank) => rank >= 1 && rank <= ranks.length ? ranks[rank - 1][1] : 0;

  DateTime? get day => DateTime.tryParse(date);
  String get dayText {
    final d = day;
    return d == null ? date : '${d.year}년 ${d.month}월 ${d.day}일';
  }

  String get shortDay {
    final d = day;
    return d == null ? date : '${d.month}월 ${d.day}일';
  }
}

class Draws {
  final List<Draw> list; // 회차 오름차순
  final String updated;
  const Draws(this.list, this.updated);
  Draw? get latest => list.isEmpty ? null : list.last;
  Draw? byNo(int no) {
    if (list.isEmpty) return null;
    final i = no - list.first.no;
    if (i >= 0 && i < list.length && list[i].no == no) return list[i];
    for (final d in list) {
      if (d.no == no) return d;
    }
    return null;
  }

  // 다음 추첨 (마지막 회차 + 7일, 토요일 20:35)
  DateTime? get nextDraw {
    final d = latest?.day;
    return d == null ? null : DateTime(d.year, d.month, d.day + 7, 20, 35);
  }
}

Draws? _draws;

Future<Draws?> loadDraws({bool fresh = false}) async {
  if (_draws != null && !fresh) return _draws;
  final j = await getJson('${dataBase}lotto/draws.json', timeout: const Duration(seconds: 25));
  if (j is! Map) return _draws;
  final list = [for (final d in (j['draws'] as List? ?? const [])) Draw.fromJson(d)].whereType<Draw>().toList();
  if (list.isEmpty) return _draws;
  list.sort((a, b) => a.no.compareTo(b.no));
  return _draws = Draws(list, '${j['updated'] ?? ''}');
}

// ---------------- 판매점 ----------------
class Store {
  final String id, name, addr, tel;
  final double lat, lng;
  final int wins; // 1등 나온 횟수
  final List<int> how; // [자동, 수동, 반자동]
  final int last; // 마지막 1등 회차
  final List<int> rounds; // 최근 1등 회차들
  const Store({required this.id, required this.name, required this.addr, this.tel = '', required this.lat, required this.lng, this.wins = 0, this.how = const [], this.last = 0, this.rounds = const []});
  LatLng get pos => LatLng(lat, lng);

  String get howText {
    final parts = <String>[];
    if (how.isNotEmpty && how[0] > 0) parts.add('자동 ${how[0]}');
    if (how.length > 1 && how[1] > 0) parts.add('수동 ${how[1]}');
    if (how.length > 2 && how[2] > 0) parts.add('반자동 ${how[2]}');
    return parts.join(' · ');
  }
}

class AreaLotto {
  final List<Store> wins; // 1등 나온 집
  final List<Store> shops; // 복권 판매점 (카카오)
  final int upto;
  const AreaLotto(this.wins, this.shops, this.upto);
}

final Map<String, AreaLotto> _areas = {};

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');

Future<AreaLotto> loadArea(String areaId) async {
  final have = _areas[areaId];
  if (have != null) return have;
  final j = await getJson('${dataBase}lotto/area_$areaId.json');
  final wins = <Store>[];
  final shops = <Store>[];
  if (j is Map) {
    for (final w in (j['wins'] as List? ?? const [])) {
      if (w is! Map) continue;
      final y = _d(w['y']), x = _d(w['x']);
      if (y == null || x == null) continue;
      wins.add(Store(
        id: 'w_${w['n']}_${w['a']}',
        name: '${w['n'] ?? ''}',
        addr: '${w['a'] ?? ''}',
        tel: '${w['t'] ?? ''}',
        lat: y,
        lng: x,
        wins: _i(w['w']),
        how: [for (final c in (w['c'] as List? ?? const [])) _i(c)],
        last: _i(w['last']),
        rounds: [for (final r in (w['r'] as List? ?? const [])) _i(r)],
      ));
    }
    for (final s in (j['shops'] as List? ?? const [])) {
      if (s is! Map) continue;
      final y = _d(s['y']), x = _d(s['x']);
      if (y == null || x == null) continue;
      shops.add(Store(id: '${s['id']}', name: '${s['n'] ?? ''}', addr: '${s['a'] ?? ''}', tel: '${s['t'] ?? ''}', lat: y, lng: x, wins: _i(s['w'])));
    }
  }
  final a = AreaLotto(wins, shops, j is Map ? _i(j['upto']) : 0);
  if (j is Map) _areas[areaId] = a;
  return a;
}

// ---------------- 등수 ----------------
class Game {
  final List<int> nums; // 6개, 오름차순
  final String kind; // 자동 · 수동 · 반자동 · ''
  const Game(this.nums, [this.kind = '']);
  Map<String, dynamic> toJson() => {'n': nums, 'k': kind};
  static Game? fromJson(dynamic j) {
    try {
      final n = [for (final x in (j['n'] as List)) (x as num).toInt()]..sort();
      return n.length == 6 ? Game(n, '${j['k'] ?? ''}') : null;
    } catch (_) {
      return null;
    }
  }
}

// 0 = 낙첨, 1~5 = 등수
int rankOf(List<int> mine, Draw d) {
  final hit = mine.where(d.nums.contains).length;
  if (hit == 6) return 1;
  if (hit == 5) return mine.contains(d.bonus) ? 2 : 3;
  if (hit == 4) return 4;
  if (hit == 3) return 5;
  return 0;
}

String rankText(int r) => r == 0 ? '낙첨' : '$r등';

// ---------------- 로또 용지 QR ----------------
// 용지 QR 안의 주소: …dhlottery.co.kr/?v=1251q141819294045m010203040506…1234567890
//   v= 뒤 4자리 = 회차, 그다음 「글자 + 12자리」가 한 게임 (글자 q 자동 · m 수동 · s 반자동), 끝의 숫자는 용지 번호
class Ticket {
  final int round;
  final List<Game> games;
  const Ticket(this.round, this.games);
}

Ticket? parseTicketQr(String raw) {
  final s = raw.trim();
  final m = RegExp(r'[?&]v=([0-9a-zA-Z]+)').firstMatch(s);
  final v = (m?.group(1) ?? (RegExp(r'^\d{4}[a-zA-Z]\d{12}').hasMatch(s) ? s : '')).toLowerCase();
  if (v.length < 17) return null;
  final round = int.tryParse(v.substring(0, 4));
  if (round == null || round < 1) return null;
  final games = <Game>[];
  for (final g in RegExp(r'([a-z])(\d{12})').allMatches(v.substring(4))) {
    final d = g.group(2)!;
    final nums = [for (var i = 0; i < 12; i += 2) int.parse(d.substring(i, i + 2))];
    if (nums.any((n) => n < 1 || n > 45) || nums.toSet().length != 6) continue;
    nums.sort();
    final kind = switch (g.group(1)) { 'q' => '자동', 'm' => '수동', 's' => '반자동', _ => '' };
    games.add(Game(nums, kind));
    if (games.length == 5) break;
  }
  return games.isEmpty ? null : Ticket(round, games);
}

// ---------------- 내 번호 (휴대폰에 저장) ----------------
class MyTicket {
  final int round; // 0 = 회차 상관없이 매주 확인하는 고정 번호
  final List<Game> games;
  const MyTicket(this.round, this.games);
  Map<String, dynamic> toJson() => {'r': round, 'g': [for (final g in games) g.toJson()]};
  static MyTicket? fromJson(dynamic j) {
    try {
      final g = [for (final x in (j['g'] as List)) Game.fromJson(x)].whereType<Game>().toList();
      return g.isEmpty ? null : MyTicket((j['r'] as num).toInt(), g);
    } catch (_) {
      return null;
    }
  }
}

Future<List<MyTicket>> loadMine() async {
  try {
    final s = await prefGet('lotto.mine');
    if (s == null || s.isEmpty) return [];
    return [for (final x in jsonDecode(s) as List) MyTicket.fromJson(x)].whereType<MyTicket>().toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveMine(List<MyTicket> list) => prefSet('lotto.mine', jsonEncode([for (final t in list.take(30)) t.toJson()]));

// ---------------- 보이는 모양 ----------------
// 공 색은 동행복권 공 색 (번호 구간별)
Color ballColor(int n) {
  if (n <= 10) return const Color(0xFFF5B800);
  if (n <= 20) return const Color(0xFF4FB3E8);
  if (n <= 30) return const Color(0xFFF26B6B);
  if (n <= 40) return const Color(0xFF9EA3AB);
  return const Color(0xFF8CC63F);
}

String won(int v) {
  if (v <= 0) return '-';
  String comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  if (v >= 100000000) {
    final eok = v ~/ 100000000;
    final man = (v % 100000000) ~/ 10000;
    return man > 0 ? '$eok억 ${comma(man)}만원' : '$eok억원';
  }
  if (v >= 10000) return '${comma(v ~/ 10000)}만원';
  return '${comma(v)}원';
}

String people(int n) => '${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}명';
