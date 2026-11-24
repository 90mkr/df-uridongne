// 지하철 (지하철 담당: 본부, 대표님 요청 11-24)
// 단지 홈 맨 아래 큰 카드: 가까운 역 · 방향별 다음 열차 (시간표 기준) · 네이버 지도 실시간 바로가기
// 상세 화면: 둘레 역들 · 방향별 다음 열차 3대 · 막차
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _band = [Color(0xFF6A5AE0), Color(0xFF8E7CF0)];
const _ink = Color(0xFF5B4BD6);

class SubwayFeature extends Feature {
  @override
  String get id => 'subway';
  @override
  String get name => '지하철';
  @override
  String get icon => 'subway';
  @override
  Slot get slot => Slot.tail;
  @override
  int get order => 20;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HomeCard(f: this, c: c);

  @override
  Widget page(BuildContext context, Complex c) => _Page(c: c);
}

class _HomeCard extends StatefulWidget {
  final Feature f;
  final Complex c;
  const _HomeCard({required this.f, required this.c});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  List<Station>? near;
  Timer? tick;

  @override
  void initState() {
    super.initState();
    nearStations(widget.c).then((l) {
      if (mounted) setState(() => near = l);
    });
    tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = near;
    if (l != null && l.isEmpty) return const SizedBox.shrink(); // 2km 안에 역이 없으면 카드 없음
    final s = (l == null || l.isEmpty) ? null : (l.firstWhere((x) => x.hasTable, orElse: () => l.first));
    final now = DateTime.now();
    Widget body;
    if (s == null) {
      body = const SizedBox(height: 96);
    } else if (!s.hasTable) {
      body = SizedBox(height: 96, child: Center(child: Text('시간표를 준비하고 있어요', style: T.small)));
    } else {
      body = Column(children: [
        _Dir(s: s, ud: 'U', now: now),
        const Divider(height: 1, thickness: 1, color: kLine),
        _Dir(s: s, ud: 'D', now: now),
      ]);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => openFeature(context, widget.f),
        child: Ink(
          decoration: cardBox(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: _band)),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                    child: const LineIcon('subway', size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '가까운 역 ', style: TextStyle(fontWeight: FontWeight.w400)),
                          TextSpan(text: '지하철', style: TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                        style: TextStyle(fontSize: 15.5, color: Colors.white, letterSpacing: -0.4, height: 1.2),
                      ),
                      Text(
                        s == null ? '역을 찾고 있어요' : '${s.name}역 · ${s.line} · ${distText(meters(widget.c.pos, s.pos))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF), height: 1.3),
                      ),
                    ]),
                  ),
                  const Text('시간표', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(14, 2, 14, 0), child: body),
              if (s != null) _NaverLink(s: s),
            ]),
          ),
        ),
      ),
    );
  }
}

// 방향 한 줄: 「계양 방면」 · 다음 열차 · 그다음
class _Dir extends StatelessWidget {
  final Station s;
  final String ud;
  final DateTime now;
  const _Dir({required this.s, required this.ud, required this.now});
  @override
  Widget build(BuildContext context) {
    final n = s.next(ud, now, n: 2);
    return SizedBox(
      height: 48,
      child: Row(children: [
        Container(
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: const Color(0x146A5AE0), borderRadius: BorderRadius.circular(7)),
          child: Text(s.towards(ud, now), maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.3, height: 1.2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            n.isEmpty ? '오늘 열차가 끝났어요' : (n.length > 1 ? '${n.first.clock} 출발 · 다음 ${n[1].minsText}' : '${n.first.clock} 출발 · 막차'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.tiny,
          ),
        ),
        Text(n.isEmpty ? '-' : n.first.minsText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: kInk)),
      ]),
    );
  }
}

class _NaverLink extends StatelessWidget {
  final Station s;
  const _NaverLink({required this.s});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openUrl(naverStationUrl(s)),
        child: Container(
          height: 38,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: const Row(children: [
            Expanded(child: Text('시간표 기준이에요. 늦어질 수 있어요.', style: T.tiny)),
            Text('네이버 지도에서 실시간', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBlue)),
            Icon(Icons.chevron_right_rounded, size: 16, color: kBlue),
          ]),
        ),
      );
}

// 상세: 둘레 역들
class _Page extends StatelessWidget {
  final Complex c;
  const _Page({required this.c});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('지하철', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: FutureBuilder<List<Station>>(
        future: nearStations(c, km: 3),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: kBlue));
          final l = (snap.data ?? const <Station>[]).take(5).toList();
          if (l.isEmpty) return const Center(child: Text('단지 3km 안에 지하철역이 없어요', style: T.small));
          final now = DateTime.now();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 28), children: [
                const Text('시간표 기준이에요. 실제 열차는 몇 분 늦어질 수 있어요.', style: T.small),
                const SizedBox(height: 10),
                for (final s in l) ...[
                  Container(
                    decoration: cardBox(),
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Row(children: [
                          const LineIcon('subway', size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: '${s.name}역 ', style: const TextStyle(fontWeight: FontWeight.w800)),
                                TextSpan(text: s.line, style: const TextStyle(fontWeight: FontWeight.w400, color: kSub, fontSize: 13)),
                              ]),
                              style: const TextStyle(fontSize: 15.5, letterSpacing: -0.4),
                            ),
                          ),
                          Text(distText(meters(c.pos, s.pos)), style: T.small),
                        ]),
                      ),
                      if (!s.hasTable)
                        const Padding(padding: EdgeInsets.fromLTRB(14, 6, 14, 12), child: Text('시간표를 준비하고 있어요', style: T.small))
                      else
                        for (final ud in ['U', 'D'])
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                            child: Row(children: [
                              SizedBox(width: 96, child: Text(s.towards(ud, now), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink))),
                              Expanded(
                                child: Wrap(spacing: 10, children: [
                                  for (final d in s.next(ud, now, n: 3))
                                    Text('${d.clock} (${d.minsText})', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                  if (s.next(ud, now).isEmpty) const Text('오늘 열차 끝', style: T.small),
                                ]),
                              ),
                              Text('막차 ${s.last(ud, now)}', style: T.tiny),
                            ]),
                          ),
                      _NaverLink(s: s),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}
