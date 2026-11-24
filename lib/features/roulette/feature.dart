// 「오늘 뭐 먹지?」 룰렛 (룰렛 담당: 본부, 대표님 요청 11-24)
// 홈 카드: 오른쪽 위로 원판이 카드 밖으로 ⅓쯤 튀어나와 천천히 돎 (동작 줄이기 켠 사람은 멈춤)
// 누르면 바텀시트: 큰 원판 + 아래 「돌리기」 → 서서히 멈추며 짧은 진동 → 「오늘은 ○○ 어때요?」 + 주변 가게 3~5곳
// 가게: 동네 전화번호부 식당(콕플 맛집 정보가 붙은 곳 먼저)
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../phonebook/data.dart' as pb;
import 'wheel.dart';

class RouletteFeature extends Feature {
  @override
  String get id => 'roulette';
  @override
  String get name => '오늘 뭐 먹지?';
  @override
  String get icon => 'food';
  @override
  Slot get slot => Slot.tail;
  @override
  int get order => 30; // 맨 아래 큰 카드 중 마지막 (버스·지하철 다음)
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HomeCard(c: c);

  @override
  Widget page(BuildContext context, Complex c) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kBg, elevation: 0, title: const Text('오늘 뭐 먹지?')),
        body: SafeArea(child: _Sheet(c: c, inPage: true)),
      );
}

String _timeLine(DateTime now) {
  final h = now.hour;
  if (h >= 22 || h < 4) return '야식 땡길 때';
  if (h < 10) return '간단한 아침 뭐 먹지?';
  if (h < 15) return '점심 메뉴 고민 끝';
  return '오늘 저녁은?';
}

void openRoulette(BuildContext context, Complex c) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sc) => _Sheet(c: c, scroll: sc),
      ),
    );

// ---------------- 홈 카드 ----------------
class _HomeCard extends StatefulWidget {
  final Complex c;
  const _HomeCard({required this.c});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> with SingleTickerProviderStateMixin {
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 9));
  List<Food> foods = [for (final id in kDefaultFoods) foodById(id)];

  @override
  void initState() {
    super.initState();
    _loadFoods().then((l) {
      if (mounted) setState(() => foods = l);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 휴대폰 「동작 줄이기」를 켠 사람은 평소 회전을 멈춘다
    if (MediaQuery.of(context).disableAnimations) {
      spin.stop();
    } else if (!spin.isAnimating) {
      spin.repeat();
    }
  }

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final ws = (w * 0.34).clamp(112.0, 150.0); // 원판 크기 (작은 폰~큰 폰)
    final lift = ws * 0.34; // 카드 위로 튀어나오는 만큼
    return Padding(
      padding: EdgeInsets.only(top: lift - 4),
      child: Stack(clipBehavior: Clip.none, children: [
        Semantics(
          button: true,
          label: '오늘 뭐 먹지 룰렛 열기',
          child: SizedBox(
          width: double.infinity,
          child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius + 2),
            onTap: () => openRoulette(context, widget.c),
            child: Ink(
              height: 118,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadius + 2),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF4EC), Color(0xFFFFFFFF)]),
                border: Border.all(color: const Color(0xFFF6DFCF)),
                boxShadow: kShadow,
              ),
              padding: EdgeInsets.fromLTRB(18, 16, ws * 0.78, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_timeLine(DateTime.now()), style: const TextStyle(fontSize: 12.5, color: Color(0xFFB2603A), fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                const SizedBox(height: 3),
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '오늘 ', style: TextStyle(fontWeight: FontWeight.w300)),
                    TextSpan(text: '뭐 먹지?', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  maxLines: 1,
                  style: TextStyle(fontSize: 24, letterSpacing: -0.8, height: 1.15, color: kInk),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFF7A59), borderRadius: BorderRadius.circular(20)),
                  child: const Text('룰렛 돌리기 →', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                ),
              ]),
            ),
          ),
        ),
          ),
        ),
        // 원판: 오른쪽 위로 카드 밖 ⅓
        Positioned(
          right: -ws * 0.06,
          top: -lift,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: spin,
              builder: (_, __) => Wheel(foods: foods, size: ws, angle: spin.value * 2 * math.pi, labels: ws >= 130),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------- 칸 저장 ----------------
Future<List<Food>> _loadFoods() async {
  try {
    final s = await prefGet('roulette.foods');
    if (s != null && s.isNotEmpty) {
      final ids = List<String>.from(jsonDecode(s));
      final l = [for (final id in ids) if (kFoods.any((f) => f.id == id)) foodById(id)];
      if (l.length >= 2) return l;
    }
  } catch (_) {}
  return [for (final id in kDefaultFoods) foodById(id)];
}

Future<void> _saveFoods(List<Food> l) => prefSet('roulette.foods', jsonEncode([for (final f in l) f.id]));

bool _isFood(pb.Shop s, Food f) =>
    (s.cats.contains('food') || s.cats.contains('cafe')) && (f.subs.contains(s.sub) || f.words.any((w) => s.name.contains(w)) || (f.id == 'bread' && s.cats.contains('cafe')));

// ---------------- 바텀시트 ----------------
class _Sheet extends StatefulWidget {
  final Complex c;
  final ScrollController? scroll;
  final bool inPage;
  const _Sheet({required this.c, this.scroll, this.inPage = false});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  List<Food> chosen = [];
  List<pb.Shop> shops = [];
  double base = 0, target = 0;
  Food? result;
  bool editing = false, more = false, loading = true;

  @override
  void initState() {
    super.initState();
    ctl.addListener(() => setState(() {}));
    ctl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        final l = _usable;
        setState(() {
          base = target % (2 * math.pi);
          result = l[pointed(base, l.length)];
          more = false;
        });
      }
    });
    _init();
  }

  Future<void> _init() async {
    final l = await _loadFoods();
    final all = await pb.shopsOf(widget.c.areaId);
    final near = all.where((s) => meters(widget.c.pos, s.pos) <= 3000).toList()
      ..sort((a, b) => meters(widget.c.pos, a.pos).compareTo(meters(widget.c.pos, b.pos)));
    if (!mounted) return;
    setState(() {
      chosen = l;
      shops = near;
      loading = false;
    });
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  // 주변에 가게가 0곳인 종류는 자동으로 뺀다 (가게 자료가 아예 없으면 그대로)
  List<Food> get _usable {
    if (shops.isEmpty) return chosen;
    final l = chosen.where((f) => shops.any((s) => _isFood(s, f))).toList();
    return l.length >= 2 ? l : chosen;
  }

  List<pb.Shop> _shopsFor(Food f) {
    final l = shops.where((s) => _isFood(s, f)).toList();
    // 1km 안 콕플 맛집 먼저, 그다음 가까운 순
    double d(pb.Shop s) => meters(widget.c.pos, s.pos);
    l.sort((a, b) {
      final ka = a.kok != null && d(a) <= 1000 ? 0 : 1, kb = b.kok != null && d(b) <= 1000 ? 0 : 1;
      if (ka != kb) return ka.compareTo(kb);
      return d(a).compareTo(d(b));
    });
    return l;
  }

  void _spin() {
    if (ctl.isAnimating) return;
    final n = _usable.length;
    final pick = math.Random().nextInt(n);
    final seg = 2 * math.pi / n;
    // 바늘(위)이 pick 칸 안쪽(가운데 근처)을 가리키게: 칸 i 의 가운데 각도 = seg*i + seg/2 → 원판을 -그만큼 돌림
    final jitter = (math.Random().nextDouble() - 0.5) * seg * 0.6;
    final stop = -(seg * pick + seg / 2 + jitter);
    var t = stop;
    while (t > base - 2 * math.pi * 5) {
      t -= 2 * math.pi;
    }
    setState(() {
      result = null;
      target = t;
    });
    ctl.forward(from: 0);
  }

  double get _angle => ctl.isAnimating ? base + (target - base) * Curves.easeOutCubic.transform(ctl.value) : base;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final size = math.min(w - 60, 300.0);
    final usable = _usable;
    final found = result == null ? const <pb.Shop>[] : _shopsFor(result!);
    return ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 28), children: [
      if (!widget.inPage)
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 10),
      Row(children: [
        const Expanded(child: MixTitle('오늘', '뭐 먹지?', size: 19)),
        TextButton(
          onPressed: () => setState(() => editing = !editing),
          child: Text(editing ? '다 골랐어요' : '칸 바꾸기', style: const TextStyle(color: kSub, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
      Text(_timeLine(DateTime.now()), style: T.small),
      if (editing) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in kFoods)
            ChoiceChipBox(f.name, on: chosen.any((x) => x.id == f.id), onTap: () {
              final l = [...chosen];
              final i = l.indexWhere((x) => x.id == f.id);
              if (i >= 0) {
                if (l.length <= 2) return toast(context, '두 칸 이상은 있어야 해요');
                l.removeAt(i);
              } else {
                if (l.length >= 12) return toast(context, '열두 칸까지만 돼요');
                l.add(f);
              }
              setState(() {
                chosen = l;
                result = null;
                base = 0;
              });
              _saveFoods(l);
            }),
        ]),
        if (shops.isNotEmpty && usable.length < chosen.length)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('주변에 가게가 없는 ${chosen.length - usable.length}칸은 원판에서 빠져요', style: T.tiny)),
      ],
      const SizedBox(height: 18),
      Center(child: Wheel(foods: usable, size: size, angle: _angle)),
      const SizedBox(height: 18),
      Center(
        child: SizedBox(
          width: 200,
          child: Btn(ctl.isAnimating ? '돌아가는 중…' : (result == null ? '돌리기' : '다시 돌리기'), primary: true, h: 50, onTap: _spin),
        ),
      ),
      if (result != null) ...[
        const SizedBox(height: 22),
        Center(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '오늘은 ', style: TextStyle(fontWeight: FontWeight.w300)),
              TextSpan(text: result!.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE8613C))),
              const TextSpan(text: ' 어때요?', style: TextStyle(fontWeight: FontWeight.w300)),
            ]),
            style: const TextStyle(fontSize: 22, letterSpacing: -0.6, color: kInk),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: kBlue)))
        else if (found.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('3km 안에서 찾지 못했어요', style: T.small)))
        else
          Container(
            decoration: cardBox(),
            child: Column(children: [
              for (final (i, s) in found.take(more ? 20 : 5).indexed) ...[
                if (i > 0) const Divider(height: 1, color: kLine, indent: 14, endIndent: 14),
                _ShopRow(s: s, c: widget.c),
              ],
            ]),
          ),
        const SizedBox(height: 10),
        if (found.length > 5 && !more)
          Center(
            child: TextButton(
              onPressed: () => setState(() => more = true),
              child: Text('이 종류 가게 더 보기 (${found.length}곳)', style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    ]);
  }
}

class _ShopRow extends StatelessWidget {
  final pb.Shop s;
  final Complex c;
  const _ShopRow({required this.s, required this.c});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.3))),
                if (s.kok != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFEFE8), borderRadius: BorderRadius.circular(10)),
                    child: const Text('콕플', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFE8613C))),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${distText(meters(c.pos, s.pos))} · ${s.sub}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ]),
          ),
          if (s.tel.isNotEmpty) IconButton(tooltip: '전화', onPressed: () => callTel(s.tel), icon: const Icon(Icons.call_rounded, color: kBlue, size: 21)),
          IconButton(tooltip: '길안내', onPressed: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng), icon: const Icon(Icons.directions_rounded, color: kSub, size: 22)),
        ]),
      );
}
