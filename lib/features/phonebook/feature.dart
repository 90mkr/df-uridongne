// 동네 전화번호부 (이 폴더는 전화번호부 담당 방만 고침)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'list_page.dart';
import 'shop_sheet.dart';

class PhonebookFeature extends Feature {
  @override
  String get id => 'phonebook';
  @override
  String get name => '전화번호부';
  @override
  String get icon => 'book';
  @override
  Slot get slot => Slot.section;
  @override
  int get order => 10;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HomeCard(c: c);

  @override
  Widget page(BuildContext context, Complex c) => PhonebookPage(complex: c);

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final all = await shopsOf(c.areaId);
    final near = [...all]..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    return [
      for (final s in near.take(300)) MapPoint(id: s.id, name: s.name, sub: s.sub, pos: s.pos, icon: s.cats.isEmpty ? '' : s.cats.first, onTap: (ctx) => showShop(ctx, s, c)),
    ];
  }

  // 지도 탭 둘째 줄: 업종
  @override
  List<MapFilter> mapFilters() => [for (final k in kCats) MapFilter(k.id, k.name, k.id)];

  @override
  Future<List<MapPoint>> mapPointsFor(Complex c, String filter) async {
    final all = await shopsOf(c.areaId);
    final list = shopsInCat(all, filter)..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    return [
      for (final s in list.take(300))
        MapPoint(id: s.id, name: s.name, sub: '${s.sub.isEmpty ? catOf(filter).name : s.sub} · ${distText(meters(c.pos, s.pos))}', pos: s.pos, icon: filter, onTap: (ctx) => showShop(ctx, s, c)),
    ];
  }
}

// 단지 홈 카드: 「동네 전화번호부」 업종 8칸
class _HomeCard extends StatefulWidget {
  final Complex c;
  const _HomeCard({required this.c});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool more = false; // 아래 화살표로 나머지 업종 펼치기
  Complex get c => widget.c;

  void _open(BuildContext context, Cat? cat) async {
    final all = await shopsOf(c.areaId);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopListPage(complex: c, all: all, cat: cat)));
  }

  @override
  Widget build(BuildContext context) {
    Widget cell(Cat cat) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context, cat),
          child: SizedBox(
            height: 84,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              LineIcon(cat.id, size: 38),
              const SizedBox(height: 7),
              Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            ]),
          ),
        );
    Widget row(Iterable<Cat> cs, {int fill = 4}) {
      final l = cs.toList();
      return Row(children: [
        for (var i = 0; i < fill; i++) ...[
          if (i > 0) Container(width: 1, height: 44, color: i < l.length ? const Color(0xFFEDF0F5) : Colors.transparent),
          Expanded(child: i < l.length ? cell(l[i]) : const SizedBox()),
        ],
      ]);
    }
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => openFeature(context, PhonebookFeature()),
          child: const Row(children: [
            LineIcon('book', size: 24),
            SizedBox(width: 7),
            Text('동네 전화번호부', style: T.title),
            Spacer(),
            Text('단지에서 가까운 순', style: TextStyle(fontSize: 11.5, color: kSub)),
            Icon(Icons.chevron_right_rounded, size: 18, color: kMute),
          ]),
        ),
        const SizedBox(height: 6),
        row(kCats.take(4)),
        const Divider(height: 1, color: Color(0xFFEDF0F5)),
        row(kCats.skip(4).take(4)),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !more
              ? const SizedBox(width: double.infinity)
              : Column(children: [
                  for (var i = 8; i < kCats.length; i += 4) ...[
                    const Divider(height: 1, color: Color(0xFFEDF0F5)),
                    row([...kCats.skip(i).take(4), for (var k = kCats.skip(i).take(4).length; k < 4; k++) null].whereType<Cat>(), fill: 4),
                  ],
                ]),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => more = !more),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(more ? '접기' : '업종 ${kCats.length - 8}개 더 보기', style: const TextStyle(fontSize: 11.5, color: kSub, fontWeight: FontWeight.w600)),
              AnimatedRotation(
                turns: more ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: kSub),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// 전화번호부 탭 · 상세 화면: 찾기 + 모든 업종 + 콕플 맛집
class PhonebookPage extends StatefulWidget {
  final Complex complex;
  const PhonebookPage({super.key, required this.complex});
  @override
  State<PhonebookPage> createState() => _PhonebookPageState();
}

class _PhonebookPageState extends State<PhonebookPage> {
  List<Shop> all = [];
  bool loading = true;
  String? loadedFor;

  Future<void> _load() async {
    final c = widget.complex;
    loadedFor = c.id;
    setState(() => loading = true);
    final list = await shopsOf(c.areaId);
    if (!mounted || loadedFor != c.id) return;
    setState(() {
      all = list;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loadedFor != widget.complex.id) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    final c = widget.complex;
    int count(String id) => all.where((s) => s.cats.contains(id)).length;
    final tops = kokTops(c.areaId);
    void go(Cat? cat) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopListPage(complex: c, all: all, cat: cat)));
    return DetailPage(
      title: '동네 전화번호부',
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => go(null),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine), color: kBg),
            child: const Row(children: [
              LineIcon('search', size: 18, line: kMute),
              SizedBox(width: 9),
              Text('세탁소, 떡집, 가게 이름으로 찾기', style: TextStyle(fontSize: 13.5, color: kMute)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          const MixTitle('업종', '별로 보기'),
          const SizedBox(width: 7),
          Text(loading ? '' : '${all.length}곳', style: T.tiny),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 520 ? 6 : 4;
          final w = box.maxWidth / cols;
          return Wrap(children: [
            for (final cat in kCats)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: loading ? null : () => go(cat),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(children: [
                      LineIcon(cat.id, size: 34),
                      const SizedBox(height: 6),
                      Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(loading ? ' ' : '${count(cat.id)}', style: const TextStyle(fontSize: 10.5, color: kMute)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
        if (tops.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Row(children: [MixTitle('콕플이 고른', '동네 맛집'), SizedBox(width: 7), Text('구글 별점·유튜버 방문 기준', style: T.tiny)]),
          const SizedBox(height: 10),
          // 유튜브 영상 사진이 크게 보이는 카드 (대표님 11-24)
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: math.min(tops.length, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final s = tops[i];
                final k = s.kok!;
                return GestureDetector(
                  onTap: () => showShop(context, s, c),
                  child: Container(
                    width: 184,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: kLine), boxShadow: kShadow),
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        height: 104,
                        width: 184,
                        child: Stack(fit: StackFit.expand, children: [
                          if (k.thumb.isNotEmpty)
                            Image.network(k.thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F6FB), alignment: Alignment.center, child: LineIcon(s.cats.first, size: 40)))
                          else
                            Container(color: const Color(0xFFF3F6FB), alignment: Alignment.center, child: LineIcon(s.cats.isEmpty ? 'food' : s.cats.first, size: 40)),
                          // 아래 어둡게 + 채널 이름
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x8C000000)], stops: [0.55, 1]),
                            ),
                          ),
                          if (k.yt > 0)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
                                decoration: BoxDecoration(color: const Color(0xFFFF0033), borderRadius: BorderRadius.circular(6)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.play_arrow_rounded, size: 13, color: Colors.white),
                                  Text('유튜버 ${k.yt}명', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                                ]),
                              ),
                            ),
                          if (k.ch.isNotEmpty)
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 6,
                              child: Text(k.ch, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(11, 9, 10, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          const SizedBox(height: 1),
                          Text(s.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB020)),
                            Text(k.grate > 0 ? k.grate.toStringAsFixed(1) : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            if (k.greviews > 0) Text(' (${k.greviews})', style: T.tiny),
                            const Spacer(),
                            Text(distText(meters(c.pos, s.pos)), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 22),
        Btn('우리 가게 등록하기 (무료)', icon: 'owner', onTap: () => openOwnerForm(context, c)),
        const SizedBox(height: 14),
        Text('업체 정보는 카카오 장소 정보를 바탕으로 모았어요${updatedOf(c.areaId).isEmpty ? '' : ' · ${updatedOf(c.areaId)} 기준'}', style: T.tiny),
      ]),
    );
  }
}
