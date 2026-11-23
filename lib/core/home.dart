// 우리 단지 홈 (본부 방만 고침): 등록된 기능들의 카드를 자리(slot) 순서대로 모아 그린다.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';

// 단지 홈을 아래로 당겨 새로고침하면 1씩 늘어난다. 기능 카드가 자료를 다시 받으려면 이 값을 들으면 된다.
final homeRefresh = ValueNotifier<int>(0);

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int gen = 0; // 새로고침마다 카드들을 새로 만든다

  Future<void> _refresh() async {
    setState(() => gen++);
    homeRefresh.value++;
    await Future.delayed(const Duration(milliseconds: 700));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: complex,
      builder: (context, c, _) => Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(children: [
            _Header(c: c),
            Expanded(child: c == null ? _empty(context) : _body(context, c)),
          ]),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LineIcon('apt', size: 54),
            const SizedBox(height: 14),
            const MixTitle('우리 단지를', '골라 주세요', size: 18),
            const SizedBox(height: 6),
            const Text('단지를 고르면 생활정보가 한 화면에 모여요', style: T.small),
            const SizedBox(height: 18),
            SizedBox(width: 200, child: Btn('단지 고르기', primary: true, onTap: () => pickComplex(context))),
          ]),
        ),
      );

  Widget _body(BuildContext context, Complex c) {
    List<Feature> at(Slot s) => features.where((f) => f.slot == s).toList()..sort((a, b) => a.order.compareTo(b.order));
    Widget card(Feature f) => KeyedSubtree(key: ValueKey('${f.id}$gen'), child: f.homeCard(context, c) ?? const SizedBox());
    final halves = at(Slot.half);
    final tools = at(Slot.tool);
    return RefreshIndicator(
      onRefresh: _refresh,
      color: kBlue,
      backgroundColor: Colors.white,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus}),
        child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: ValueKey('home$gen'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 28),
          children: [
            for (final f in at(Slot.hero)) ...[card(f), const SizedBox(height: 12)],
            for (var i = 0; i < halves.length; i += 2) ...[
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: card(halves[i])),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < halves.length ? card(halves[i + 1]) : const SizedBox()),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            for (final f in at(Slot.section)) ...[card(f), const SizedBox(height: 12)],
            for (final f in at(Slot.wide)) ...[card(f), const SizedBox(height: 12)],
            if (tools.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(2, 8, 0, 10), child: Text('생활 도구', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3))),
              // 옆으로 넘기는 줄 (4개 반쯤 보여 더 있다는 걸 알게)
              _ToolStrip(tools: [...tools, ...features.where((f) => f.slot != Slot.tool && f.ready && _short.containsKey(f.id))]),
            ],
            const SizedBox(height: 22),
            const Text('정보는 공공데이터·카카오 장소 정보를 바탕으로 해요. 방문 전 전화로 한 번 확인해 주세요.', style: T.tiny),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Complex? c;
  const _Header({required this.c});
  @override
  Widget build(BuildContext context) {
    final head = features.where((f) => f.slot == Slot.header).toList();
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(kPad, 12, 12, 4),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: () => pickComplex(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('우리 단지', style: T.tiny),
              const SizedBox(height: 1),
              Row(children: [
                Flexible(
                  child: c == null
                      ? const Text('단지 고르기', style: T.h1)
                      : Text.rich(
                          TextSpan(children: [
                            if (c!.town.isNotEmpty) TextSpan(text: '${c!.town} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: c!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 19, letterSpacing: -0.6, height: 1.25),
                        ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ]),
            ]),
          ),
        ),
        if (c != null)
          for (final f in head)
            Padding(padding: const EdgeInsets.only(left: 8), child: f.homeCard(context, c!) ?? const SizedBox()),
        IconButton(
          tooltip: '알림',
          onPressed: () => toast(context, '알림은 준비하고 있어요'),
          icon: const LineIcon('bell', size: 23, fill: Colors.transparent),
        ),
      ]),
    );
  }
}

// 생활 도구 줄: 저절로 천천히 흘러가고(끝없이 이어짐), 손으로 만지면 잠깐 멈춘다 (대표님 11-24)
class _ToolStrip extends StatefulWidget {
  final List<Feature> tools;
  const _ToolStrip({required this.tools});
  @override
  State<_ToolStrip> createState() => _ToolStripState();
}

class _ToolStripState extends State<_ToolStrip> {
  final ctl = ScrollController();
  Timer? tick;
  DateTime pauseUntil = DateTime(0);
  double setW = 0; // 한 바퀴 길이

  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!ctl.hasClients || setW <= 0 || DateTime.now().isBefore(pauseUntil)) return;
      var o = ctl.offset + 0.6;
      if (o >= setW) o -= setW;
      ctl.jumpTo(o);
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    ctl.dispose();
    super.dispose();
  }

  void _pause() => pauseUntil = DateTime.now().add(const Duration(seconds: 4));

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, box) {
        final w = (box.maxWidth - 8 * 4) / 4.4;
        final n = widget.tools.length;
        setW = n * (w + 8);
        final loop = setW > box.maxWidth; // 넘칠 때만 흐름
        return Listener(
          onPointerDown: (_) => _pause(),
          onPointerMove: (_) => _pause(),
          child: SizedBox(
            height: 92,
            child: ListView.builder(
              controller: ctl,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: loop ? n * 3 : n,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(width: w, child: ToolTile(f: widget.tools[i % n])),
              ),
            ),
          ),
        );
      });
}

// 생활 도구 줄에 함께 넣는 다른 기능의 짧은 이름
const _short = {'trash': '분리수거', 'lotto': '로또', 'weather': '날씨', 'bus': '버스', 'pharmacy': '약국', 'phonebook': '전화번호부', 'deals': '실거래가'};

// 생활 도구 작은 칸
class ToolTile extends StatelessWidget {
  final Feature f;
  const ToolTile({super.key, required this.f});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openFeature(context, f),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine), boxShadow: kShadow),
            child: Column(children: [
              LineIcon(f.icon, size: 34),
              const SizedBox(height: 6),
              Text(_short[f.id] ?? f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            ]),
          ),
        ),
      );
}
