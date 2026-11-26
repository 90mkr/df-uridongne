// 지하철 노선도 (대표님 11-26) — 공식 노선도 그림 대신, 우리 지도 위에 노선 색 선과 역 점으로 그린다.
// 자료: web/data/subway/lines_<권역>.json (collector/features/subway_lines.py 가 주 1회 모음)
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/dnmap.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

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
  _cache[region] = out;
  return out;
}

class LinesPage extends StatefulWidget {
  final Complex c;
  const LinesPage({super.key, required this.c});
  @override
  State<LinesPage> createState() => _LinesPageState();
}

class _LinesPageState extends State<LinesPage> {
  List<SubLine>? all;
  List<SubLine> near = const [];
  String? pick; // 골라 본 호선 (없으면 동네 노선 전부)
  bool showAll = false; // 「전체」 노선 보기
  (String, String)? tapped; // 누른 역 (이름, 호선)
  final ctl = DnMapCtl();

  @override
  void initState() {
    super.initState();
    final r = regionOf(widget.c.pos);
    if (r == null) {
      all = const [];
      return;
    }
    linesOf(r).then((l) {
      if (!mounted) return;
      // 단지 5km 안에 역이 있는 호선 = 우리 동네 노선 (가까운 순)
      double dist(SubLine x) => x.stations.map((s) => meters(widget.c.pos, s.$2)).fold(double.infinity, (a, b) => a < b ? a : b);
      final n = l.where((x) => dist(x) <= 5000).toList()..sort((a, b) => dist(a).compareTo(dist(b)));
      setState(() {
        all = l;
        near = n;
      });
    });
  }

  List<SubLine> get shown {
    final a = all ?? const <SubLine>[];
    if (pick != null) return a.where((x) => x.name == pick).toList();
    return a;
  }

  void _focus(String? name, {bool all = false}) {
    setState(() {
      pick = name;
      showAll = all;
      tapped = null;
    });
    final l = name == null ? null : (all ?? const <SubLine>[]).where((x) => x.name == name).firstOrNull;
    if (l != null && l.stations.length >= 2) {
      ctl.fit([for (final s in l.stations) s.$2], const EdgeInsets.fromLTRB(40, 60, 40, 140));
    } else {
      ctl.move(widget.c.pos, all ? 11 : 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = all;
    final focus = pick;
    // 보이는 노선: 골랐으면 그 노선만 · 기본은 우리 동네 노선만 · 「전체」면 모두 (대표님 11-26: 겹쳐서 색이 안 보임)
    final base = focus != null ? shown : (showAll ? (a ?? const <SubLine>[]) : near);
    final w = focus != null ? 7.0 : (showAll ? 4.0 : 6.0);
    final lines = <DnLine>[
      // 노선마다 흰 테두리를 먼저 깔아 지도 위에서도, 겹치는 곳에서도 색이 또렷하게
      for (final l in base.reversed)
        for (final p in l.paths)
          if (p.length >= 2) ...[
            DnLine(p, color: Colors.white, width: w + 4),
            DnLine(p, color: l.color, width: w),
          ],
    ];
    // 역 점: 고른 노선은 모든 역, 아니면 동네 노선 역 중 단지 6km 안
    final marks = <DnMark>[];
    final seen = <String>{};
    for (final l in (focus != null ? shown : near)) {
      for (final s in l.stations) {
        if (focus == null && meters(widget.c.pos, s.$2) > 6000) continue;
        final id = '${l.name}|${s.$1}';
        if (!seen.add(id)) continue;
        final sel = tapped?.$1 == s.$1;
        marks.add(DnMark(
          id: id,
          pos: s.$2,
          key: '$id|$sel',
          size: sel ? const Size(150, 44) : const Size(10, 10),
          z: sel ? 9 : 1,
          onTap: () => setState(() => tapped = (s.$1, l.name)),
          child: sel ? _StationTag(name: s.$1, color: l.color) : _Dot(color: l.color),
        ));
      }
    }
    return DetailPage(
      title: '지하철 노선도',
      icon: 'subway',
      body: a == null
          ? const Center(child: CircularProgressIndicator(color: kBlue))
          : a.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('이 동네 노선도는 준비하고 있어요', style: T.small)))
              : Stack(children: [
                  Positioned.fill(
                    child: DnMap(
                      center: widget.c.pos,
                      zoom: 13,
                      lines: lines,
                      marks: marks,
                      ctl: ctl,
                      onMapTap: () => setState(() => tapped = null),
                    ),
                  ),
                  // 호선 고르기 (옆으로 밀기) — 동네 노선 먼저, 「전체」
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(0, 10, 0, 12 + MediaQuery.paddingOf(context).bottom),
                      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x141C3A6E), blurRadius: 14)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 8),
                          child: Row(children: [
                            const MixTitle('우리 동네', '노선', size: 13.5),
                            const Spacer(),
                            Text(tapped == null ? '역을 누르면 이름이 보여요' : '${tapped!.$1}역 · ${tapped!.$2}', style: T.tiny),
                          ]),
                        ),
                        SizedBox(
                          height: 34,
                          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: kPad), children: [
                            _Chip(label: '우리 동네', color: kInk, on: focus == null && !showAll, onTap: () => _focus(null)),
                            _Chip(label: '전체', color: kInk, on: focus == null && showAll, onTap: () => _focus(null, all: true)),
                            for (final l in [...near, ...a.where((x) => !near.contains(x))])
                              _Chip(label: l.name, color: l.color, on: focus == l.name, onTap: () => _focus(focus == l.name ? null : l.name)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
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
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 1)),
            child: Text('$name역', maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
          ),
          const SizedBox(height: 3),
          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 1))),
        ]),
      );
}
