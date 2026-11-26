// 지하철 노선도 (대표님 11-26) — 흰 바탕 노선도가 기본, 필요하면 「지도 위에 보기」.
//  · 손가락으로 키우고 밀기, 키울수록 역 이름이 더 보임 (겹치는 이름은 숨김)
//  · 환승역은 흰 알약, 우리 단지는 파란 점 + 이름표
//  · 아래: 호선 고르기 → 그 노선 띠(역 순서·환승·우리 역) → 역을 누르면 다음 열차·환승·지도 앱 실시간·길찾기
// 자료: web/data/subway/lines_<권역>.json (collector/features/subway_lines.py 가 주 1회 모음)
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/dnmap.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'route.dart';

class SubLine {
  final String name;
  final Color color;
  final List<List<LatLng>> paths;
  final List<(String, LatLng)> stations;
  const SubLine(this.name, this.color, this.paths, this.stations);
}

const _regions = <String, List<double>>{
  'capital': [126.30, 36.75, 127.75, 38.05],
  'busan': [128.75, 35.00, 129.35, 35.45],
  'daegu': [128.35, 35.75, 128.85, 36.05],
  'gwangju': [126.70, 35.05, 127.00, 35.25],
  'daejeon': [127.25, 36.25, 127.50, 36.50],
};

String? regionOf(LatLng p) {
  for (final e in _regions.entries) {
    final b = e.value;
    if (p.longitude >= b[0] && p.longitude <= b[2] && p.latitude >= b[1] && p.latitude <= b[3]) return e.key;
  }
  return null;
}

final Map<String, List<SubLine>> _cache = {};

Color _hex(String s) {
  final v = int.tryParse(s.replaceAll('#', ''), radix: 16);
  return v == null ? const Color(0xFF8A93A3) : Color(0xFF000000 | v);
}

Future<List<SubLine>> linesOf(String region) async {
  final have = _cache[region];
  if (have != null) return have;
  final j = await getJson('${dataBase}subway/lines_$region.json');
  final out = <SubLine>[];
  for (final x in (j is Map ? (j['lines'] as List? ?? const []) : const [])) {
    if (x is! Map) continue;
    LatLng pt(dynamic p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
    out.add(SubLine(
      '${x['l']}',
      _hex('${x['c']}'),
      [for (final p in (x['p'] as List? ?? const [])) if (p is List) [for (final q in p) if (q is List && q.length >= 2) pt(q)]],
      [for (final s in (x['s'] as List? ?? const [])) if (s is List && s.length >= 3) ('${s[0]}', LatLng((s[1] as num).toDouble(), (s[2] as num).toDouble()))],
    ));
  }
  if (out.isNotEmpty) _cache[region] = out;
  return out;
}

String _k(LatLng p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

/// 노선 띠: 이 노선에서 [from] 역을 지나는 가장 긴 줄 (갈라지는 노선은 우리 역이 있는 가지)
List<(String, LatLng)> lineStrip(SubLine l, String from) {
  final name = {for (final s in l.stations) _k(s.$2): s.$1};
  final pos = {for (final s in l.stations) _k(s.$2): s.$2};
  final adj = <String, Set<String>>{};
  for (final p in l.paths) {
    for (var i = 0; i + 1 < p.length; i++) {
      final a = _k(p[i]), b = _k(p[i + 1]);
      (adj[a] ??= {}).add(b);
      (adj[b] ??= {}).add(a);
      pos[a] ??= p[i];
      pos[b] ??= p[i + 1];
    }
  }
  final start = l.stations.where((s) => s.$1 == from).map((s) => _k(s.$2)).firstOrNull ?? (l.stations.isEmpty ? null : _k(l.stations.first.$2));
  if (start == null) return const [];
  List<String> longest(String n, Set<String> seen) {
    var best = <String>[];
    for (final m in adj[n] ?? const <String>{}) {
      if (seen.contains(m)) continue;
      seen.add(m);
      final r = longest(m, seen);
      seen.remove(m);
      if (r.length + 1 > best.length) best = [m, ...r];
    }
    return best;
  }

  // 우리 역에서 서로 다른 두 방향으로 가장 긴 줄 두 개를 이어 붙임
  final branches = <List<String>>[];
  for (final m in adj[start] ?? const <String>{}) {
    branches.add([m, ...longest(m, {start, m})]);
  }
  branches.sort((a, b) => b.length.compareTo(a.length));
  final left = branches.isNotEmpty ? branches[0] : <String>[];
  final right = branches.length > 1 ? branches.skip(1).firstWhere((b) => !b.any(left.contains), orElse: () => <String>[]) : <String>[];
  final keys = [...left.reversed, start, ...right];
  return [for (final k in keys) if (name[k] != null && pos[k] != null) (name[k]!, pos[k]!)];
}

// ---------------- 화면 ----------------

class LinesPage extends StatefulWidget {
  final Complex c;
  const LinesPage({super.key, required this.c});
  @override
  State<LinesPage> createState() => _LinesPageState();
}

class _LinesPageState extends State<LinesPage> {
  List<SubLine>? all;
  List<SubLine> near = const [];
  Map<String, List<SubLine>> byName = const {}; // 역 이름 → 지나는 호선 (환승)
  String? pick; // 고른 호선
  bool showAll = false; // 「전체」
  bool onMap = false; // 「지도 위에 보기」
  (String, SubLine)? tapped; // 누른 역
  // 「간단 경로」 (지하철 방 요청 11-26): 출발역·도착역 → 갈아타기 적은 길
  bool routeMode = false;
  String? rFrom, rTo;
  SubRoute? route;

  void _setRoute({String? from, String? to}) {
    setState(() {
      rFrom = from;
      rTo = to;
      route = (from != null && to != null) ? findRoute(all ?? const [], from, to) : null;
    });
    final r = route;
    if (r == null || onMap) return;
    // 경로가 다 보이게
    final w = world, b = box;
    if (w == null || b == null) return;
    final ps = [for (final l in r.legs) for (final st in l.stops) w.px(st.$2)];
    final xs = ps.map((p) => p.dx), ys = ps.map((p) => p.dy);
    final rc = Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
    final sc = math.min((b.width - 80) / math.max(rc.width, 1), (b.height - 80) / math.max(rc.height, 1)).clamp(0.04, 2.5);
    _setView(rc.center, sc, fy: 0.5);
  }
  List<Station> local = const []; // 동네 역 시간표 (다음 열차)
  final ctl = DnMapCtl();
  final tc = TransformationController();
  Size? box;
  _World? world;

  @override
  void initState() {
    super.initState();
    stationsOf(widget.c.areaId).then((l) {
      if (mounted) setState(() => local = l);
    });
    final r = regionOf(widget.c.pos);
    if (r == null) {
      all = const [];
      return;
    }
    linesOf(r).then((l) {
      if (!mounted) return;
      double dist(SubLine x) => x.stations.map((s) => meters(widget.c.pos, s.$2)).fold(double.infinity, (a, b) => a < b ? a : b);
      final n = l.where((x) => dist(x) <= 5000).toList()..sort((a, b) => dist(a).compareTo(dist(b)));
      final bn = <String, List<SubLine>>{};
      for (final x in l) {
        for (final s in x.stations) {
          final v = bn[s.$1] ??= [];
          if (!v.contains(x)) v.add(x);
        }
      }
      setState(() {
        all = l;
        near = n;
        byName = bn;
        world = _World(_regions[r]!);
      });
    });
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  SubLine? get stripLine => pick != null ? (all ?? const <SubLine>[]).where((x) => x.name == pick).firstOrNull : near.firstOrNull;

  String nearestOn(SubLine l) {
    var best = l.stations.first;
    for (final s in l.stations) {
      if (meters(widget.c.pos, s.$2) < meters(widget.c.pos, best.$2)) best = s;
    }
    return best.$1;
  }

  void _setView(Offset center, double s, {double fy = 0.42}) {
    final b = box;
    if (b == null) return;
    tc.value = Matrix4.translationValues(b.width / 2 - center.dx * s, b.height * fy - center.dy * s, 0)..multiply(Matrix4.diagonal3Values(s, s, 1));
  }

  // 흰 바탕 노선도: 처음 보는 자리·크기 (km = 화면 가로에 들어올 거리)
  void _resetView({LatLng? to, double km = 12}) {
    final w = world, b = box;
    if (w == null || b == null) return;
    _setView(w.px(to ?? widget.c.pos), (b.width / (km * _World.perKm)).clamp(0.04, 6.0));
  }

  void _fitLine(SubLine l) {
    final w = world, b = box;
    if (w == null || b == null || l.stations.isEmpty) return;
    final ps = [for (final s in l.stations) w.px(s.$2)];
    final xs = ps.map((p) => p.dx), ys = ps.map((p) => p.dy);
    final r = Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
    final s = math.min((b.width - 60) / math.max(r.width, 1), (b.height - 60) / math.max(r.height, 1)).clamp(0.04, 3.0);
    _setView(r.center, s, fy: 0.5);
  }

  void _choose(String? name, {bool all = false}) {
    setState(() {
      pick = name;
      showAll = all;
      tapped = null;
    });
    final l = name == null ? null : (this.all ?? const <SubLine>[]).where((x) => x.name == name).firstOrNull;
    if (onMap) {
      if (l != null) {
        ctl.fit([for (final s in l.stations) s.$2], const EdgeInsets.fromLTRB(40, 60, 40, 60));
      } else {
        ctl.move(widget.c.pos, all ? 11 : 13);
      }
    } else {
      l != null ? _fitLine(l) : _resetView(km: all ? 40 : 12);
    }
  }

  void _tapStation(String name, SubLine l, {bool move = false}) {
    if (routeMode) {
      if (rFrom == null || (rFrom != null && rTo != null)) {
        _setRoute(from: name);
      } else if (name != rFrom) {
        _setRoute(from: rFrom, to: name);
      }
      return;
    }
    setState(() => tapped = (name, l));
    if (!move) return;
    final p = l.stations.firstWhere((s) => s.$1 == name).$2;
    if (onMap) {
      ctl.move(p, 15);
    } else {
      final w = world;
      if (w != null) _setView(w.px(p), math.max(tc.value.getMaxScaleOnAxis(), 0.9), fy: 0.5);
    }
  }

  // 진하게 보일 노선: 고른 노선 · 기본은 우리 동네 노선 · 「전체」면 모두
  bool _strong(SubLine l) => pick != null ? l.name == pick : (showAll || near.contains(l));

  @override
  Widget build(BuildContext context) {
    final a = all;
    return DetailPage(
      title: '지하철 노선도',
      icon: 'subway',
      actions: [
        if (a != null && a.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: _Pill(
                label: onMap ? '노선만 보기' : '지도 위에 보기',
                onTap: () {
                  setState(() {
                    onMap = !onMap;
                    if (!onMap) box = null; // 돌아오면 우리 단지로
                  });
                },
              ),
            ),
          ),
      ],
      body: a == null
          ? const Center(child: CircularProgressIndicator(color: kBlue))
          : a.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('이 동네 노선도는 준비하고 있어요', style: T.small)))
              : Column(children: [
                  Expanded(child: onMap ? _mapView(a) : _plainView(a)),
                  _bottom(a),
                ]),
    );
  }

  // ---- 흰 바탕 노선도 ----
  Widget _plainView(List<SubLine> a) {
    final w = world!;
    return LayoutBuilder(builder: (context, c) {
      final first = box == null;
      box = c.biggest;
      if (first) WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
      return ClipRect(
        child: Stack(children: [
          // 손가락 움직임만 받는 판 — 그림은 그 위에 화면 기준으로 따로 그림
          // (대표님 11-26: 확대·축소하면 글자가 깨알처럼 작아짐 → 글자는 늘 화면에서 같은 크기)
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: tc,
              constrained: false,
              minScale: 0.04,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(800),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _hit(d.localPosition, a, w),
                child: SizedBox(width: w.size.width, height: w.size.height),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _Painter(
                    world: w,
                    lines: a,
                    strongSet: routeMode && route != null ? const <String>{} : {for (final l in a) if (_strong(l)) l.name},
                    pick: pick,
                    route: routeMode ? route : null,
                    routeEnds: routeMode ? [if (rFrom != null) rFrom!, if (rTo != null) rTo!] : const [],
                    byName: byName,
                    home: w.px(widget.c.pos),
                    homeName: widget.c.name,
                    tapped: tapped?.$1,
                    tc: tc,
                    view: () => box ?? Size.zero,
                  ),
                ),
              ),
            ),
          ),
          // 우리 단지로 돌아가기
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(side: BorderSide(color: Color(0xFFDDE2EA))),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _resetView(),
                child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.home_outlined, size: 20, color: kBlue)),
              ),
            ),
          ),
        ]),
      );
    });
  }

  void _hit(Offset p, List<SubLine> a, _World w) {
    // 역 이름 글자를 눌렀으면 그 역
    for (final (n, rect) in _Painter.hitLabels) {
      if (!rect.contains(p)) continue;
      final l = (byName[n] ?? const <SubLine>[]).where(_strong).firstOrNull ?? (byName[n] ?? const <SubLine>[]).firstOrNull;
      if (l != null) return _tapStation(n, l);
    }
    final r = 28 / tc.value.getMaxScaleOnAxis();
    (String, SubLine)? best;
    var bd = r;
    var bestStrong = false;
    for (final l in a) {
      final st = _strong(l);
      if (!st && pick != null) continue;
      for (final s in l.stations) {
        final d = (w.px(s.$2) - p).distance;
        if (d > r) continue;
        // 진한 노선의 역을 먼저
        if (best == null || (st && !bestStrong) || (st == bestStrong && d < bd)) {
          bd = d;
          best = (s.$1, l);
          bestStrong = st;
        }
      }
    }
    if (best == null) {
      setState(() => tapped = null);
    } else {
      _tapStation(best.$1, best.$2);
    }
  }

  // ---- 지도 위에 보기 ----
  Widget _mapView(List<SubLine> a) {
    final w = pick != null ? 7.0 : (showAll ? 4.0 : 6.0);
    final base = [for (final l in a) if (_strong(l)) l];
    final lines = <DnLine>[
      for (final l in base.reversed)
        for (final p in l.paths)
          if (p.length >= 2) ...[
            DnLine(p, color: Colors.white, width: w + 4),
            DnLine(p, color: l.color, width: w),
          ],
    ];
    // 「간단 경로」: 지나는 구간을 굵게 위에 덧그림
    final rr = routeMode ? route : null;
    if (rr != null) {
      for (final leg in rr.legs) {
        final pts = [for (final st in leg.stops) st.$2];
        lines.add(DnLine(pts, color: Colors.white, width: 13));
        lines.add(DnLine(pts, color: leg.line.color, width: 9));
      }
    }
    final marks = <DnMark>[];
    final seen = <String>{};
    for (final l in base) {
      for (final s in l.stations) {
        if (pick == null && meters(widget.c.pos, s.$2) > 8000) continue;
        if (!seen.add(s.$1)) continue;
        final sel = tapped?.$1 == s.$1;
        marks.add(DnMark(
          id: 'st|${s.$1}',
          pos: s.$2,
          key: '${s.$1}|${l.name}|$sel',
          size: sel ? const Size(190, 58) : const Size(10, 10),
          z: sel ? 9 : 1,
          onTap: () => _tapStation(s.$1, l),
          child: sel ? _StationTag(name: s.$1, color: l.color) : _Dot(color: l.color),
        ));
      }
    }
    return DnMap(center: widget.c.pos, zoom: 13, lines: lines, marks: marks, ctl: ctl, onMapTap: () => setState(() => tapped = null));
  }

  // ---- 아래: 호선 고르기 · 노선 띠 · 역 정보 ----
  Widget _bottom(List<SubLine> a) {
    final sl = stripLine;
    final t = tapped;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 10, 0, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE6EAF0)))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 32,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: kPad), children: [
            _Chip(label: '경로 찾기', color: kBlue, on: routeMode, onTap: () => setState(() {
                  routeMode = !routeMode;
                  tapped = null;
                  if (!routeMode) {
                    rFrom = null;
                    rTo = null;
                    route = null;
                  }
                })),
            _Chip(label: '우리 동네', color: kInk, on: !routeMode && pick == null && !showAll, onTap: () => _choose(null)),
            _Chip(label: '전체', color: kInk, on: pick == null && showAll, onTap: () => _choose(null, all: true)),
            for (final l in [...near, ...a.where((x) => !near.contains(x))])
              _Chip(label: l.name, color: l.color, on: pick == l.name, onTap: () => _choose(pick == l.name ? null : l.name)),
          ]),
        ),
        if (routeMode) ...[
          const SizedBox(height: 10),
          _RoutePanel(
            from: rFrom,
            to: rTo,
            route: route,
            names: {for (final l in a) for (final st in l.stations) st.$1}.toList()..sort(),
            onPick: (isFrom, n) => isFrom ? _setRoute(from: n, to: rTo == n ? null : rTo) : _setRoute(from: rFrom, to: n),
            onSwap: () => _setRoute(from: rTo, to: rFrom),
            onClear: () => _setRoute(),
          ),
        ] else if (sl != null) ...[
          const SizedBox(height: 10),
          _Strip(
            key: ValueKey('strip_${sl.name}'),
            line: sl,
            stations: lineStrip(sl, nearestOn(sl)),
            mine: nearestOn(sl),
            tapped: t?.$2 == sl ? t?.$1 : null,
            byName: byName,
            onTap: (n) => _tapStation(n, sl, move: true),
          ),
        ],
        if (!routeMode && t != null) ...[
          const SizedBox(height: 8),
          _StationCard(
            name: t.$1,
            line: t.$2,
            transfer: [for (final x in byName[t.$1] ?? const <SubLine>[]) if (x != t.$2) x],
            local: local,
            c: widget.c,
            onClose: () => setState(() => tapped = null),
          ),
        ],
      ]),
    );
  }
}

// ---------------- 흰 바탕 그리기 ----------------

class _World {
  final List<double> bbox; // 서 남 동 북
  static const perKm = 60.0; // 1배일 때 1km = 60점
  _World(this.bbox);
  double get _cos => math.cos((bbox[1] + bbox[3]) / 2 * math.pi / 180);
  Size get size => Size((bbox[2] - bbox[0]) * 111 * _cos * perKm, (bbox[3] - bbox[1]) * 111 * perKm);
  Offset px(LatLng p) => Offset((p.longitude - bbox[0]) * 111 * _cos * perKm, (bbox[3] - p.latitude) * 111 * perKm);
}

class _Painter extends CustomPainter {
  final _World world;
  final List<SubLine> lines;
  final Set<String> strongSet;
  final String? pick, tapped;
  final Map<String, List<SubLine>> byName;
  final Offset home;
  final String homeName;
  final TransformationController tc;
  final Size Function() view;
  final SubRoute? route;
  final List<String> routeEnds;
  _Painter({
    this.route,
    this.routeEnds = const [],
    required this.world,
    required this.lines,
    required this.strongSet,
    required this.pick,
    required this.byName,
    required this.home,
    required this.homeName,
    required this.tapped,
    required this.tc,
    required this.view,
  }) : super(repaint: tc);

  static final Map<String, TextPainter> _tp = {};
  static List<(String, Rect)> hitLabels = []; // 그린 역 이름 자리 (이름을 눌러도 그 역)
  TextPainter _text(String s, {double size = 11, FontWeight w = FontWeight.w600, Color color = kInk}) {
    final key = '$s|$size|${w.index}|${color.toARGB32()}';
    return _tp[key] ??= (TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Pretendard', fontSize: size, fontWeight: w, color: color, height: 1.1, letterSpacing: -0.3)),
      textDirection: TextDirection.ltr,
    )..layout());
  }

  bool _strong(SubLine l) => strongSet.contains(l.name);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(tc.value.storage); // 화면 기준 판에 지도 좌표로 그림
    _paint(canvas);
    canvas.restore();
  }

  void _paint(Canvas canvas) {
    final s = tc.value.getMaxScaleOnAxis();
    // 지금 보이는 곳 (가장자리 여유)
    final inv = Matrix4.inverted(tc.value);
    final v = view();
    final tl = MatrixUtils.transformPoint(inv, Offset.zero), br = MatrixUtils.transformPoint(inv, Offset(v.width, v.height));
    final vis = Rect.fromPoints(tl, br).inflate(80 / s);

    final faint = [for (final l in lines) if (!_strong(l)) l];
    final bold = [for (final l in lines) if (_strong(l)) l];
    // 키울수록 글자·점·선도 같이 커짐 (지도 카드처럼) — 1km 가 30점일 때 기준, 최대 2.2배
    final px = s * _World.perKm; // 1km 가 화면 몇 점
    final g = math.pow(px / 30, 0.35).clamp(1.0, 1.5).toDouble(); // 대표님 11-26: 글자는 너무 크지도 작지도 않게 — 확대해도 조금만 커짐
    final lw = (pick != null ? 5.0 : 4.0) * math.min(g, 1.6) / s;

    void drawLine(SubLine l, Color col, double w) {
      final p = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final path in l.paths) {
        if (path.length < 2) continue;
        final pth = Path();
        for (var i = 0; i < path.length; i++) {
          final o = world.px(path[i]);
          i == 0 ? pth.moveTo(o.dx, o.dy) : pth.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(pth, p);
      }
    }

    for (final l in faint) {
      drawLine(l, l.color.withValues(alpha: 0.42), 3.2 / s); // 대표님 11-26: 다른 노선이 너무 흐려 안 보임
    }
    for (final l in bold.reversed) {
      drawLine(l, Colors.white, lw + 3 / s);
      drawLine(l, l.color, lw);
    }

    // 「간단 경로」: 지나는 구간만 진하게 + 진행 방향 화살표 (나머지 노선은 위에서 흐리게)
    final r = route;
    final routeLabels = <(String, Offset, int)>[];
    if (r != null) {
      final rw = 7.0 * math.min(g, 1.4) / s;
      for (final leg in r.legs) {
        final pth = Path();
        for (var i = 0; i < leg.stops.length; i++) {
          final o = world.px(leg.stops[i].$2);
          i == 0 ? pth.moveTo(o.dx, o.dy) : pth.lineTo(o.dx, o.dy);
        }
        Paint pen(Color c, double w) => Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(pth, pen(Colors.white, rw + 4 / s));
        canvas.drawPath(pth, pen(leg.line.color, rw));
        // 화살표: 구간마다 몇 개 (진행 방향)
        final step = math.max(1, leg.count ~/ 3);
        for (var i = 0; i < leg.stops.length - 1; i += step) {
          final a = world.px(leg.stops[i].$2), b = world.px(leg.stops[i + 1].$2);
          final d = b - a;
          if (d.distance * s < 26) continue;
          final m = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          final u = d / d.distance, nrm = Offset(-u.dy, u.dx);
          final h = 5.5 * g / s;
          final tri = Path()
            ..moveTo(m.dx + u.dx * h, m.dy + u.dy * h)
            ..lineTo(m.dx - u.dx * h + nrm.dx * h * 0.8, m.dy - u.dy * h + nrm.dy * h * 0.8)
            ..lineTo(m.dx - u.dx * h - nrm.dx * h * 0.8, m.dy - u.dy * h - nrm.dy * h * 0.8)
            ..close();
          canvas.drawPath(tri, Paint()..color = Colors.white);
        }
        for (final st in leg.stops) {
          final o = world.px(st.$2);
          canvas.drawCircle(o, 3.2 * g / s, Paint()..color = Colors.white);
          routeLabels.add((st.$1, o, 2));
        }
      }
      // 갈아타는 역: 흰 알약 + 진한 테두리 · 출발·도착: 파란 큰 점
      final ringP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / s
        ..color = const Color(0xFF1F2430);
      for (var i = 1; i < r.legs.length; i++) {
        final o = world.px(r.legs[i].stops.first.$2);
        final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 18 * g / s, height: 12 * g / s), Radius.circular(6 * g / s));
        canvas.drawRRect(rr, Paint()..color = Colors.white);
        canvas.drawRRect(rr, ringP);
        routeLabels.add(('${r.legs[i].from} 환승', o, 1));
      }
      for (final (n, o) in [(r.from, world.px(r.fromPos)), (r.to, world.px(r.toPos))]) {
        canvas.drawCircle(o, 9 * g / s, Paint()..color = kBlue.withValues(alpha: 0.2));
        canvas.drawCircle(o, 6 * g / s, Paint()..color = kBlue);
        canvas.drawCircle(
            o,
            6 * g / s,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5 / s
              ..color = Colors.white);
        routeLabels.add((n == r.from ? '출발 $n' : '도착 $n', o, 0));
      }
    } else {
      // 출발역만 고른 상태
      for (final n in routeEnds) {
        for (final l in lines) {
          final st = l.stations.where((x) => x.$1 == n).firstOrNull;
          if (st == null) continue;
          final o = world.px(st.$2);
          canvas.drawCircle(o, 9 * g / s, Paint()..color = kBlue.withValues(alpha: 0.2));
          canvas.drawCircle(o, 6 * g / s, Paint()..color = kBlue);
          routeLabels.add(('출발 $n', o, 0));
          break;
        }
      }
    }

    // 역: 환승역은 흰 알약, 보통 역은 흰 점 + 노선 색 테두리
    final placed = <Rect>[];
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / s;
    final fill = Paint()..color = Colors.white;
    final labels = <(String, Offset, int)>[]; // 이름, 위치, 우선순위 (0 누른 역 · 1 환승 · 2 보통)
    final drawn = <String>{};
    for (final l in bold) {
      for (final st in l.stations) {
        final o = world.px(st.$2);
        if (!vis.contains(o)) continue;
        final multi = (byName[st.$1] ?? const <SubLine>[]).where(_strong).length > 1;
        if (multi) {
          if (!drawn.add('T|${st.$1}')) continue;
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 15 * g / s, height: 10 * g / s), Radius.circular(5 * g / s));
          canvas.drawRRect(r, fill);
          canvas.drawRRect(r, ring..color = const Color(0xFF3A3F4A));
        } else if (st.$1 == tapped) {
          // 고른 역: 진한 파란 큰 점 + 흰 테 (대표님 11-26)
          canvas.drawCircle(o, 8 * g / s, Paint()..color = kBlue.withValues(alpha: 0.18));
          canvas.drawCircle(o, 5.6 * g / s, Paint()..color = kBlue);
          canvas.drawCircle(o, 5.6 * g / s, ring..color = Colors.white);
        } else {
          canvas.drawCircle(o, 4.2 * g / s, fill);
          canvas.drawCircle(o, 4.2 * g / s, ring..color = l.color);
        }
        if (drawn.add('L|${st.$1}')) labels.add((st.$1, o, st.$1 == tapped ? 0 : (multi ? 1 : 2)));
      }
    }

    // 우리 단지
    final hp = Paint()..color = kBlue;
    canvas.drawCircle(home, 8 / s, Paint()..color = kBlue.withValues(alpha: 0.18));
    canvas.drawCircle(home, 4.6 / s, hp);
    canvas.drawCircle(
        home,
        4.6 / s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / s
          ..color = Colors.white);
    final ht = _text(homeName.length > 12 ? '${homeName.substring(0, 12)}…' : homeName, size: 11, w: FontWeight.w700, color: Colors.white);
    final hr = Rect.fromLTWH(home.dx - (ht.width / 2 + 8) / s, home.dy + 10 / s, (ht.width + 16) / s, (ht.height + 8) / s);
    canvas.drawRRect(RRect.fromRectAndRadius(hr, Radius.circular(hr.height / 2)), hp);
    canvas.save();
    canvas.translate(hr.left + 8 / s, hr.top + 4 / s);
    canvas.scale(1 / s);
    ht.paint(canvas, Offset.zero);
    canvas.restore();
    placed.add(hr);

    // 역 이름: 중요한 것부터, 겹치면 건너뜀. 멀리서 볼 땐 환승역만
    final hits = <(String, Rect)>[];
    if (routeLabels.isNotEmpty) {
      final named = {for (final x in routeLabels) if (x.$3 < 2) x.$1.replaceAll(RegExp(r'^(출발|도착) | 환승$'), '')};
      labels
        ..removeWhere((x) => named.contains(x.$1))
        ..addAll([for (final x in routeLabels) if (x.$3 < 2 || !named.contains(x.$1)) (x.$1, x.$2, x.$3 == 2 ? 1 : x.$3)]);
    }
    labels.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (n, o, pri) in labels) {
      if (pri == 2 && px < 22) continue;
      if (pri == 1 && px < 9) continue;
      final sel = pri == 0;
      double fs(double b) => ((b * g) * 2).round() / 2; // 0.5 단위 (글자 그림 다시 쓰기)
      final tp = _text(n, size: fs(sel ? 15 : (pri == 1 ? 13.5 : 12.5)), w: sel ? FontWeight.w800 : (pri == 1 ? FontWeight.w700 : FontWeight.w600), color: sel ? Colors.white : kInk); // 대표님 11-26: 글자 더 크게
      final w = tp.width / s, h = tp.height / s;
      // 오른쪽 → 왼쪽 → 위 → 아래 중 빈 곳
      final gap = (sel ? 12 + 4 * g : 6 + 4 * g) / s;
      final cands = [
        Rect.fromLTWH(o.dx + gap, o.dy - h / 2, w, h),
        Rect.fromLTWH(o.dx - gap - w, o.dy - h / 2, w, h),
        Rect.fromLTWH(o.dx - w / 2, o.dy - gap - h, w, h),
        Rect.fromLTWH(o.dx - w / 2, o.dy + gap, w, h),
      ];
      Rect? at;
      for (final r in cands) {
        if (!placed.any((p) => p.overlaps(r))) {
          at = r;
          break;
        }
      }
      if (at == null && !sel) continue;
      at ??= cands.first;
      placed.add(at.inflate(2 / s));
      hits.add((n, at.inflate(4 / s)));
      // 선 위에서도 읽히게 반투명 흰 바탕 · 고른 역은 파란 알약에 흰 글자 (잘 보이게)
      if (sel) {
        final pill = RRect.fromRectAndRadius(at.inflate(5 / s), Radius.circular(9 / s));
        canvas.drawRRect(pill.shift(Offset(0, 1 / s)), Paint()
          ..color = kBlue.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 / s));
        canvas.drawRRect(pill, Paint()..color = kBlue);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(at.inflate(1.5 / s), Radius.circular(3 / s)), Paint()..color = const Color(0xD9FFFFFF));
      }
      canvas.save();
      canvas.translate(at.left, at.top);
      canvas.scale(1 / s);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
    hitLabels = hits;
  }

  @override
  bool shouldRepaint(covariant _Painter o) =>
      o.route != route || o.routeEnds.join() != routeEnds.join() || o.pick != pick || o.tapped != tapped || o.lines != lines || !setEquals(o.strongSet, strongSet) || o.homeName != homeName;
}

// ---------------- 노선 띠 ----------------

class _Strip extends StatefulWidget {
  final SubLine line;
  final List<(String, LatLng)> stations;
  final String mine;
  final String? tapped;
  final Map<String, List<SubLine>> byName;
  final void Function(String) onTap;
  const _Strip({super.key, required this.line, required this.stations, required this.mine, required this.tapped, required this.byName, required this.onTap});
  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  final sc = ScrollController();
  // 역마다 이름 길이만큼 칸 너비 (대표님 11-26: 따닥따닥 붙고 두 줄로 갈라짐 → 넓게, 한 줄로)
  static double wOf(String n) => (n.length * 13.5 + 26).clamp(74, 190).toDouble();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = widget.stations.indexWhere((s) => s.$1 == widget.mine);
      if (i < 0 || !sc.hasClients) return;
      var x = kPad;
      for (final s in widget.stations.take(i)) {
        x += wOf(s.$1);
      }
      final to = (x + wOf(widget.stations[i].$1) / 2 - sc.position.viewportDimension / 2).clamp(0.0, sc.position.maxScrollExtent);
      sc.jumpTo(to);
    });
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.stations;
    final col = widget.line.color;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: kPad),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(11)),
            child: Text(widget.line.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          if (st.length >= 2) Expanded(child: Text('${st.first.$1} ↔ ${st.last.$1} · 역 ${st.length}개', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)),
        ]),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 86,
        child: ListView.builder(
          controller: sc,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          itemCount: st.length,
          itemBuilder: (context, i) {
            final n = st[i].$1;
            final me = n == widget.mine, sel = n == widget.tapped;
            final tr = [for (final x in widget.byName[n] ?? const <SubLine>[]) if (x != widget.line) x];
            final big = me || sel;
            return InkWell(
              onTap: () => widget.onTap(n),
              child: SizedBox(
                width: wOf(n),
                child: Column(children: [
                  SizedBox(
                    height: 26,
                    child: Stack(alignment: Alignment.center, children: [
                      Row(children: [
                        Expanded(child: Container(height: 4, color: i == 0 ? Colors.transparent : col)),
                        Expanded(child: Container(height: 4, color: i == st.length - 1 ? Colors.transparent : col)),
                      ]),
                      // 고른 역: 진하고 크게 (노선 색으로 꽉 찬 점 + 흰 테 + 둘레 빛)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: sel ? 24 : (me ? 18 : (tr.isNotEmpty ? 16 : 12)),
                        height: sel ? 24 : (me ? 18 : 12),
                        decoration: BoxDecoration(
                          color: (me || sel) ? col : Colors.white,
                          borderRadius: BorderRadius.circular(tr.isNotEmpty && !sel ? 6 : 12),
                          border: Border.all(color: (me || sel) ? Colors.white : (tr.isNotEmpty ? const Color(0xFF3A3F4A) : col), width: 1),
                          boxShadow: sel
                              ? [BoxShadow(color: col.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 2)]
                              : me
                                  ? [BoxShadow(color: col.withValues(alpha: 0.35), blurRadius: 6)]
                                  : null,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 5),
                  // 이름은 한 줄 — 고른 역은 노선 색 알약에 흰 굵은 글자
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(horizontal: sel ? 9 : 2, vertical: sel ? 3 : 1),
                    decoration: BoxDecoration(color: sel ? col : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      n,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.2, fontWeight: (me || sel) ? FontWeight.w800 : FontWeight.w500, color: sel ? Colors.white : kInk, letterSpacing: -0.4),
                    ),
                  ),
                  if (me) const Padding(padding: EdgeInsets.only(top: 2), child: Text('우리 역', style: TextStyle(fontSize: 10, color: kBlue, fontWeight: FontWeight.w700))),
                  if (!me && tr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (final x in tr.take(4)) Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: x.color, shape: BoxShape.circle)),
                      ]),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------- 역 정보 ----------------

class _StationCard extends StatelessWidget {
  final String name;
  final SubLine line;
  final List<SubLine> transfer;
  final List<Station> local;
  final Complex c;
  final VoidCallback onClose;
  const _StationCard({required this.name, required this.line, required this.transfer, required this.local, required this.c, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final pos = line.stations.firstWhere((s) => s.$1 == name).$2;
    final st = local.where((s) => s.name == name && s.hasTable && (s.line == line.name || s.line.contains(line.name) || line.name.contains(s.line))).firstOrNull;
    final now = DateTime.now();
    final km = meters(c.pos, pos) / 1000;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kPad),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
      decoration: cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$name역', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final x in [line, ...transfer])
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(color: x.color, borderRadius: BorderRadius.circular(10)),
                    child: Text(x.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ]),
            ),
          ),
          Text(km < 1 ? '단지에서 ${(km * 1000).round()}m' : '단지에서 ${km.toStringAsFixed(1)}km', style: T.tiny),
          IconButton(onPressed: onClose, visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 18, color: kMute)),
        ]),
        if (st != null) ...[
          for (final ud in st.dirs)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 10),
              child: Row(children: [
                SizedBox(width: 120, child: Text(st.dest(ud, now), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kSub))),
                for (final d in st.next(ud, now, n: 2))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: d.minsText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      TextSpan(text: ' ${d.clock}', style: const TextStyle(fontSize: 10.5, color: kMute)),
                    ])),
                  ),
              ]),
            ),
          const Padding(padding: EdgeInsets.only(top: 2), child: Text('시간표 기준 · 실시간은 지도 앱에서', style: T.tiny)),
        ],
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Row(children: [
            Expanded(child: _Btn(label: '지도 앱에서 실시간', onTap: () => _openStation(name, line.name, pos))),
            const SizedBox(width: 8),
            Expanded(child: _Btn(label: '여기까지 길찾기', strong: true, onTap: () => _route(c, '$name역', pos))),
          ]),
        ),
      ]),
    );
  }
}

// 지도 앱으로 역 열기 (길찾기 칸에서 고른 앱 → 카카오맵 → 네이버 지도 → 카카오맵 웹)
Future<void> _openStation(String name, String line, LatLng p) async {
  final q = Uri.encodeComponent('$name역 $line');
  if (!kIsWeb) {
    final pick = await prefGet('bus.goApp') ?? '';
    final kakao = 'kakaomap://search?q=$q&p=${p.latitude},${p.longitude}';
    final naver = 'nmap://search?query=$q&appname=kr.designfeel.dongne';
    for (final u in pick == 'naver' ? [naver, kakao] : [kakao, naver]) {
      try {
        if (await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
  }
  await launchUrl(Uri.parse('https://map.kakao.com/link/search/$q'), mode: LaunchMode.externalApplication);
}

// 우리 단지 → 이 역 대중교통 길찾기 (길찾기 칸과 같은 방식)
Future<void> _route(Complex c, String to, LatLng p) async {
  final sn = Uri.encodeComponent(c.name), dn = Uri.encodeComponent(to);
  final web = 'https://map.kakao.com/link/by/traffic/$sn,${c.lat},${c.lng}/$dn,${p.latitude},${p.longitude}';
  if (!kIsWeb) {
    final pick = await prefGet('bus.goApp') ?? '';
    final kakao = 'kakaomap://route?sp=${c.lat},${c.lng}&ep=${p.latitude},${p.longitude}&by=PUBLICTRANSIT';
    final naver = 'nmap://route/public?slat=${c.lat}&slng=${c.lng}&sname=$sn&dlat=${p.latitude}&dlng=${p.longitude}&dname=$dn&appname=kr.designfeel.dongne';
    for (final u in pick == 'naver' ? [naver, kakao] : [kakao, naver]) {
      try {
        if (await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
  }
  await launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication);
}

// 출발역 → 도착역 지도 앱 대중교통 길찾기 (카카오맵 없으면 웹 · 네이버 지도도 고를 수 있게)
Future<void> _openRouteApp(String app, SubRoute r) async {
  final sn = Uri.encodeComponent('${r.from}역'), dn = Uri.encodeComponent('${r.to}역');
  final s = r.fromPos, d = r.toPos;
  final kakaoWeb = 'https://map.kakao.com/link/by/traffic/$sn,${s.latitude},${s.longitude}/$dn,${d.latitude},${d.longitude}';
  final naverWeb = 'https://map.naver.com/p/directions/${s.longitude},${s.latitude},$sn/${d.longitude},${d.latitude},$dn/-/transit';
  if (!kIsWeb) {
    final u = app == 'naver'
        ? 'nmap://route/public?slat=${s.latitude}&slng=${s.longitude}&sname=$sn&dlat=${d.latitude}&dlng=${d.longitude}&dname=$dn&appname=kr.designfeel.dongne'
        : 'kakaomap://route?sp=${s.latitude},${s.longitude}&ep=${d.latitude},${d.longitude}&by=PUBLICTRANSIT';
    try {
      if (await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
  }
  await launchUrl(Uri.parse(app == 'naver' ? naverWeb : kakaoWeb), mode: LaunchMode.externalApplication);
}

// 「간단 경로」 아래 칸: 출발·도착 고르기 · 요약 · 지도 앱 자세히
class _RoutePanel extends StatelessWidget {
  final String? from, to;
  final SubRoute? route;
  final List<String> names;
  final void Function(bool isFrom, String name) onPick;
  final VoidCallback onSwap, onClear;
  const _RoutePanel({required this.from, required this.to, required this.route, required this.names, required this.onPick, required this.onSwap, required this.onClear});

  Future<void> _search(BuildContext context, bool isFrom) async {
    final n = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StationSearch(title: isFrom ? '출발역' : '도착역', names: names),
    );
    if (n != null) onPick(isFrom, n);
  }

  @override
  Widget build(BuildContext context) {
    final r = route;
    Widget field(String label, String? v, bool isFrom) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _search(context, isFrom),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: v == null ? kLine : kBlue.withValues(alpha: 0.5))),
              child: Row(children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: kSub, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(child: Text(v ?? '역 검색·노선도에서 누르기', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: v == null ? 12.5 : 15, fontWeight: v == null ? FontWeight.w500 : FontWeight.w800, color: v == null ? kMute : kInk, letterSpacing: -0.4))),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          field('출발', from, true),
          IconButton(tooltip: '출발·도착 바꾸기', onPressed: from == null && to == null ? null : onSwap, icon: const Icon(Icons.swap_horiz_rounded, color: kBlue)),
          field('도착', to, false),
        ]),
        if (from != null && to != null && r == null)
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('두 역을 잇는 길을 찾지 못했어요 (다른 권역이거나 자료가 없어요)', style: T.small)),
        if (r != null) ...[
          const SizedBox(height: 10),
          Text(r.summary, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -0.3, height: 1.35)),
          const SizedBox(height: 6),
          for (final leg in r.legs)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: leg.line.color, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Text('${leg.line.name}  ${leg.from} → ${leg.to}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kInk))),
                Text('${leg.count}정거장', style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Btn(label: '네이버 지도', onTap: () => _openRouteApp('naver', r))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _Btn(label: '자세히 보기 (카카오맵)', strong: true, onTap: () => _openRouteApp('kakao', r))),
          ]),
        ] else if (from == null)
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('노선도에서 출발역을 누르고, 이어서 도착역을 누르세요.', style: T.small)),
        if (from != null && to == null)
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('이제 도착역을 누르세요.', style: T.small)),
        const SizedBox(height: 6),
        const Text('대략적인 경로입니다. 실제 소요 시간은 지도 앱에서 확인하세요.', style: T.tiny),
      ]),
    );
  }
}

// 역 이름 검색
class _StationSearch extends StatefulWidget {
  final String title;
  final List<String> names;
  const _StationSearch({required this.title, required this.names});
  @override
  State<_StationSearch> createState() => _StationSearchState();
}

class _StationSearchState extends State<_StationSearch> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final l = q.isEmpty ? widget.names : widget.names.where((n) => n.contains(q)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => q = v.trim().replaceAll('역', '')),
                decoration: InputDecoration(
                  hintText: '${widget.title} 이름',
                  prefixIcon: const Icon(Icons.search_rounded, color: kBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: l.length,
                itemBuilder: (_, i) => ListTile(dense: true, title: Text('${l[i]}역', style: const TextStyle(fontSize: 15)), onTap: () => Navigator.pop(context, l[i])),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------- 작은 부품 ----------------

class _Btn extends StatelessWidget {
  final String label;
  final bool strong;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap, this.strong = false});
  @override
  Widget build(BuildContext context) => Material(
        color: strong ? kBlue : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: strong ? kBlue : const Color(0xFFDDE2EA))),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 38,
            child: Center(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: strong ? Colors.white : kInk))),
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFFDDE2EA))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kInk)),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.color, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: on ? color : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: on ? color : const Color(0xFFDDE2EA))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!on) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6)],
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : kInk)),
              ]),
            ),
          ),
        ),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 1))),
      );
}

class _StationTag extends StatelessWidget {
  final String name;
  final Color color;
  const _StationTag({required this.name, required this.color});
  // 대표님 11-26: 고른 역이 잘 표가 안 남 → 노선 색을 진하게·글자 크게·그림자, 아래 점도 꽉 찬 큰 점
  Color get _deep {
    final h = HSLColor.fromColor(color);
    return h.withLightness((h.lightness - 0.18).clamp(0.22, 0.5)).withSaturation((h.saturation + 0.1).clamp(0, 1)).toColor();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _deep,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [BoxShadow(color: _deep.withValues(alpha: 0.45), blurRadius: 12)],
            ),
            child: Text('$name역', maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, letterSpacing: -0.4)),
          ),
          const SizedBox(height: 3),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: _deep, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1), boxShadow: [BoxShadow(color: _deep.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]),
          ),
        ]),
      );
}


// ---------------- 홈 위젯 「우리 역 노선도」 (대표님 11-26) ----------------
// 우리 단지에서 가장 가까운 노선의 띠 — 우리 역이 가운데, 역을 누르면 노선도 화면
class LineHomeWidget extends StatefulWidget {
  final Complex c;
  const LineHomeWidget({super.key, required this.c});
  @override
  State<LineHomeWidget> createState() => _LineHomeWidgetState();
}

class _LineHomeWidgetState extends State<LineHomeWidget> {
  SubLine? line;
  String mine = '';
  List<(String, LatLng)> strip = const [];
  Map<String, List<SubLine>> byName = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = regionOf(widget.c.pos);
    if (r == null) return;
    final l = await linesOf(r);
    if (l.isEmpty || !mounted) return;
    double dist(SubLine x) => x.stations.map((s) => meters(widget.c.pos, s.$2)).fold(double.infinity, (a, b) => a < b ? a : b);
    final best = [...l]..sort((a, b) => dist(a).compareTo(dist(b)));
    final ln = best.first;
    if (dist(ln) > 5000 || ln.stations.isEmpty) return;
    var st = ln.stations.first;
    for (final s in ln.stations) {
      if (meters(widget.c.pos, s.$2) < meters(widget.c.pos, st.$2)) st = s;
    }
    final bn = <String, List<SubLine>>{};
    for (final x in l) {
      for (final s in x.stations) {
        final v = bn[s.$1] ??= [];
        if (!v.contains(x)) v.add(x);
      }
    }
    setState(() {
      line = ln;
      mine = st.$1;
      strip = lineStrip(ln, st.$1);
      byName = bn;
    });
  }

  void _open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinesPage(c: widget.c)));

  @override
  Widget build(BuildContext context) {
    final l = line;
    if (l == null || strip.length < 2) return const SizedBox.shrink();
    return Container(
      decoration: cardBox(r: 20),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 0, kPad - 4, 8),
            child: Row(children: [
              const LineIcon('subway', size: 26),
              const SizedBox(width: 8),
              const Text('우리 역 ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
              const Text('노선도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: -0.5, color: kInk)),
              const Spacer(),
              const Text('전체 노선도', style: TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w600)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: kSub),
            ]),
          ),
        ),
        _Strip(key: ValueKey('${l.name}|$mine'), line: l, stations: strip, mine: mine, tapped: null, byName: byName, onTap: (_) => _open()),
      ]),
    );
  }
}
