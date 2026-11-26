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
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

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
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: tc,
              constrained: false,
              minScale: 0.04,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(800),
              child: GestureDetector(
                onTapUp: (d) => _hit(d.localPosition, a, w),
                child: CustomPaint(
                  size: w.size,
                  painter: _Painter(
                    world: w,
                    lines: a,
                    strongSet: {for (final l in a) if (_strong(l)) l.name},
                    pick: pick,
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
            _Chip(label: '우리 동네', color: kInk, on: pick == null && !showAll, onTap: () => _choose(null)),
            _Chip(label: '전체', color: kInk, on: pick == null && showAll, onTap: () => _choose(null, all: true)),
            for (final l in [...near, ...a.where((x) => !near.contains(x))])
              _Chip(label: l.name, color: l.color, on: pick == l.name, onTap: () => _choose(pick == l.name ? null : l.name)),
          ]),
        ),
        if (sl != null) ...[
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
        if (t != null) ...[
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
  _Painter({
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
    final g = math.pow(px / 30, 0.7).clamp(1.0, 2.8).toDouble(); // 대표님 11-26: 키울 때 글자가 더 확실히 커지게
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
      drawLine(l, l.color.withValues(alpha: 0.16), 2.4 / s);
    }
    for (final l in bold.reversed) {
      drawLine(l, Colors.white, lw + 3 / s);
      drawLine(l, l.color, lw);
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
    labels.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (n, o, pri) in labels) {
      if (pri == 2 && px < 22) continue;
      if (pri == 1 && px < 9) continue;
      final sel = pri == 0;
      double fs(double b) => ((b * g) * 2).round() / 2; // 0.5 단위 (글자 그림 다시 쓰기)
      final tp = _text(n, size: fs(sel ? 16 : (pri == 1 ? 14 : 13)), w: sel ? FontWeight.w800 : (pri == 1 ? FontWeight.w700 : FontWeight.w600), color: sel ? Colors.white : kInk); // 대표님 11-26: 글자 더 크게
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
      o.pick != pick || o.tapped != tapped || o.lines != lines || !setEquals(o.strongSet, strongSet) || o.homeName != homeName;
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
