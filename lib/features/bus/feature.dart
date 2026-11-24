// 단지 앞 버스 (이 폴더는 단지 앞 버스 담당 방만 고침)
// 단지 홈 반쪽 카드: 단지에서 가장 가까운(또는 고정한) 정류장에 먼저 오는 버스 2대 — 몇 분 · 몇 정거장
// 상세 화면: 둘레 정류장 고르기 · 실시간 도착(30초마다) · 자주 타는 정류장 고정 · 노선 보기(정류장 순서·지금 버스 위치·첫차 막차) · 지도
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
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
  Slot get slot => Slot.tail; // 대표님 11-24: 실시간이라 늦게 떠서 홈 맨 아래 가로 한 줄 크게
  @override
  int get order => 10;
  @override
  String get version => '0.3.0';
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
    // 가로 한 줄 큰 카드: 파란 머리띠(정류장) + 노선별 줄 (최대 4개). 불러오는 동안도 높이를 잡아 둬 화면이 안 튐
    Widget body;
    if (loading) {
      body = Column(children: [for (var i = 0; i < 3; i++) const _Ghost()]);
    } else if (s == null) {
      body = _msg(lastErr == BusErr.none ? '가까운 정류장이 없어요' : '정류장 자료를 모으고 있어요');
    } else if (arr == null) {
      body = _msg(errText(lastErr));
    } else if (arr!.isEmpty) {
      body = _msg('지금 오는 버스가 없어요');
    } else {
      final rows = byRoute(arr!).take(4).toList();
      body = Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: kLine),
          _Row(r: rows[i], hot: i == 0),
        ],
      ]);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => openFeature(context, f),
        child: Ink(
          decoration: cardBox(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 머리띠
              Container(
                height: 64,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2F6BFF), Color(0xFF5B8CFF)])),
                child: Stack(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                        child: const LineIcon('bus', size: 26),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '단지 앞 ', style: TextStyle(fontWeight: FontWeight.w400)),
                              TextSpan(text: '버스', style: TextStyle(fontWeight: FontWeight.w800)),
                            ]),
                            style: TextStyle(fontSize: 15.5, color: Colors.white, letterSpacing: -0.4, height: 1.2),
                          ),
                          Text(
                            s == null ? '정류장을 찾고 있어요' : '${s.name} · ${distText(meters(c.pos, s.pos))}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF), height: 1.3),
                          ),
                        ]),
                      ),
                      const Text('실시간', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                    ]),
                  ),
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 6), child: body),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _msg(String t) => SizedBox(height: 120, child: Center(child: Text(t, style: T.small)));
}

// 노선 종류 색 (광역 빨강 · 간선 파랑 · 지선 초록 · 그 밖 파랑)
Color _typeColor(String t) {
  if (t.contains('광역') || t.contains('급행') || t.contains('좌석')) return const Color(0xFFE5484D);
  if (t.contains('지선') || t.contains('마을')) return const Color(0xFF2EA36B);
  return kBlue;
}

class _Row extends StatelessWidget {
  final RouteArrivals r;
  final bool hot;
  const _Row({required this.r, required this.hot});
  @override
  Widget build(BuildContext context) {
    final a = r.first, n = r.next;
    final col = _typeColor(a.type);
    return SizedBox(
      height: 46,
      child: Row(children: [
        Container(
          constraints: const BoxConstraints(minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)),
          child: Text(a.routeNo, maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: col, letterSpacing: -0.3, height: 1.2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            n == null ? a.leftText : '${a.leftText} · 다음 ${n.minsText}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.tiny,
          ),
        ),
        Text(a.minsText, style: TextStyle(fontSize: hot ? 18 : 16, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: hot ? kBlue : kInk)),
      ]),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: Row(children: [
          Container(width: 58, height: 26, decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 10, margin: const EdgeInsets.only(right: 60), decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(5)))),
          Container(width: 40, height: 16, decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(5))),
        ]),
      );
}
