// 화면 틀 (본부 방만 고침): 하단 메뉴 다섯 칸 — 단지 홈 · 전화번호부 · 지도 · 생활 도구 · 내 정보
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'fb.dart';
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
  }

  Future<void> _boot() async {
    fbReady();
    await Future.wait([loadAreas(), loadSavedComplex()]);
    myLocation(ask: false);
    if (!mounted) return;
    setState(() => booting = false);
    if (complex.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pickComplex(context, first: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (booting) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(strokeWidth: 1.6, color: kBlue)));
    }
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

  Widget _nav() {
    const items = [('home', '단지 홈'), ('book', '전화번호부'), ('map', '지도'), ('grid', '생활 도구'), ('me', '내 정보')];
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFECEDF1)))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => tab = i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    LineIcon(items[i].$1, size: 23, line: tab == i ? kBlue : kSub, fill: tab == i ? kSoft : Colors.transparent),
                    const SizedBox(height: 3),
                    Text(items[i].$2,
                        style: TextStyle(fontSize: 10.5, fontWeight: tab == i ? FontWeight.w700 : FontWeight.w400, color: tab == i ? kBlue : kSub)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NoComplex extends StatelessWidget {
  const _NoComplex();
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(onPressed: () => pickComplex(context), child: const Text('먼저 우리 단지를 골라 주세요')),
      );
}
