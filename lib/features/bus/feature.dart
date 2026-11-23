// 단지 앞 버스 (이 폴더는 단지 앞 버스 담당 방만 고침)
// 단지 홈 반쪽 카드: 단지에서 가장 가까운(또는 고정한) 정류장에 먼저 오는 버스 2대 — 몇 분 · 몇 정거장
// 상세 화면: 둘레 정류장 고르기 · 실시간 도착(30초마다) · 자주 타는 정류장 고정 · 노선 보기(정류장 순서·지금 버스 위치·첫차 막차) · 지도
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'page.dart';

class BusFeature extends Feature {
  @override
  String get id => 'bus';
  @override
  String get name => '단지 앞 버스';
  @override
  String get icon => 'bus';
  @override
  Slot get slot => Slot.half;
  @override
  int get order => 10;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HomeCard(feature: this, complex: c);

  @override
  Widget page(BuildContext context, Complex c) => BusPage(complex: c);

  // 「지금 우리 단지」 카드: 출퇴근 시간에 높게, 곧 오는 버스 두 대
  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    final stops = await stopsFor(c);
    if (stops.isEmpty) return null;
    final arr = await arrivals(stops.first);
    if (arr == null || arr.isEmpty) return null;
    final a = [...arr]..sort((x, y) => x.secs.compareTo(y.secs));
    final f = a.first;
    final rush = (now.hour >= 6 && now.hour < 10) || (now.hour >= 17 && now.hour < 20);
    return Brief(
      icon: 'bus',
      kicker: '${rush ? (now.hour < 12 ? '출근길' : '퇴근길') : '지금'} · ${stops.first.name}',
      bold: '${f.routeNo}번 ',
      hot: f.soon ? '곧 도착' : '${f.mins}분 뒤',
      rest: f.soon ? '' : ' 도착',
      sub: a.length > 1 ? '다음 ${a[1].routeNo}번 ${a[1].mins}분 · ${a[1].left}정거장 전' : '${f.left}정거장 전',
      score: rush ? 80 : 45,
    );
  }

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final list = await stopsNear(c);
    return [
      for (final s in list)
        MapPoint(
          id: 'bus.${s.id}',
          name: s.name,
          sub: '${distText(meters(c.pos, s.pos))}${s.no.isEmpty ? '' : ' · ${s.no}'}',
          pos: s.pos,
          onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => BusPage(complex: c, startStop: s.id))),
        ),
    ];
  }
}

class _HomeCard extends StatefulWidget {
  final BusFeature feature;
  final Complex complex;
  const _HomeCard({required this.feature, required this.complex});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  Stop? stop;
  List<Arrival>? arr;
  var loading = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _HomeCard old) {
    super.didUpdateWidget(old);
    if (old.complex.id != widget.complex.id) {
      stop = null;
      arr = null;
      loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await stopsFor(widget.complex);
    if (!mounted) return;
    stop = list.isEmpty ? null : list.first;
    await _refresh();
  }

  Future<void> _refresh() async {
    final s = stop;
    if (s != null) arr = await arrivals(s);
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature, c = widget.complex, s = stop;
    Widget body;
    String? foot;
    if (loading) {
      body = const ComingSoon('정류장을 찾고 있어요…');
    } else if (s == null) {
      body = ComingSoon(lastErr == BusErr.none ? '가까운 정류장이 없어요' : '정류장 자료를 모으고 있어요');
    } else {
      foot = '${s.name} · ${distText(meters(c.pos, s.pos))}';
      final a = arr;
      if (a == null) {
        body = ComingSoon(errText(lastErr));
      } else if (a.isEmpty) {
        body = const ComingSoon('지금 오는 버스가 없어요');
      } else {
        final rows = byRoute(a).take(2).toList();
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            _Line(a: rows[i].first, hot: i == 0),
          ],
        ]);
      }
    }
    return HomeCardBox(icon: f.icon, title: f.name, foot: foot, onTap: () => openFeature(context, f), child: body);
  }
}

class _Line extends StatelessWidget {
  final Arrival a;
  final bool hot;
  const _Line({required this.a, required this.hot});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(
          child: Text(a.routeNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.2)),
        ),
        Text(a.minsText, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: hot ? kBlue : kInk)),
        const SizedBox(width: 4),
        Text(a.left <= 0 ? '도착' : '${a.left}정거장', style: T.tiny),
      ]);
}
