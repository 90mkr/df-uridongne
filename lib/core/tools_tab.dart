// 생활 도구 탭 (본부 방만 고침): 등록된 모든 기능을 칸으로
// 대표님 시안(11-24) 참고: 위 하늘색 띠 + 그림, 흰 칸 안 아이콘 뒤에 옅은 색 빛, 한 줄에 4개
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';

// 아이콘 뒤 옅은 빛 (칸마다 조금씩 다른 색)
// 칸이 좁아 이름은 짧게 (낱말 중간에서 줄 바뀜 없게)
const _short = {'weather': '날씨·미세먼지', 'board': '단지 이야기', 'events': '행사·축제', 'trash': '분리수거', 'pharmacy': '문 연 약국', 'postcode': '택배·우편', 'deals': '최근 거래', 'bus': '단지 앞 버스', 'roulette': '오늘 뭐 먹지?', 'school': '학교 급식'};

const _glow = [Color(0xFFFFE7B8), Color(0xFFCFE2FF), Color(0xFFE6DDFF), Color(0xFFFFD9DF), Color(0xFFD5F3DE), Color(0xFFFFE2CC)];

class ToolsTab extends StatelessWidget {
  const ToolsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final list = [...features]..sort((a, b) => a.slot.index != b.slot.index ? a.slot.index.compareTo(b.slot.index) : a.order.compareTo(b.order));
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FE),
      body: Stack(children: [
        // 대표님 배경(11-25): 오른쪽 위 반짝이 아이콘 + 물결, 아래로 바탕색에 녹아듦
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + 300,
          child: ClipRect(
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/art/tools_bg.jpg', fit: BoxFit.cover, alignment: Alignment.topRight, filterQuality: FilterQuality.medium),
              // 아래 끝을 바탕색으로 덮어 녹임 (사진 끝 줄이 남지 않게 — 페이드 효과 대신 덮개)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFF1F5FE).withValues(alpha: 0), const Color(0xFFF1F5FE).withValues(alpha: 0), const Color(0xFFF1F5FE), const Color(0xFFF1F5FE)], stops: const [0, 0.7, 1, 1]),
                ),
              ),
            ]),
            ),
        ),
        ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: 120 + top,
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Stack(children: [
            Positioned(
              left: kPad,
              top: 34,
              child: Row(children: [
                Image.asset('assets/nav/grid.png', width: 34, height: 34),
                const SizedBox(width: 10),
                const Text('생활 도구', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              ]),
            ),
          ]),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 28),
              child: LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 560 ? 6 : 4; // 대표님 11-24: 한 줄에 4개
                const gap = 9.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final (i, f) in list.indexed)
                    SizedBox(
                      width: w,
                      height: w * 1.12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => openFeature(context, f),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE6ECF5)),
                              boxShadow: const [BoxShadow(color: Color(0x141C3A6E), blurRadius: 10)],
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Stack(alignment: Alignment.center, children: [
                                Container(
                                  width: w * 0.62,
                                  height: w * 0.62,
                                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_glow[i % _glow.length], _glow[i % _glow.length].withValues(alpha: 0)])),
                                ),
                                LineIcon(f.icon, size: w * 0.44),
                              ]),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(_short[f.id] ?? f.name,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4)),
                              ),
                              if (!f.ready)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                  decoration: BoxDecoration(color: const Color(0xFFEFF2F6), borderRadius: BorderRadius.circular(10)),
                                  child: const Text('준비 중', style: TextStyle(fontSize: 9.5, color: kSub)),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
            ),
          ),
        ),
      ]),
      ]),
    );
  }
}
