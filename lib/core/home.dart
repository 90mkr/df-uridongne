// 우리 단지 홈 (본부 방만 고침): 등록된 기능들의 카드를 자리(slot) 순서대로 모아 그린다.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'complex_info.dart';
import 'home_layout.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';

// 내 정보 탭 등 홈 밖에서 「홈 편집」 열기: 홈 탭으로 넘어가 그 자리에서 편집 모드
void openHomeEditFor(BuildContext context, Complex c) => homeEditAsk.value++;

// 단지 홈을 아래로 당겨 새로고침하면 1씩 늘어난다. 기능 카드가 자료를 다시 받으려면 이 값을 들으면 된다.
final homeRefresh = ValueNotifier<int>(0);

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int gen = 0; // 새로고침마다 카드들을 새로 만든다
  bool editing = false; // 「홈 편집」: 카드들을 작은 막대로 줄여 끌어 옮기기 · 끄기 · 켜기

  @override
  void initState() {
    super.initState();
    homeEditAsk.addListener(_askEdit);
  }

  @override
  void dispose() {
    homeEditAsk.removeListener(_askEdit);
    super.dispose();
  }

  void _askEdit() {
    if (mounted) setState(() => editing = true);
  }

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

  Widget _body(BuildContext context, Complex c) => ValueListenableBuilder<int>(
        valueListenable: homeLayoutTick,
        builder: (context, _, __) => _bodyIn(context, c),
      );

  Widget _bodyIn(BuildContext context, Complex c) {
    Widget card(Feature f) => KeyedSubtree(key: ValueKey('${f.id}$gen'), child: f.homeCard(context, c) ?? const SizedBox());
    // 홈 칸들: 기본 순서 → 사용자가 「홈 편집」에서 바꾼 순서·끈 칸 적용
    final base = defaultBlocks(context, c, today: () => TodayHero(key: ValueKey('today${c.id}$gen'), c: c), card: card);
    if (editing) return _editor(context, base);
    final blocks = arrange(base);
    final kids = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      // 반쪽 카드 둘이 이어지면 나란히, 하나면 가로 한 줄 전체
      if (b.half && i + 1 < blocks.length && blocks[i + 1].half) {
        kids.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: b.build(context)),
            const SizedBox(width: 10),
            Expanded(child: blocks[i + 1].build(context)),
          ]),
        ));
        i++;
      } else {
        kids.add(KeyedSubtree(key: ValueKey('b${b.id}$gen'), child: b.build(context)));
      }
      kids.add(const SizedBox(height: 12));
    }
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
                ...kids,
                const SizedBox(height: 2),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => editing = true),
                    icon: const Icon(Icons.tune_rounded, size: 17, color: kSub),
                    label: const Text('홈 편집', style: TextStyle(color: kSub, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('정보는 공공데이터·카카오 장소 정보를 바탕으로 해요. 방문 전 전화로 한 번 확인해 주세요.', style: T.tiny),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 홈 편집: 휴대폰 「빠른 설정 편집」처럼 — 위는 보이는 카드(꾹 눌러 끌기 · ⊖ 끄기), 아래는 꺼 둔 카드(⊕ 켜기)
  Widget _editor(BuildContext context, List<HomeBlock> base) {
    final all = arrange(base, withHidden: true);
    final visible = all.where((b) => !isHidden(b.id)).toList();
    final hidden = all.where((b) => isHidden(b.id)).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 8, 12, 4),
            child: Row(children: [
              const Expanded(child: MixTitle('홈', '편집', size: 17)),
              TextButton(onPressed: resetHomeLayout, child: const Text('처음대로', style: TextStyle(color: kSub, fontSize: 13))),
              const SizedBox(width: 4),
              SizedBox(width: 72, child: Btn('완료', primary: true, h: 36, onTap: () => setState(() => editing = false))),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(kPad, 0, kPad, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('꾹 눌러 위아래로 옮기고, ⊖ 로 끄고, 아래 ⊕ 로 다시 켜요. 이 휴대폰에만 저장돼요.', style: T.tiny)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 28),
              itemCount: visible.length,
              onReorder: (a, b) {
                if (b > a) b--;
                final v = [...visible];
                v.insert(b, v.removeAt(a));
                setHomeOrder(v, hidden);
              },
              proxyDecorator: (child, _, __) => Material(color: Colors.transparent, elevation: 8, shadowColor: const Color(0x33000000), borderRadius: BorderRadius.circular(14), child: child),
              itemBuilder: (_, i) {
                final b = visible[i];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('e${b.id}'),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EditBar(
                      b: b,
                      on: true,
                      onToggle: () => hideBlock(b.id, visible, hidden),
                      handle: ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.drag_indicator_rounded, color: kSub))),
                    ),
                  ),
                );
              },
              footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 14),
                const Padding(padding: EdgeInsets.only(left: 2, bottom: 8), child: MixTitle('꺼 둔', '카드', size: 15)),
                if (hidden.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('꺼 둔 카드가 없어요', style: T.small, textAlign: TextAlign.center)),
                for (final b in hidden)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EditBar(b: b, on: false, onToggle: () => showBlock(b.id, visible, hidden)),
                  ),
                const SizedBox(height: 6),
                const Text('꺼 둔 기능도 아래 「생활 도구」 탭에는 언제나 있어요.', style: T.tiny),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// 편집 막대: ⊖/⊕ · 아이콘 · 이름 · (손잡이)
class _EditBar extends StatelessWidget {
  final HomeBlock b;
  final bool on;
  final VoidCallback onToggle;
  final Widget? handle;
  const _EditBar({required this.b, required this.on, required this.onToggle, this.handle});
  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        decoration: cardBox(),
        padding: const EdgeInsets.only(left: 4, right: 2),
        child: Row(children: [
          IconButton(
            onPressed: onToggle,
            tooltip: on ? '끄기' : '켜기',
            icon: Icon(on ? Icons.remove_circle_rounded : Icons.add_circle_rounded, color: on ? const Color(0xFFE5484D) : kBlue, size: 24),
          ),
          Opacity(opacity: on ? 1 : 0.55, child: LineIcon(b.icon, size: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: on ? kInk : kSub)),
          ),
          if (handle != null) handle! else const SizedBox(width: 12),
        ]),
      );
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
            onTap: () => openComplexInfo(context),
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
                const Icon(Icons.chevron_right_rounded, size: 20),
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

// ---------------- 지금 우리 단지 (맨 위 상황 맞춤 카드) ----------------
class TodayHero extends StatefulWidget {
  final Complex c;
  const TodayHero({super.key, required this.c});
  @override
  State<TodayHero> createState() => _TodayHeroState();
}

class _TodayHeroState extends State<TodayHero> {
  List<(Feature, Brief)> items = [];
  bool loading = true;
  int page = 0;
  Timer? auto;

  @override
  void initState() {
    super.initState();
    _load();
    auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || items.length < 2) return;
      setState(() => page = (page + 1) % items.length); // 서서히 바뀜 (페이드)
    });
  }

  @override
  void dispose() {
    auto?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final got = await Future.wait([
      for (final f in features.where((f) => f.ready))
        f.brief(widget.c, now).timeout(const Duration(seconds: 8), onTimeout: () => null).catchError((_) => null).then((b) => b == null ? null : (f, b)),
    ]);
    final list = got.whereType<(Feature, Brief)>().toList()..sort((a, b) => b.$2.score.compareTo(a.$2.score));
    if (!mounted) return;
    setState(() {
      items = list.take(5).toList();
      loading = false;
    });
  }

  Widget _slide(int i) {
    final (f, b) = items[i];
    return GestureDetector(
      key: ValueKey('slide$i${b.kicker}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openFeature(context, f),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: LineIcon(b.icon, size: 20),
            ),
            const SizedBox(width: 7),
            Flexible(child: Text(b.kicker, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w600))),
            const SizedBox(width: 60), // 오른쪽 위 점 자리
          ]),
          const Spacer(),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: b.bold),
              if (b.hot.isNotEmpty) TextSpan(text: b.hot, style: const TextStyle(color: Color(0xFFFFD84D))),
              TextSpan(text: b.rest),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.7, height: 1.25, shadows: [Shadow(color: Color(0x33000000), blurRadius: 6)]),
          ),
          const SizedBox(height: 4),
          Text(b.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xE6FFFFFF))),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greet = h < 6 ? '늦은 밤이에요' : h < 11 ? '좋은 아침이에요' : h < 17 ? '좋은 오후예요' : '편안한 저녁이에요';
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1570EA), Color(0xFF0B4DBA)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF0B4DBA).withValues(alpha: 0.18), blurRadius: 18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 236,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0x8C000000), Color(0xE6000000)], stops: [0, 0.5, 1]).createShader(r),
            child: Image.asset('assets/art/hero.png', fit: BoxFit.cover, alignment: Alignment.centerRight, filterQuality: FilterQuality.medium),
          ),
        ),
        if (loading || items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('지금 우리 단지 · $greet', style: const TextStyle(fontSize: 12, color: Color(0xD9FFFFFF))),
              const SizedBox(height: 6),
              Text(loading ? '오늘 소식을 모으고 있어요' : '오늘도 좋은 하루 보내세요',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6)),
            ]),
          )
        else
          GestureDetector(
            // 손으로 옆으로 밀어도 넘어감
            onHorizontalDragEnd: (d) {
              if (items.length < 2) return;
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 100) return;
              setState(() => page = (page + (v < 0 ? 1 : -1) + items.length) % items.length);
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (cur, prev) => Stack(children: [...prev, if (cur != null) cur]),
              child: _slide(page.clamp(0, items.length - 1)),
            ),
          ),
        if (items.length > 1)
          Positioned(
            right: 16,
            top: 20,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 5),
                  width: i == page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == page ? 1 : 0.45), borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
      ]),
    );
  }
}

const _short = {'trash': '분리수거', 'lotto': '로또', 'weather': '날씨', 'bus': '버스', 'pharmacy': '약국', 'phonebook': '전화번호부', 'deals': '실거래가', 'subway': '지하철', 'school': '학교 급식'};

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
