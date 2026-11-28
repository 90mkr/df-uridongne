// 우리 단지 홈 (본부 방만 고침): 등록된 기능들의 카드를 자리(slot) 순서대로 모아 그린다.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../features/registry.dart';
import '../features/board/noti.dart';
import 'complex_info.dart';
import 'home_layout.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'banners.dart';
import 'theme.dart';
import 'here.dart';
import 'ui.dart';
import 'remote.dart';

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
        // 「우리 집 | 지금 여기」가 바뀌거나 많이 움직이면 카드들을 그 기준으로 다시 (대표님 11-28)
        builder: (context, _, __) => ValueListenableBuilder<int>(valueListenable: baseTick, builder: (context, _, __) => _bodyIn(context, c)),
      );

  Widget _bodyIn(BuildContext context, Complex c) {
    Widget card(Feature f) {
      final fc = baseFor(c, f.id);
      return KeyedSubtree(key: ValueKey('${f.id}${fc.id}$gen'), child: f.homeCard(context, fc) ?? const SizedBox());
    }
    final tc = baseFor(c, 'weather');
    // 홈 칸들: 기본 순서 → 사용자가 「홈 편집」에서 바꾼 순서·끈 칸 적용
    final base = defaultBlocks(context, c, today: () => TodayHero(key: ValueKey('today${tc.id}$gen'), c: tc), card: card);
    if (editing) return _editor(context, base);
    final all = arrange(base);
    // 11-26 홈 두 단계: 위 큰 카드(크게 보기) · 아래 아이콘 한 줄
    final blocks = all.where((b) => isBig(b.id)).toList();
    final seen = <String>{};
    final icons = [for (final b in all) if (!isBig(b.id) && seen.add(b.fid) && featureById(b.fid) != null) b];
    Widget hold(HomeBlock b, Widget child) => GestureDetector(onLongPress: () => _sizeMenu(context, b, big: true), child: child);
    final kids = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      // 반쪽 카드 둘이 이어지면 나란히, 하나면 가로 한 줄 전체
      if (b.half && i + 1 < blocks.length && blocks[i + 1].half) {
        final b2 = blocks[i + 1];
        kids.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: hold(b, b.build(context))),
            const SizedBox(width: 10),
            Expanded(child: hold(b2, b2.build(context))),
          ]),
        ));
        i++;
      } else {
        kids.add(hold(b, KeyedSubtree(key: ValueKey('b${b.id}$gen'), child: b.build(context))));
      }
      kids.add(const SizedBox(height: 12));
    }
    if (icons.isNotEmpty) {
      kids.add(const SizedBox(height: 6));
      kids.add(_IconRow(items: icons, onHold: (b) => _sizeMenu(context, b, big: false)));
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
                const SizedBox(height: 14),
                const HomeBanners(), // 맨 아래 배너 (디자인필 · 콕플)
                const SizedBox(height: 42), // 홈 편집 단추와 넉넉히 (대표님 11-24: 3배)
                Center(
                  // 홈 편집: 또렷한 흰 단추 (대표님 11-24 — 글자만 있으니 약함)
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() => editing = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFCAD7EE)),
                          boxShadow: kShadow,
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.dashboard_customize_outlined, size: 19, color: kBlue),
                          SizedBox(width: 7),
                          Text('홈 편집', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(width: 6),
                          Text('카드 순서·켜고 끄기', style: TextStyle(color: kSub, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('정보는 공공데이터·카카오 장소 정보를 바탕으로 해요. 방문 전 전화로 한 번 확인해 주세요.', style: T.tiny),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 첫 화면에서 꾹 누르기 → 크게 보기로 올리기 / 아이콘으로 내리기 (11-26)
  Future<void> _sizeMenu(BuildContext context, HomeBlock b, {required bool big}) async {
    final f = featureById(b.fid);
    final name = big ? b.name : (kHomeShort[b.fid] ?? f?.name ?? b.name);
    final up = !big && canBeBig(b.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              LineIcon(b.icon, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            ]),
            const SizedBox(height: 14),
            if (big)
              _MenuRow(icon: Icons.south_rounded, text: '아이콘으로 내리기', sub: '아래 아이콘 줄로 — 홈이 짧아져요', onTap: () {
                Navigator.pop(ctx);
                setHomeSize(b.id, false);
              })
            else if (up)
              _MenuRow(icon: Icons.north_rounded, text: '크게 보기로 올리기', sub: '위 큰 카드로 — 정보가 바로 보여요', onTap: () {
                Navigator.pop(ctx);
                setHomeSize(b.id, true);
              })
            else
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('이 기능은 큰 카드가 없어 아이콘으로만 보여요', style: T.small)),
            _MenuRow(icon: Icons.visibility_off_outlined, text: '홈에서 빼기', sub: '생활 도구 탭에는 그대로 있어요', onTap: () {
              Navigator.pop(ctx);
              final every = arrange(defaultBlocks(context, complex.value!, today: () => const SizedBox(), card: (_) => const SizedBox()), withHidden: true);
              hideBlock(b.id, every.where((x) => !isHidden(x.id)).toList(), every.where((x) => isHidden(x.id)).toList());
            }),
            _MenuRow(icon: Icons.dashboard_customize_outlined, text: '홈 편집 열기', sub: '순서 바꾸기·켜고 끄기', onTap: () {
              Navigator.pop(ctx);
              setState(() => editing = true);
            }),
          ]),
        ),
      ),
    );
  }

  // 홈 편집 (11-26 두 묶음): 「크게 보기」 / 「아이콘으로」 — 화살표 한 번으로 묶음 사이 이동, 꾹 눌러 묶음 안 순서, ⊖ 끄기 · 아래 ⊕ 켜기
  Widget _editor(BuildContext context, List<HomeBlock> base) {
    final all = arrange(base, withHidden: true);
    final visible = all.where((b) => !isHidden(b.id)).toList();
    final hidden = all.where((b) => isHidden(b.id)).toList();
    final big = visible.where((b) => isBig(b.id)).toList();
    final small = visible.where((b) => !isBig(b.id)).toList();
    void save(List<HomeBlock> bg, List<HomeBlock> sm) => setHomeOrder([...bg, ...sm], hidden);
    Widget group(List<HomeBlock> list, bool isBigGroup) => ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: list.length,
          onReorder: (a, b) {
            if (b > a) b--;
            final v = [...list];
            v.insert(b, v.removeAt(a));
            isBigGroup ? save(v, small) : save(big, v);
          },
          proxyDecorator: (child, _, __) => Material(color: Colors.transparent, elevation: 8, shadowColor: const Color(0x33000000), borderRadius: BorderRadius.circular(14), child: child),
          itemBuilder: (_, i) {
            final b = list[i];
            final canMove = isBigGroup || canBeBig(b.id);
            return ReorderableDelayedDragStartListener(
              key: ValueKey('e${b.id}'),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EditBar(
                  b: b,
                  on: true,
                  label: isBigGroup ? null : kHomeShort[b.fid],
                  onToggle: () => hideBlock(b.id, visible, hidden),
                  move: canMove
                      ? IconButton(
                          tooltip: isBigGroup ? '아이콘으로' : '크게 보기로',
                          onPressed: () => setHomeSize(b.id, !isBigGroup),
                          icon: Icon(isBigGroup ? Icons.south_rounded : Icons.north_rounded, color: kBlue, size: 22),
                        )
                      : null,
                  handle: ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.drag_indicator_rounded, color: kSub))),
                ),
              ),
            );
          },
        );
    Widget head(String a, String b, String sub) => Padding(
          padding: const EdgeInsets.only(left: 2, top: 6, bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            MixTitle(a, b, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(sub, style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        );
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
            padding: EdgeInsets.fromLTRB(kPad, 0, kPad, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text('↑↓ 로 크게 보기·아이콘 사이를 옮기고, 꾹 눌러 순서를 바꿔요. 이 휴대폰에만 저장돼요.', style: T.tiny)),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 28), children: [
              head('크게', '보기', '위에 큰 카드로 — 오늘 바뀌는 정보'),
              if (big.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('큰 카드가 없어요', style: T.small, textAlign: TextAlign.center)),
              group(big, true),
              const SizedBox(height: 10),
              head('아이콘', '으로', '아래 한 줄 — 눌러서 바로 열기'),
              if (small.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('아이콘이 없어요', style: T.small, textAlign: TextAlign.center)),
              group(small, false),
              const SizedBox(height: 14),
              head('꺼 둔', '칸', ''),
              if (hidden.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('꺼 둔 칸이 없어요', style: T.small, textAlign: TextAlign.center)),
              for (final b in hidden)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EditBar(b: b, on: false, onToggle: () => showBlock(b.id, visible, hidden)),
                ),
              const SizedBox(height: 6),
              const Text('꺼 둔 기능도 아래 「생활 도구」 탭에는 언제나 있어요.', style: T.tiny),
            ]),
          ),
        ]),
      ),
    );
  }
}

// 꾹 누르기 메뉴 한 줄
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text, sub;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.text, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(children: [
            Icon(icon, size: 22, color: kBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                Text(sub, style: T.tiny),
              ]),
            ),
          ]),
        ),
      );
}

// 아이콘 한 줄 (11-26): 3D 아이콘 + 짧은 이름, 가로로 넘김. 휴대폰에선 4개 반이 보여 마지막이 잘려 보임 → 옆에 더 있다는 신호
class _IconRow extends StatelessWidget {
  final List<HomeBlock> items;
  final void Function(HomeBlock b) onHold;
  const _IconRow({required this.items, required this.onHold});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth / 4.5).clamp(64.0, 96.0);
      return Container(
        decoration: cardBox(r: 20),
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 10),
            child: MixTitle('생활', '바로가기', size: 15),
          ),
          SizedBox(
            height: w * 0.62 + 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                for (final b in items)
                  _IconTile(
                    w: w,
                    icon: b.icon,
                    label: kHomeShort[b.fid] ?? featureById(b.fid)?.name ?? b.name,
                    onTap: () {
                      final f = featureById(b.fid);
                      if (f != null) openFeature(context, f);
                    },
                    onHold: () => onHold(b),
                  ),
                _IconTile(w: w, icon: '', label: '전체 보기', onTap: () => homeToolsAsk.value++, onHold: null),
              ],
            ),
          ),
        ]),
      );
    });
  }
}

class _IconTile extends StatelessWidget {
  final double w;
  final String icon, label;
  final VoidCallback onTap;
  final VoidCallback? onHold;
  const _IconTile({required this.w, required this.icon, required this.label, required this.onTap, required this.onHold});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onHold,
        child: SizedBox(
          width: w,
          child: Column(children: [
            SizedBox(
              height: w * 0.62,
              child: Center(
                child: icon.isEmpty
                    ? Container(
                        width: w * 0.5,
                        height: w * 0.5,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5FE), borderRadius: BorderRadius.circular(w * 0.25)),
                        child: const Icon(Icons.grid_view_rounded, color: kBlue, size: 22),
                      )
                    : LineIcon(icon, size: w * 0.56),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: kInk)),
          ]),
        ),
      );
}

// 편집 막대: ⊖/⊕ · 아이콘 · 이름 · (손잡이)
class _EditBar extends StatelessWidget {
  final HomeBlock b;
  final bool on;
  final VoidCallback onToggle;
  final Widget? handle;
  final Widget? move; // ↑ 크게 보기로 / ↓ 아이콘으로
  final String? label;
  const _EditBar({required this.b, required this.on, required this.onToggle, this.handle, this.move, this.label});
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
            child: Text(label ?? b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: on ? kInk : kSub)),
          ),
          if (move != null) move!,
          if (handle != null) handle! else const SizedBox(width: 12),
        ]),
      );
}

class _Header extends StatelessWidget {
  final Complex? c;
  const _Header({required this.c});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(kPad, 12, 12, 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: InkWell(
            onTap: () => openComplexInfo(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<int>(
                valueListenable: baseTick,
                builder: (context, _, __) {
                  final here = c != null && useHereFor(c!);
                  final town = here ? (areaAt(myPos.value!)?.name ?? '') : '';
                  return Text(here ? '지금 ${town.isEmpty ? '현재 위치' : town} 기준으로 보는 중' : (c?.isHome == true ? '우리 집' : '우리 단지'),
                      style: here ? T.tiny.copyWith(color: kBlue, fontWeight: FontWeight.w700) : T.tiny);
                },
              ),
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
                          style: const TextStyle(fontSize: 16, letterSpacing: -0.5, height: 1.25), // 작게 해서 이름이 더 보이게 (대표님 11-28)
                        ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ]),
            ]),
          ),
        ),
        // 날씨 자리에 「우리 집 | 현재 위치」 (대표님 11-28: 날씨는 덜 중요 — 생활 도구·지금 우리 단지 카드에서 봄)
        if (c != null) Padding(padding: const EdgeInsets.only(left: 8), child: BaseSwitch(home: c!, compact: true)),
        IconButton(
          tooltip: '알림',
          // 「준비하고 있어요」 대신 알림 설정으로 바로 (대표님 11-28)
          onPressed: c == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardNotiPage(c: c!))),
          icon: const LineIcon('bell', size: 23, fill: Colors.transparent),
        ),
      ]),
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
        // 사진은 카드 전체, 파랑 필터는 글자 쪽 왼편만 좁게 (대표님 11-24)
        Positioned.fill(child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x2E06163F), BlendMode.multiply), child: artImage('assets/art/hero.jpg', fit: BoxFit.cover, alignment: const Alignment(0.6, 0), filterQuality: FilterQuality.medium))),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xF20B4DBA), Color(0xC21570EA), Color(0x330A2A6E)], stops: [0, 0.46, 0.74]),
            ),
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

const _short = {'trash': '분리수거', 'lotto': '로또', 'weather': '날씨', 'bus': '버스', 'pharmacy': '약국', 'phonebook': '전화번호부', 'deals': '실거래가', 'subway': '지하철', 'school': '학교 급식', 'roulette': '뭐 먹지'};

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
