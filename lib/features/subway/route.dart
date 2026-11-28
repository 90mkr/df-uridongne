// 노선도 「간단 경로」 (지하철 방 요청 11-26)
// 기준: 갈아타는 횟수가 적은 길 → 같으면 정거장이 적은 길. 시간표는 쓰지 않음 (대략적인 경로)
// 자료: 노선마다 역 위치(좌표)·선 모양(paths) — 선 위 꼭짓점 중 역 자리끼리 이어 역 사이 연결을 만든다
import 'package:latlong2/latlong.dart';

import '../../core/data.dart' show meters;
import 'lines_page.dart' show SubLine;

class RouteLeg {
  final SubLine line;
  final List<(String, LatLng)> stops; // 처음·끝 역 포함
  const RouteLeg(this.line, this.stops);
  int get count => stops.length - 1; // 정거장 수
  String get from => stops.first.$1;
  String get to => stops.last.$1;

  /// 이 구간 어림 시간(분): 역마다 서고 떠나는 데 0.9분 + 1km 에 0.95분 (인천1호선·서울 2호선 실제 시간과 맞춰 봄)
  /// 급행 성격 노선(GTX·공항철도·신분당선)은 더 빠르게
  double get minutes {
    final fast = line.name.contains('GTX') ? 0.5 : (line.name.contains('공항철도') || line.name.contains('신분당') ? 0.75 : 0.95);
    var m = 0.0;
    for (var i = 0; i + 1 < stops.length; i++) {
      m += 0.9 + meters(stops[i].$2, stops[i + 1].$2) / 1000 * fast;
    }
    return m;
  }
}

class SubRoute {
  final List<RouteLeg> legs;
  const SubRoute(this.legs);
  int get transfers => legs.length - 1;
  int get stops => legs.fold(0, (a, l) => a + l.count);
  String get from => legs.first.from;
  String get to => legs.last.to;
  LatLng get fromPos => legs.first.stops.first.$2;
  LatLng get toPos => legs.last.stops.last.$2;

  /// 어림 소요 시간(분) — 갈아탈 때마다 5분(걷기+기다리기). 시간표가 아니라 거리로 어림한 값
  int get minutes => (legs.fold(0.0, (a, l) => a + l.minutes) + transfers * 5).round();

  /// 「인천1호선 → 부평 환승 1호선 → 신도림 환승 2호선 → 강남, 모두 n정거장」
  String get summary {
    final b = StringBuffer(legs.first.line.name);
    for (var i = 1; i < legs.length; i++) {
      b.write(' → ${legs[i].from} 환승 ${legs[i].line.name}');
    }
    b.write(' → $to, 모두 $stops정거장');
    return b.toString();
  }
}

String _k(LatLng p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

// 노선별 역 이웃 (한 번 만들어 둠)
final _adjCache = <SubLine, Map<String, Set<String>>>{};
final _posCache = <SubLine, Map<String, LatLng>>{};

Map<String, Set<String>> _adj(SubLine l) {
  final have = _adjCache[l];
  if (have != null) return have;
  final name = <String, String>{};
  final pos = <String, LatLng>{};
  for (final s in l.stations) {
    name[_k(s.$2)] = s.$1;
    pos[s.$1] ??= s.$2;
  }
  final adj = <String, Set<String>>{};
  for (final p in l.paths) {
    String? last;
    for (final q in p) {
      final n = name[_k(q)];
      if (n == null) continue;
      if (last != null && last != n) {
        (adj[last] ??= {}).add(n);
        (adj[n] ??= {}).add(last);
      }
      last = n;
    }
  }
  // 선 모양에 역이 안 걸린 노선: 역 목록 순서대로 잇기 (모자란 자료 대비)
  if (adj.isEmpty) {
    for (var i = 0; i + 1 < l.stations.length; i++) {
      final a = l.stations[i].$1, b = l.stations[i + 1].$1;
      (adj[a] ??= {}).add(b);
      (adj[b] ??= {}).add(a);
    }
  }
  _posCache[l] = pos;
  return _adjCache[l] = adj;
}

/// 출발역 → 도착역 (역 이름). 못 찾으면 null
SubRoute? findRoute(List<SubLine> lines, String from, String to) {
  if (from == to) return null;
  final adj = {for (final l in lines) l: _adj(l)};
  // 상태 = (역, 노선) · 비용 = (환승 수, 정거장 수)
  final best = <String, (int, int)>{};
  final prev = <String, String?>{};
  final key = <String, (String, SubLine)>{};
  String id(String n, SubLine l) => '$n|${l.name}';
  final open = <String>{};
  for (final l in lines) {
    if (_posCache[l]?.containsKey(from) != true) continue;
    final k = id(from, l);
    best[k] = (0, 0);
    prev[k] = null;
    key[k] = (from, l);
    open.add(k);
  }
  bool less((int, int) a, (int, int) b) => a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);
  final done = <String>{};
  String? goal;
  while (open.isNotEmpty) {
    String? cur;
    for (final k in open) {
      if (cur == null || less(best[k]!, best[cur]!)) cur = k;
    }
    open.remove(cur);
    done.add(cur!);
    final (n, l) = key[cur]!;
    if (n == to) {
      goal = cur;
      break;
    }
    final c = best[cur]!;
    void relax(String n2, SubLine l2, (int, int) cost) {
      final k2 = id(n2, l2);
      if (done.contains(k2)) return;
      final b = best[k2];
      if (b == null || less(cost, b)) {
        best[k2] = cost;
        prev[k2] = cur;
        key[k2] = (n2, l2);
        open.add(k2);
      }
    }

    for (final m in adj[l]![n] ?? const <String>{}) {
      relax(m, l, (c.$1, c.$2 + 1));
    }
    // 같은 이름 역에서 다른 노선으로 갈아타기
    for (final l2 in lines) {
      if (l2 == l || _posCache[l2]?.containsKey(n) != true) continue;
      relax(n, l2, (c.$1 + 1, c.$2));
    }
  }
  if (goal == null) return null;
  // 되짚어 구간 나누기
  final seq = <(String, SubLine)>[];
  for (String? k = goal; k != null; k = prev[k]) {
    seq.add(key[k]!);
  }
  final steps = seq.reversed.toList();
  final legs = <RouteLeg>[];
  var cur = <(String, LatLng)>[];
  SubLine? line;
  for (final (n, l) in steps) {
    final p = _posCache[l]![n]!;
    if (line != l) {
      if (line != null && cur.length >= 2) legs.add(RouteLeg(line, cur));
      line = l;
      cur = [(n, p)];
    } else {
      cur.add((n, p));
    }
  }
  if (line != null && cur.length >= 2) legs.add(RouteLeg(line, cur));
  return legs.isEmpty ? null : SubRoute(legs);
}
