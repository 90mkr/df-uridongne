// 화면 틀 (본부 방만 고침): 하단 메뉴 다섯 칸 — 단지 홈 · 전화번호부 · 지도 · 생활 도구 · 내 정보
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

import '../features/registry.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'fb.dart';
import 'feature.dart';
import 'home.dart';
import 'here.dart';
import 'home_layout.dart';
import 'map_tab.dart';
import 'me.dart';
import 'theme.dart';
import 'tools_tab.dart';
import 'push.dart';
import 'remote.dart';
import 'settings_sync.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  bool booting = true;

  @override
  void initState() {
    super.initState();
    _boot();
    mapAsk.addListener(_toMap);
    homeEditAsk.addListener(_toHome);
    homeToolsAsk.addListener(_toTools);
  }

  // 홈 아이콘 줄 끝 「전체 보기」 → 생활 도구 탭
  void _toTools() {
    if (mounted) setState(() => tab = 3);
  }

  // 내 정보의 「홈 편집」 → 홈 탭으로 (홈이 편집 모드로 바뀜)
  void _toHome() {
    if (mounted) setState(() => tab = 0);
  }

  // 다른 화면의 「지도로 보기」 → 지도 탭으로
  void _toMap() {
    if (mapAsk.value != null && mounted) setState(() => tab = 2);
  }

  Future<void> _boot() async {
    fbReady();
    await Future.wait([loadAreas(), loadSavedComplex(), Future.delayed(const Duration(milliseconds: 1400))]);
    myLocation(ask: false);
    startSettingsSync(); // 로그인해 있으면 설정(우리 단지·홈 배치) 서버 백업·되살리기
    if (!mounted) return;
    setState(() => booting = false);
    _shortcuts();
    // 게시판 알림 주제: 앱 켤 때와 단지를 바꿀 때 다시 맞추기
    final c0 = complex.value;
    if (c0 != null) syncPush(c0);
    complex.addListener(() {
      final c = complex.value;
      if (c != null) syncPush(c);
    });
    if (complex.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pickComplex(context, first: true));
    }
  }

  // 앱 아이콘을 길게 누르면 나오는 바로가기 (대표님 11-25: 급할 때 화장실 바로)
  void _shortcuts() {
    if (kIsWeb) return;
    try {
      const qa = QuickActions();
      qa.initialize((type) {
        final c = complex.value;
        final f = featureById(type);
        if (c == null || f == null || !mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => featurePage(ctx, f.id, c, f.page)));
      });
      qa.setShortcutItems(const [ShortcutItem(type: 'toilet', localizedTitle: '가까운 화장실')]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (booting) return const _Splash();
    return ValueListenableBuilder(
      valueListenable: complex,
      builder: (context, c, _) {
        final pages = <Widget>[
          const HomeTab(),
          c == null
              ? const _NoComplex()
              : (featureById('phonebook') == null ? const SizedBox() : featurePage(context, 'phonebook', c, featureById('phonebook')!.page)),
          const MapTab(),
          const ToolsTab(),
          const MeTab(),
        ];
        return Scaffold(
          body: IndexedStack(index: tab, children: pages),
          bottomNavigationBar: _nav(),
        );
      },
    );
  }

  // 하단 메뉴: 떠 있는 흰 둥근 띠 + 색 아이콘, 고른 칸은 파란 알약 (시안 11-23)
  // 하단 메뉴 (대표님 11-24): 둥근 띄움 없이 화면 끝까지 평평하게 · 새 아이콘 · 아이콘은 늘 원래 색, 고른 칸은 옅은 파랑 바탕·파랑 글자·위 파랑 줄
  Widget _nav() {
    const items = [('home', '단지 홈'), ('list', '전화번호부'), ('map', '지도'), ('grid', '생활 도구'), ('me', '내 정보')];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE3E8F0))),
        boxShadow: [BoxShadow(color: Color(0x0F1C3A6E), blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => tab = i),
                  // 고른 칸 (대표님 11-24 「이전 방식이 더 좋음」): 원래 색 아이콘 + 옅은 파랑 바탕 + 파랑 글자 + 위 파랑 줄
                  child: Stack(children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: tab == i ? 36 : 0,
                          height: 3,
                          decoration: const BoxDecoration(color: kBlue, borderRadius: BorderRadius.vertical(bottom: Radius.circular(2))),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedScale(
                          scale: tab == i ? 1.06 : 0.94,
                          duration: const Duration(milliseconds: 160),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(color: tab == i ? const Color(0xFFE3EDFF) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                            child: Image.asset('assets/nav/${items[i].$1}.png', width: 27, height: 27),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(items[i].$2,
                            maxLines: 1,
                            style: TextStyle(fontSize: 11, fontWeight: tab == i ? FontWeight.w800 : FontWeight.w500, color: tab == i ? kBlue : const Color(0xFF5B6475), letterSpacing: -0.3)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}


// 첫 화면 (대표님 11-24 요기콕): 아이콘과 같은 파랑 바탕 + 웃는 집 그림, 위에 앱 이름
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF015DFD),
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Spacer(flex: 3),
            const Text('우리 단지 생활정보, 한 번에', style: TextStyle(fontSize: 15, color: Color(0xD9FFFFFF), fontWeight: FontWeight.w500, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text.rich(
              const TextSpan(children: [
                TextSpan(text: '요기', style: TextStyle(fontWeight: FontWeight.w300)),
                TextSpan(text: '콕', style: TextStyle(fontWeight: FontWeight.w800)),
              ]),
              style: const TextStyle(fontSize: 46, color: Colors.white, letterSpacing: -1.5, height: 1.1),
            ),
            const SizedBox(height: 24),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xB3FFFFFF))),
            const Spacer(flex: 2),
            // 넓은 화면(폴드)에서도 한가운데 · 높이에 맞춰 크기 제한 (대표님 11-24: 폴드7에서 왼쪽으로 쏠림)
            LayoutBuilder(builder: (ctx, box) {
              final w = [box.maxWidth * 0.78, MediaQuery.of(ctx).size.height * 0.42, 420.0].reduce((a, b) => a < b ? a : b);
              return SizedBox(width: box.maxWidth, child: Center(child: artImage('assets/art/splash_home.png', width: w, height: w, fit: BoxFit.contain)));
            }),
            const Spacer(flex: 2),
          ]),
        ),
      );
}

class _NoComplex extends StatelessWidget {
  const _NoComplex();
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(onPressed: () => pickComplex(context), child: const Text('먼저 우리 단지를 골라 주세요')),
      );
}
