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
      for (final s in near.take(300)) MapPoint(id: s.id, name: s.name, sub: s.sub, pos: s.pos, onTap: (ctx) => showShop(ctx, s, c)),
    ];
  }
}

// 단지 홈 카드: 「동네 전화번호부」 업종 8칸
class _HomeCard extends StatelessWidget {
  final Complex c;
  const _HomeCard({required this.c});

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
    Widget row(Iterable<Cat> cs) => Row(children: [
          for (final (i, cat) in cs.indexed) ...[
            if (i > 0) Container(width: 1, height: 44, color: const Color(0xFFEDF0F5)),
            Expanded(child: cell(cat)),
          ],
        ]);
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: math.min(tops.length, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final s = tops[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
                  onTap: () => showShop(context, s, c),
                  child: Ink(
                    width: 160,
                    decoration: cardBox(),
                    padding: const EdgeInsets.fromLTRB(13, 11, 12, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      Text(s.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                      const Spacer(),
                      Row(children: [
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB020)),
                        Text(s.kok!.grate > 0 ? s.kok!.grate.toStringAsFixed(1) : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Text(distText(meters(c.pos, s.pos)), style: T.tiny),
                      ]),
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
