// 「홈 화면 꾸미기」 (본부 방만 고침): 사용자가 단지 홈 카드의 순서를 바꾸고, 안 보고 싶은 카드·생활 도구를 끈다.
// 설정은 이 휴대폰에만 저장 (prefs: home.order · home.hide · home.hideTools)
import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'data.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';

/// 바뀌면 홈이 다시 그려진다
final homeLayoutTick = ValueNotifier<int>(0);

List<String> _order = [];
Set<String> _hide = {};
Set<String> _on = {}; // 처음엔 꺼져 있는 한 줄 카드(r:) 중 사용자가 켠 것
bool _loaded = false;

Future<void> loadHomeLayout() async {
  if (_loaded) return;
  _loaded = true;
  try {
    final o = await prefGet('home.order');
    if (o != null && o.isNotEmpty) _order = List<String>.from(jsonDecode(o));
    final h = await prefGet('home.hide');
    if (h != null && h.isNotEmpty) _hide = Set<String>.from(jsonDecode(h));
    final t = await prefGet('home.on');
    if (t != null && t.isNotEmpty) _on = Set<String>.from(jsonDecode(t));
  } catch (_) {}
  homeLayoutTick.value++;
}

Future<void> _save() async {
  await prefSet('home.order', jsonEncode(_order));
  await prefSet('home.hide', jsonEncode(_hide.toList()));
  await prefSet('home.on', jsonEncode(_on.toList()));
  homeLayoutTick.value++;
}

// 한 줄 카드(r:)는 처음엔 꺼 둔다 — 홈이 너무 길어지지 않게. 꾸미기에서 켜면 보인다
bool isHidden(String id) => _hide.contains(id) || (id.startsWith('r:') && !_on.contains(id));

void _setOn(String id, bool v) {
  if (v) {
    _hide.remove(id);
    _on.add(id);
  } else {
    _hide.add(id);
    _on.remove(id);
  }
}

// 「내 차 어디 댔지」 같은 한 줄 카드가 따로 없는 기능의 한 줄 카드 제목·설명
const _rowTitles = {
  'weather': ('오늘', '날씨', '기온·미세먼지 한눈에'),
  'trash': ('오늘', '배출', '오늘 내놓을 쓰레기·분리수거'),
  'lotto': ('로또', '당첨 번호', '이번 회차 번호와 내 번호 맞춰 보기'),
  'postcode': ('택배', '우편번호', '우리 단지 우편번호·택배 조회'),
};

class _RowCard extends StatelessWidget {
  final Feature f;
  final Complex c;
  const _RowCard({required this.f, required this.c});
  @override
  Widget build(BuildContext context) {
    final t = _rowTitles[f.id];
    return FutureBuilder<Brief?>(
      future: f.brief(c, DateTime.now()),
      builder: (_, snap) {
        final b = snap.data;
        final sub = b == null ? (t?.$3 ?? '') : [b.bold, b.hot, b.rest].where((x) => x.isNotEmpty).join(' ').trim();
        return MainRowCard(
          icon: f.icon,
          bold: t?.$1 ?? f.name,
          thin: t?.$2 ?? '',
          sub: sub.isEmpty ? (t?.$3 ?? '') : sub,
          subLines: 1,
          trailing: const Icon(Icons.chevron_right_rounded, color: kSub),
          onTap: () => openFeature(context, f),
        );
      },
    );
  }
}

// 본문 큰 카드 이름 (mainCard 는 기능 이름과 다르게 부름)
const _mainNames = {'parking': '내 차 어디 댔지', 'charger': '충전소 찾기', 'gas': '제일 싼 주유소', 'anniv': '다가오는 기념일'};

/// 홈 한 칸
class HomeBlock {
  final String id; // today · f:<기능> · m:<기능> · tools
  final String name, icon;
  final bool half;
  final Widget Function(BuildContext context) build;
  const HomeBlock(this.id, this.name, this.icon, this.build, {this.half = false});
}

/// 기본 순서의 홈 칸들 (만들 수 있는 것만)
List<HomeBlock> defaultBlocks(BuildContext context, Complex c, {required Widget Function() today, required Widget Function() tools, required Widget Function(Feature f) card}) {
  List<Feature> at(Slot s) => features.where((f) => f.slot == s).toList()..sort((a, b) => a.order.compareTo(b.order));
  final out = <HomeBlock>[];
  for (final f in at(Slot.hero)) {
    out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f)));
  }
  if (at(Slot.hero).isEmpty) out.add(HomeBlock('today', '지금 우리 단지', 'weather', (_) => today()));
  for (final f in at(Slot.half)) {
    out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f), half: true));
  }
  for (final s in [Slot.section, Slot.wide]) {
    for (final f in at(s)) {
      out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f)));
    }
  }
  for (final f in [...features]..sort((a, b) => a.mainOrder.compareTo(b.mainOrder))) {
    final w = f.mainCard(context, c);
    if (w != null) out.add(HomeBlock('m:${f.id}', _mainNames[f.id] ?? f.name, f.icon, (_) => w));
  }
  // 한 줄 카드가 따로 없는 기능도 같은 모양 한 줄 카드로 (처음엔 꺼 둠)
  for (final f in features) {
    if (!f.ready || !_rowTitles.containsKey(f.id) || f.mainCard(context, c) != null) continue;
    final t = _rowTitles[f.id]!;
    out.add(HomeBlock('r:${f.id}', '${t.$1} ${t.$2}', f.icon, (_) => _RowCard(f: f, c: c)));
  }
  for (final f in at(Slot.tail)) {
    out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f)));
  }
  out.add(HomeBlock('tools', '생활 도구 띠', 'grid', (_) => tools()));
  return out;
}

/// 사용자 순서 적용 (새로 생긴 칸은 기본 자리 근처에 끼움). hidden 포함 여부 선택
List<HomeBlock> arrange(List<HomeBlock> base, {bool withHidden = false}) {
  if (_order.isEmpty) return withHidden ? base : base.where((b) => !isHidden(b.id)).toList();
  final byId = {for (final b in base) b.id: b};
  final out = <HomeBlock>[];
  for (final id in _order) {
    final b = byId.remove(id);
    if (b != null) out.add(b);
  }
  // 새 칸: 기본 순서에서 바로 앞 칸 뒤에
  for (var i = 0; i < base.length; i++) {
    final b = base[i];
    if (!byId.containsKey(b.id)) continue;
    final prev = i == 0 ? null : base[i - 1].id;
    final at = prev == null ? 0 : out.indexWhere((x) => x.id == prev) + 1;
    out.insert(at.clamp(0, out.length), b);
    byId.remove(b.id);
  }
  return withHidden ? out : out.where((b) => !isHidden(b.id)).toList();
}

void openHomeEdit(BuildContext context, List<HomeBlock> base) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => _HomeEditPage(base: base)));
}

class _HomeEditPage extends StatefulWidget {
  final List<HomeBlock> base;
  const _HomeEditPage({required this.base});
  @override
  State<_HomeEditPage> createState() => _HomeEditPageState();
}

class _HomeEditPageState extends State<_HomeEditPage> {
  late List<HomeBlock> list = arrange(widget.base, withHidden: true);

  void _changed() {
    _order = [for (final b in list) b.id];
    _save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('홈 화면 꾸미기', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          TextButton(
            onPressed: () {
              _order = [];
              _hide = {};
              _on = {};
              _save();
              setState(() => list = arrange(widget.base, withHidden: true));
            },
            child: const Text('처음대로', style: TextStyle(color: kSub, fontSize: 13.5)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(kPad, 4, kPad, 10),
                child: Text('오른쪽 손잡이를 끌어 순서를 바꾸고, 보실 카드만 켜 두세요. 꺼도 아래 「생활 도구」에는 그대로 있어요. 이 휴대폰에만 저장돼요.', style: T.small),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: kPad),
              sliver: SliverReorderableList(
                itemCount: list.length,
                onReorder: (a, b) {
                  if (b > a) b--;
                  final x = list.removeAt(a);
                  list.insert(b, x);
                  _changed();
                },
                proxyDecorator: (child, _, __) => Material(color: Colors.transparent, elevation: 6, borderRadius: BorderRadius.circular(12), child: child),
                itemBuilder: (_, i) {
                  final b = list[i];
                  final on = !isHidden(b.id);
                  return Padding(
                    key: ValueKey(b.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 58,
                      decoration: cardBox(),
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Row(children: [
                        Opacity(opacity: on ? 1 : 0.35, child: LineIcon(b.icon, size: 28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(b.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: on ? kInk : kSub)),
                        ),
                        Switch(
                          value: on,
                          activeTrackColor: kBlue,
                          onChanged: (v) {
                            _setOn(b.id, v);
                            _changed();
                          },
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.drag_indicator_rounded, color: kSub)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ]),
        ),
      ),
    );
  }
}
