// 화면 틀 (본부 방만 고침): 하단 메뉴 다섯 칸 — 단지 홈 · 전화번호부 · 지도 · 생활 도구 · 내 정보
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/registry.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'fb.dart';
import 'feature.dart';
import 'home.dart';
import 'icons.dart';
import 'map_tab.dart';
import 'me.dart';
import 'theme.dart';
import 'tools_tab.dart';

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
  }

  // 다른 화면의 「지도로 보기」 → 지도 탭으로
  void _toMap() {
    if (mapAsk.value != null && mounted) setState(() => tab = 2);
  }

  Future<void> _boot() async {
    fbReady();
    await Future.wait([loadAreas(), loadSavedComplex(), Future.delayed(const Duration(milliseconds: 1400))]);
    myLocation(ask: false);
    if (!mounted) return;
    setState(() => booting = false);
    if (complex.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pickComplex(context, first: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (booting) return const _Splash();
    return ValueListenableBuilder(
      valueListenable: complex,
      builder: (context, c, _) {
        final pages = <Widget>[
          const HomeTab(),
          c == null ? const _NoComplex() : (featureById('phonebook')?.page(context, c) ?? const SizedBox()),
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
  Widget _nav() {
    const items = [('home', '단지 홈'), ('list', '전화번호부'), ('map', '지도'), ('grid', '생활 도구'), ('me', '내 정보')];
    return Container(
      color: kBg,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE6EBF3)),
            boxShadow: [BoxShadow(color: const Color(0xFF1C3A6E).withValues(alpha: 0.10), blurRadius: 18)],
          ),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => tab = i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedScale(
                      scale: tab == i ? 1.12 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: SvgPicture.string(_navSvg[items[i].$1]!, width: 27, height: 27),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: EdgeInsets.symmetric(horizontal: tab == i ? 10 : 2, vertical: 2),
                      decoration: BoxDecoration(color: tab == i ? kBlue : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Text(items[i].$2,
                          maxLines: 1,
                          style: TextStyle(fontSize: 11, fontWeight: tab == i ? FontWeight.w800 : FontWeight.w600, color: tab == i ? Colors.white : const Color(0xFF24539F), letterSpacing: -0.3)),
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

// 하단 메뉴 아이콘: 남색 선 + 색 면 (아기자기하게)
const _nv = '#24539F';
const _navSvg = {
  'home': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M10 22v19h28V22" fill="#DCEBFF" stroke="$_nv" stroke-width="2.6" stroke-linejoin="round"/><path d="M5 24L24 7l19 17" fill="none" stroke="#FF8A3D" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><path d="M5 24L24 7l19 17" fill="none" stroke="$_nv" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" opacity=".35"/><rect x="19" y="28" width="10" height="13" rx="2" fill="#4C8DF6" stroke="$_nv" stroke-width="2"/></svg>',
  'list': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="9" y="6" width="30" height="36" rx="6" fill="#DCEBFF" stroke="$_nv" stroke-width="2.6"/><circle cx="17" cy="17" r="2.2" fill="#4C8DF6"/><circle cx="17" cy="25" r="2.2" fill="#4C8DF6"/><circle cx="17" cy="33" r="2.2" fill="#4C8DF6"/><path d="M23 17h9M23 25h9M23 33h9" stroke="$_nv" stroke-width="2.6" stroke-linecap="round"/></svg>',
  'map': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M5 11l12-4 14 4 12-4v30l-12 4-14-4-12 4z" fill="#8EE0CF" stroke="$_nv" stroke-width="2.6" stroke-linejoin="round"/><path d="M17 7v30" stroke="$_nv" stroke-width="2.2"/><path d="M31 11v30" stroke="$_nv" stroke-width="2.2"/><path d="M17 7l14 4v30l-14-4z" fill="#C9F1E8"/></svg>',
  'grid': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="7" y="7" width="15" height="15" rx="4.5" fill="#DCEBFF" stroke="$_nv" stroke-width="2.6"/><rect x="26" y="7" width="15" height="15" rx="4.5" fill="#4C8DF6" stroke="$_nv" stroke-width="2.6"/><rect x="7" y="26" width="15" height="15" rx="4.5" fill="#4C8DF6" stroke="$_nv" stroke-width="2.6"/><rect x="26" y="26" width="15" height="15" rx="4.5" fill="#DCEBFF" stroke="$_nv" stroke-width="2.6"/></svg>',
  'me': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="16" r="8" fill="#DCEBFF" stroke="$_nv" stroke-width="2.6"/><path d="M9 41c1.5-8 7.5-13 15-13s13.5 5 15 13z" fill="#4C8DF6" stroke="$_nv" stroke-width="2.6" stroke-linejoin="round"/></svg>',
};

// 첫 화면 (대표님 시안 11-23): 파란 바탕 + 아래 동네 그림, 위에 앱 이름
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF013DCD),
        body: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/art/splash.jpg', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.52),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('우리 단지 생활정보, 한 번에', style: TextStyle(fontSize: 15, color: Color(0xCCFFFFFF), fontWeight: FontWeight.w500, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: '우리', style: TextStyle(fontWeight: FontWeight.w300)),
                    TextSpan(text: '동네', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  style: const TextStyle(fontSize: 44, color: Colors.white, letterSpacing: -1.5, height: 1.1),
                ),
                const SizedBox(height: 26),
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xB3FFFFFF))),
              ]),
            ),
          ),
        ]),
      );
}

class _NoComplex extends StatelessWidget {
  const _NoComplex();
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(onPressed: () => pickComplex(context), child: const Text('먼저 우리 단지를 골라 주세요')),
      );
}
