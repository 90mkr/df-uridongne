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
      body = const SizedBox(height: 70, child: Center(child: Text('시간표를 준비하고 있어요', style: T.small)));
    } else {
      body = Column(children: [
        _Dir(s: s, ud: 'U', now: now),
        const Divider(height: 1, thickness: 1, color: kLine),
        _Dir(s: s, ud: 'D', now: now),
      ]);
    }
    // 대표님 시안(11-24): 보라 머리띠 + 오른쪽 전철 그림 + 흰 「시간표」 단추, 흰 판이 둥글게 겹침, 아래 안내는 옅은 상자
    // 모서리까지 깔끔하게 잘리도록: 그림자 상자 > 둥글게 자르기 > 흰 바탕 > 누르기
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF6A5AE0).withValues(alpha: 0.16), blurRadius: 16)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => openFeature(context, widget.f),
            child: Stack(children: [
              Container(
                height: 104,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7E6BE7), Color(0xFF8571EE)])),
                child: Stack(children: [
                  // 대표님 사진(11-24) 깔고, 글자 쪽(왼쪽)만 색 필터
                  Positioned.fill(child: Image.asset('assets/art/subway_bg.jpg', fit: BoxFit.cover, alignment: const Alignment(0.7, 0.1), filterQuality: FilterQuality.medium)),
                  const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xF26A55DC), Color(0xC27E6BE7), Color(0x2E7E6BE7)], stops: [0, 0.45, 0.8])))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 12, 16),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                        child: const LineIcon('subway', size: 32),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('가까운 역 지하철', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2)),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.place_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                s == null ? '역을 찾고 있어요' : '${s.name}역 · ${s.line} · ${distText(meters(widget.c.pos, s.pos))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xF2FFFFFF), height: 1.3),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('시간표', style: TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w800)),
                          Icon(Icons.chevron_right_rounded, color: _ink, size: 18),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 90),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (s != null)
                      // 노선 띠: 동그라미 번호 + 노선 이름
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Color(0xFF2F6BFF), shape: BoxShape.circle),
                            child: Text(RegExp(r'\d').firstMatch(s.line)?.group(0) ?? 'M', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          Text(s.line, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2F4FC8))),
                          const Spacer(),
                          Text('${s.name}역', style: const TextStyle(fontSize: 12, color: kSub)),
                        ]),
                      ),
                    body,
                    if (s != null) _NaverLink(s: s),
                    const SizedBox(height: 2),
                  ]),
                ),
              ),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => openUrl(naverStationUrl(s)),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE3E8F0))),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, size: 15, color: kSub),
                SizedBox(width: 6),
                Expanded(child: Text('시간표 기준이에요. 늦어질 수 있어요.', style: T.tiny)),
                Text('네이버 지도에서 실시간', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kBlue)),
                Icon(Icons.chevron_right_rounded, size: 16, color: kBlue),
              ]),
            ),
          ),
        ),
      );
}

// 상세: 둘레 역들 — 홈 카드와 같은 사진 머리띠 · 노선 띠 · 시간 알약 (대표님 11-24)
class _Page extends StatelessWidget {
  final Complex c;
  const _Page({required this.c});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        SizedBox(
          height: top + 120,
          child: Stack(children: [
            Positioned.fill(child: Image.asset('assets/art/subway_bg.jpg', fit: BoxFit.cover, alignment: const Alignment(0.7, 0.1))),
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xF26A55DC), Color(0xC27E6BE7), Color(0x2E7E6BE7)], stops: [0, 0.45, 0.8]))),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: top + 6,
              child: Row(children: [
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 24, color: Colors.white)),
                const LineIcon('subway', size: 30),
                const SizedBox(width: 8),
                const Text('가까운 역 지하철', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white)),
              ]),
            ),
            Positioned(
              left: kPad,
              bottom: 14,
              child: const Text('시간표 기준이에요. 실제 열차는 몇 분 늦어질 수 있어요.', style: TextStyle(fontSize: 12, color: Color(0xE6FFFFFF))),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Station>>(
            future: nearStations(c, km: 3),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: kBlue));
              final l = (snap.data ?? const <Station>[]).take(5).toList();
              if (l.isEmpty) return const Center(child: Text('단지 3km 안에 지하철역이 없어요', style: T.small));
              final now = DateTime.now();
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 28), children: [
                    for (final s in l) ...[
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6EBF3)), boxShadow: const [BoxShadow(color: Color(0x101C3A6E), blurRadius: 10)]),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: Color(0xFF2F6BFF), shape: BoxShape.circle),
                                child: Text(RegExp(r'\d').firstMatch(s.line)?.group(0) ?? 'M', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: '${s.name}역 ', style: const TextStyle(fontWeight: FontWeight.w800, color: kInk)),
                                    TextSpan(text: s.line, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2F4FC8), fontSize: 12.5)),
                                  ]),
                                  style: const TextStyle(fontSize: 15, letterSpacing: -0.4),
                                ),
                              ),
                              Text(distText(meters(c.pos, s.pos)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSub)),
                            ]),
                          ),
                          if (!s.hasTable)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('시간표를 준비하고 있어요', style: T.small)))
                          else
                            for (final ud in ['U', 'D'])
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(children: [
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 84),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: const Color(0x146A5AE0), borderRadius: BorderRadius.circular(12)),
                                    child: Text(s.towards(ud, now), maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                                      for (final (i, d) in s.next(ud, now, n: 3).indexed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(color: i == 0 ? const Color(0xFFEEF4FF) : const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(12)),
                                          child: Text('${d.clock} · ${d.minsText}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: i == 0 ? kBlue : kInk)),
                                        ),
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
        ),
      ]),
    );
  }
}
