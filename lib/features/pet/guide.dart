// 반려 생활 가이드 — 반려동물 테마 방 (대표님 11-26)
// 글은 서버 자료 web/data/pet/guide.json (앱 업데이트 없이 글을 더하고 고침)
//   블록: p 문단 · check 체크 목록 · qa 묻고 답하기 · warn 병원에 가야 할 때 · tip 요령
//   reviewed: 수의사 감수를 마친 글 id → 「수의사 감수」 표시
// 우리 아이 수첩의 종·나이에 맞는 글을 먼저 보여 준다.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'kids.dart';
import 'places.dart';

class GuideItem {
  final String id, cat, kind, title, sub, src;
  final List<String> age, tags;
  final List<Map> body;
  const GuideItem(this.id, this.cat, this.kind, this.title, this.sub, this.src, this.age, this.tags, this.body);
  static GuideItem? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    List<String> l(dynamic v) => [for (final x in (v is List ? v : const [])) '$x'];
    return GuideItem('${j['id']}', '${j['cat'] ?? ''}', '${j['kind'] ?? '공통'}', '${j['title'] ?? ''}', '${j['sub'] ?? ''}', '${j['src'] ?? ''}', l(j['age']),
        l(j['tags']), [for (final b in (j['body'] as List? ?? const [])) if (b is Map) b]);
  }
}

class Guide {
  final List<(String, String, String)> cats; // (id, 이름, 아이콘)
  final List<GuideItem> items;
  final Set<String> reviewed;
  final List<String> pick;
  final String note;
  const Guide(this.cats, this.items, this.reviewed, this.pick, this.note);
  String catName(String id) => cats.where((c) => c.$1 == id).firstOrNull?.$2 ?? '';
}

Future<Guide?>? _guide;

Future<Guide?> loadGuide({bool force = false}) {
  if (force || _guide == null) {
    _guide = () async {
      final j = await getJson('${dataBase}pet/guide.json');
      if (j is! Map) return null;
      final items = [for (final x in (j['items'] as List? ?? const [])) GuideItem.fromJson(x)].whereType<GuideItem>().toList();
      if (items.isEmpty) return null;
      return Guide(
        [for (final c in (j['cats'] as List? ?? const [])) if (c is Map) ('${c['id']}', '${c['name']}', '${c['icon'] ?? 'pet'}')],
        items,
        {for (final x in (j['reviewed'] as List? ?? const [])) '$x'},
        [for (final x in (j['pick'] as List? ?? const [])) '$x'],
        '${j['note'] ?? ''}',
      );
    }();
    _guide!.then((g) {
      if (g == null) _guide = null; // 실패는 묶어 두지 않음
    });
  }
  return _guide!;
}

// 생애 단계: baby · adult · senior (강아지 7살·고양이 11살부터 노령)
String stageOf(Kid k) {
  final b = k.birth;
  if (b == null) return 'adult';
  final y = DateTime.now().difference(b).inDays / 365.25;
  if (y < 1) return 'baby';
  if (y >= (k.kind == '고양이' ? 11 : 7)) return 'senior';
  return 'adult';
}

bool _fits(GuideItem g, String kind, String stage) =>
    (g.kind == '공통' || g.kind == kind) && (g.age.contains('all') || g.age.contains(stage));

/// 우리 아이에게 맞는 글 (가장 잘 맞는 순, 많아야 n개)
List<GuideItem> picksFor(Guide g, Kid? k, {int n = 6}) {
  if (k == null) {
    return [for (final id in g.pick) ...g.items.where((x) => x.id == id)].take(n).toList();
  }
  final st = stageOf(k);
  final v = g.items.where((x) => _fits(x, k.kind, st)).toList();
  int score(GuideItem x) => (x.kind == k.kind ? 2 : 0) + (x.age.contains(st) ? 3 : 0) + (x.cat == 'emergency' ? 1 : 0);
  v.sort((a, b) => score(b).compareTo(score(a)));
  return v.take(n).toList();
}

String _stageText(Kid k) {
  final s = stageOf(k);
  final age = k.ageText;
  return [k.kind, if (age.isNotEmpty) age, if (s == 'senior') '노령', if (s == 'baby') '어린 시기'].join(' · ');
}

// ---------------- 목록 화면 ----------------

class PetGuidePage extends StatefulWidget {
  final Complex complex;
  const PetGuidePage({super.key, required this.complex});
  @override
  State<PetGuidePage> createState() => _PetGuidePageState();
}

class _PetGuidePageState extends State<PetGuidePage> {
  Guide? g;
  bool loading = true;
  String cat = 'all';
  String q = '';
  int kidIdx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    await loadKids();
    final v = await loadGuide(force: force);
    if (!mounted) return;
    setState(() {
      g = v;
      loading = false;
    });
  }

  void _open(GuideItem x) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetGuideArticle(guide: g!, item: x, complex: widget.complex)));

  @override
  Widget build(BuildContext context) {
    final gd = g;
    return DetailPage(
      title: '반려 생활 가이드',
      icon: 'book',
      white: false,
      body: loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : gd == null
              ? Padding(padding: const EdgeInsets.all(kPad), child: Text('글을 받지 못했어요. 잠시 뒤 다시 열어 주세요.', style: T.body))
              : RefreshIndicator(onRefresh: () => _load(force: true), child: _body(gd)),
    );
  }

  Widget _body(Guide gd) {
    final ks = kids.value;
    final kid = ks.isEmpty ? null : ks[kidIdx.clamp(0, ks.length - 1)];
    final picks = picksFor(gd, kid);
    final words = q.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final list = gd.items.where((x) {
      if (cat != 'all' && x.cat != cat) return false;
      if (words.isEmpty) return true;
      final hay = '${x.title} ${x.sub} ${x.tags.join(' ')}';
      return words.every(hay.contains);
    }).toList();

    return ListView(padding: const EdgeInsets.fromLTRB(0, 16, 0, 30), children: [
      // 우리 아이 맞춤
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: kPad),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: kid == null
                ? const MixTitle('먼저 읽어 볼', '글', size: 16)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MixTitle(kid.name, '에게 맞는 글', size: 16),
                    const SizedBox(height: 2),
                    Text(_stageText(kid), style: T.small),
                  ]),
          ),
          if (ks.length > 1)
            InkWell(
              onTap: () => setState(() => kidIdx = (kidIdx + 1) % ks.length),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text('다른 아이', style: TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w600))),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          itemCount: picks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _PickCard(item: picks[i], catName: gd.catName(picks[i].cat), icon: gd.cats.where((c) => c.$1 == picks[i].cat).firstOrNull?.$3 ?? 'pet', reviewed: gd.reviewed.contains(picks[i].id), onTap: () => _open(picks[i])),
        ),
      ),
      if (kid == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 8, kPad, 0),
          child: Text('「우리 아이 수첩」에 아이를 등록하면 종·나이에 맞는 글을 골라 드려요.', style: T.tiny),
        ),
      const SizedBox(height: 22),
      // 찾기
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: kPad),
        child: Container(
          height: 42,
          decoration: cardBox(r: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const LineIcon('search', size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '예: 슬개골, 양치, 초콜릿', hintStyle: TextStyle(fontSize: 13, color: kMute)),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      // 분류 (옆으로 밀기)
      SizedBox(
        height: 38,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: kPad), children: [
          for (final c in [('all', '전체', ''), ...gd.cats]) ...[
            ChoiceChipBox(c.$2, on: cat == c.$1, onTap: () => setState(() => cat = c.$1)),
            const SizedBox(width: 6),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: kPad),
        child: list.isEmpty
            ? Text('찾는 글이 없어요.', style: T.small)
            : Container(
                decoration: cardBox(),
                child: Column(children: [
                  for (var i = 0; i < list.length; i++) _Row(item: list[i], catName: cat == 'all' ? gd.catName(list[i].cat) : '', reviewed: gd.reviewed.contains(list[i].id), last: i == list.length - 1, onTap: () => _open(list[i])),
                ]),
              ),
      ),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: Text('${gd.items.length}편 · ${gd.note}', style: T.tiny)),
    ]);
  }
}

class _PickCard extends StatelessWidget {
  final GuideItem item;
  final String catName, icon;
  final bool reviewed;
  final VoidCallback onTap;
  const _PickCard({required this.item, required this.catName, required this.icon, required this.reviewed, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Ink(
            width: 196,
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(catName, style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w600))),
                LineIcon(icon, size: 28),
              ]),
              const Spacer(),
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.3)),
              const SizedBox(height: 3),
              Text(item.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ]),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final GuideItem item;
  final String catName;
  final bool reviewed, last;
  final VoidCallback onTap;
  const _Row({required this.item, required this.catName, required this.reviewed, required this.last, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: kLine))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text([if (catName.isNotEmpty) catName, if (item.kind != '공통') item.kind, item.sub].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
            if (reviewed) ...[const SizedBox(width: 6), const Pill('수의사 감수')],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: kMute),
          ]),
        ),
      );
}

// ---------------- 글 화면 ----------------

class PetGuideArticle extends StatelessWidget {
  final Guide guide;
  final GuideItem item;
  final Complex complex;
  const PetGuideArticle({super.key, required this.guide, required this.item, required this.complex});

  @override
  Widget build(BuildContext context) {
    final related = guide.items.where((x) => x.cat == item.cat && x.id != item.id).take(3).toList();
    final reviewed = guide.reviewed.contains(item.id);
    return DetailPage(
      title: guide.catName(item.cat),
      icon: 'book',
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 20, kPad, 34), children: [
        Text(item.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.3)),
        const SizedBox(height: 4),
        Text(item.sub, style: const TextStyle(fontSize: 13.5, color: kSub, fontWeight: FontWeight.w300)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(item.kind == '공통' ? '강아지·고양이' : item.kind),
          if (reviewed) const Pill('수의사 감수', color: kBlue, bg: Color(0xFFEEF3FF)),
        ]),
        const SizedBox(height: 18),
        for (final b in item.body) ...[_block(context, b), const SizedBox(height: 14)],
        const SizedBox(height: 6),
        Container(height: 1, color: kLine),
        const SizedBox(height: 12),
        if (item.src.isNotEmpty) Text(item.src, style: T.tiny),
        const SizedBox(height: 4),
        Text(guide.note, style: T.tiny),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 26),
          const MixTitle('같이 읽으면', '좋은 글', size: 14.5),
          const SizedBox(height: 8),
          Container(
            decoration: cardBox(),
            child: Column(children: [
              for (var i = 0; i < related.length; i++)
                _Row(
                    item: related[i],
                    catName: '',
                    reviewed: guide.reviewed.contains(related[i].id),
                    last: i == related.length - 1,
                    onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PetGuideArticle(guide: guide, item: related[i], complex: complex)))),
            ]),
          ),
        ],
      ]),
    );
  }

  List<String> _list(dynamic v) => [for (final x in (v is List ? v : const [])) '$x'];

  Widget _block(BuildContext context, Map b) {
    switch ('${b['t']}') {
      case 'check':
        return Container(
          decoration: cardBox(r: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(children: [
            for (final x in _list(b['x']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check, size: 16, color: kSub)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(x, style: const TextStyle(fontSize: 14, height: 1.45))),
                ]),
              ),
          ]),
        );
      case 'qa':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${b['q']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('${b['a']}', style: const TextStyle(fontSize: 14.5, height: 1.6)),
        ]);
      case 'warn':
        return Container(
          decoration: cardBox(r: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              LineIcon('hosp', size: 24),
              SizedBox(width: 8),
              Text('이럴 땐 바로 병원으로', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ]),
            const SizedBox(height: 8),
            for (final x in _list(b['x']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 4, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: kInk, shape: BoxShape.circle)))),
                  const SizedBox(width: 9),
                  Expanded(child: Text(x, style: const TextStyle(fontSize: 14, height: 1.45))),
                ]),
              ),
            const SizedBox(height: 10),
            Btn('가까운 동물병원·응급 병원 찾기', icon: 'hosp', h: 42, primary: true, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetEmergencyPage(complex: complex)))),
          ]),
        );
      case 'tip':
        return Container(
          decoration: BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('요령', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kBlue)),
            const SizedBox(width: 10),
            Expanded(child: Text('${b['x']}', style: const TextStyle(fontSize: 13.5, height: 1.5))),
          ]),
        );
      default:
        return Text('${b['x'] ?? ''}', style: const TextStyle(fontSize: 15, height: 1.65));
    }
  }
}
