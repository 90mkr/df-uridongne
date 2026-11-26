// 생활 도구 탭 (본부 방만 고침): 등록된 모든 기능을 칸으로
// 대표님 시안(11-24) 참고: 위 하늘색 띠 + 그림, 흰 칸 안 아이콘 뒤에 옅은 색 빛, 한 줄에 4개
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';
import 'remote.dart';
import 'data.dart';
import 'complex_pick.dart';
import 'guide.dart';
import 'home.dart';
import 'ui.dart';
import '../features/board/noti.dart';

// 아이콘 뒤 옅은 빛 (칸마다 조금씩 다른 색)
// 칸이 좁아 이름은 짧게 (낱말 중간에서 줄 바뀜 없게)
const _short = {'weather': '날씨·미세먼지', 'board': '단지 이야기', 'events': '행사·축제', 'trash': '분리수거', 'pharmacy': '문 연 약국', 'postcode': '택배·우편', 'deals': '최근 거래', 'bus': '단지 앞 버스', 'roulette': '오늘 뭐 먹지?', 'school': '학교 급식', 'parking': '주차 어디?', 'mycar': '내 차 어디?', 'toilet': '화장실'};

const _glow = [Color(0xFFFFE7B8), Color(0xFFCFE2FF), Color(0xFFE6DDFF), Color(0xFFFFD9DF), Color(0xFFD5F3DE), Color(0xFFFFE2CC)];

class ToolsTab extends StatelessWidget {
  const ToolsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final list = [...features]..sort((a, b) => a.slot.index != b.slot.index ? a.slot.index.compareTo(b.slot.index) : a.order.compareTo(b.order));
    // 급할 때 찾는 화장실은 맨 앞 칸 (대표님 11-25: 두 번 안에 닿게)
    final ti = list.indexWhere((f) => f.id == 'toilet');
    if (ti > 0) list.insert(0, list.removeAt(ti));
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
              Positioned(left: 0, right: 0, top: 0, bottom: 2, child: artImage('assets/art/tools_bg.jpg', fit: BoxFit.cover, alignment: Alignment.topRight, filterQuality: FilterQuality.medium)),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LayoutBuilder(builder: (context, c) {
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
              const SizedBox(height: 26),
              const _AppSettings(),
              ]),
            ),
          ),
        ),
      ]),
      ]),
    );
  }
}

// 생활 도구 맨 아래 「앱 설정」 (대표님 11-27): 사용 방법 띠 + 자주 바꾸는 설정 네 칸
class _AppSettings extends StatelessWidget {
  const _AppSettings();
  @override
  Widget build(BuildContext context) {
    final c = complex.value;
    final items = <(IconData, String, VoidCallback?)>[
      (Icons.dashboard_customize_outlined, '홈 꾸미기', c == null ? null : () => openHomeEditFor(context, c)),
      (Icons.apartment_rounded, '우리 단지', () => pickComplex(context)),
      (Icons.notifications_none_rounded, '알림 설정', c == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardNotiPage(c: c)))),
      (Icons.menu_book_outlined, '사용 방법', () => openGuide(context)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const MixTitle('앱', '설정', size: 17),
      const SizedBox(height: 10),
      // 사용 방법 띠
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openGuide(context),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6ECF5)),
              boxShadow: const [BoxShadow(color: Color(0x141C3A6E), blurRadius: 10)],
            ),
            child: const Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '처음이세요? ', style: TextStyle(fontWeight: FontWeight.w300)),
                    TextSpan(text: '$kAppName 사용 방법', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]), style: TextStyle(fontSize: 15, letterSpacing: -0.4)),
                  SizedBox(height: 3),
                  Text('단지 고르기부터 홈 꾸미기까지, 그림으로 쉽게', style: TextStyle(fontSize: 12, color: kSub)),
                ]),
              ),
              LineIcon('book', size: 40),
              Icon(Icons.chevron_right_rounded, color: kMute),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 9),
      Row(children: [
        for (final (k, it) in items.indexed) ...[
          if (k > 0) const SizedBox(width: 9),
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: it.$3,
                child: Ink(
                  height: 74,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6ECF5))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(it.$1, size: 24, color: it.$3 == null ? kMute : const Color(0xFF24539F)),
                    const SizedBox(height: 6),
                    Text(it.$2, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ]),
    ]);
  }
}
