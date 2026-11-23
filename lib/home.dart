part of 'main.dart';

// ---------------- 첫 화면 ----------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Area? area;
  List<Shop> shops = [];
  bool loading = true;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await store.loadAreas();
    final saved = await savedArea();
    Area? a = store.areas.where((x) => x.id == saved && x.ready).firstOrNull;
    final p = await myLocation(ask: false);
    if (p != null) a = areaAt(store.areas.where((x) => x.ready).toList(), p) ?? a;
    a ??= store.areas.where((x) => x.ready).firstOrNull ?? store.areas.firstOrNull;
    await _setArea(a);
  }

  Future<void> _setArea(Area? a) async {
    if (a == null) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      area = a;
      loading = true;
    });
    saveArea(a.id);
    final list = await store.shops(a);
    if (!mounted || area?.id != a.id) return;
    setState(() {
      shops = list;
      loading = false;
    });
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    final p = await myLocation();
    if (!mounted) return;
    setState(() => locating = false);
    if (p == null) {
      toast(context, '위치를 알 수 없어요. 휴대폰 위치 사용을 켜 주세요');
      return;
    }
    final a = areaAt(store.areas.where((x) => x.ready).toList(), p);
    if (a == null) {
      toast(context, '이 근처는 아직 자료를 모으는 중이에요');
      return;
    }
    if (a.id != area?.id) await _setArea(a);
    if (mounted) toast(context, '내 위치 가까운 순서로 보여 드려요');
  }

  void _pickArea() async {
    final a = await showModalBottomSheet<Area>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (_) => AreaSheet(current: area),
    );
    if (a != null) _setArea(a);
  }

  int countOf(String cat) => shops.where((s) => s.cats.contains(cat)).length;

  void _openCat(Cat c) {
    if (area == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopListPage(area: area!, all: shops, cat: c)));
  }

  void _openSearch() {
    if (area == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopListPage(area: area!, all: shops, search: true)));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width < 600 ? 20.0 : 32.0;
    final tops = area == null ? const <Shop>[] : store.kokTops(area!);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              color: kBlue,
              onRefresh: () async {
                if (area != null) await _setArea(area);
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 14, pad, 36),
                children: [
                  _top(),
                  const SizedBox(height: 14),
                  _searchBar(),
                  const SizedBox(height: 26),
                  _title('무엇을 찾으세요', area == null || loading ? null : '${shops.length}곳'),
                  const SizedBox(height: 12),
                  _catGrid(),
                  const SizedBox(height: 30),
                  _title('생활 도구', null),
                  const SizedBox(height: 12),
                  _tools(),
                  if (tops.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    _title('콕플이 고른 동네 맛집', '구글 별점·유튜버 방문 기준'),
                    const SizedBox(height: 12),
                    _kokStrip(tops),
                  ],
                  const SizedBox(height: 30),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _top() => Row(children: [
        const Text(kAppName, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickArea,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(area?.full ?? '동네 고르기',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kSub)),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 19, color: kSub),
                ]),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '내 위치로',
          onPressed: locating ? null : _locate,
          icon: locating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.6, color: kBlue))
              : const LineIcon('loc', size: 24),
        ),
      ]);

  Widget _searchBar() => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSearch,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine), color: kBg),
          child: const Row(children: [
            LineIcon('search', size: 19, line: kMute),
            SizedBox(width: 9),
            Text('세탁소, 떡집, 가게 이름으로 찾기', style: TextStyle(fontSize: 14, color: kMute)),
          ]),
        ),
      );

  Widget _title(String t, String? sub) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        if (sub != null) ...[
          const SizedBox(width: 7),
          Padding(padding: const EdgeInsets.only(bottom: 1), child: Text(sub, style: const TextStyle(fontSize: 12, color: kMute))),
        ],
      ]);

  Widget _catGrid() {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 6 : 4;
      final w = c.maxWidth / cols;
      return Wrap(children: [
        for (final cat in kCats)
          SizedBox(
            width: w,
            child: _CatTile(cat: cat, count: loading ? null : countOf(cat.id), onTap: () => _openCat(cat)),
          ),
      ]);
    });
  }

  Widget _tools() {
    final items = [
      ('post', '우편번호 찾기', '도로명·지번 주소로', () => openUrl('${kIsWeb ? '' : 'https://90mkr.github.io/df-uridongne/'}postcode.html', inApp: true)),
      ('night', '휴일 문 연 약국', '밤·주말에 여는 곳', () => openUrl('https://www.pharm114.or.kr/', inApp: true)),
      ('kokple', '유튜버 맛집 지도', '콕플에서 보기', () => openUrl(kKokpleWeb)),
      ('owner', '사장님이세요?', '우리 가게 직접 등록', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => OwnerForm(area: area)));
      }),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 4 : 2;
      const gap = 10.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final t in items)
          SizedBox(
            width: w,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: t.$4,
                child: Ink(
                  decoration: cardBox(),
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  child: Row(children: [
                    LineIcon(t.$1, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25)),
                        const SizedBox(height: 2),
                        Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kMute, height: 1.25)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  Widget _kokStrip(List<Shop> tops) => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: math.min(tops.length, 12),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final s = tops[i];
            final k = s.kok!;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showShop(context, s, area!),
              child: Ink(
                width: 168,
                decoration: cardBox(),
                padding: const EdgeInsets.fromLTRB(13, 12, 12, 11),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(s.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kMute)),
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB020)),
                    const SizedBox(width: 2),
                    Text(k.grate > 0 ? k.grate.toStringAsFixed(1) : '-', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    if (k.yt > 0) ...[
                      const SizedBox(width: 8),
                      Text('유튜브 ${k.yt}', style: const TextStyle(fontSize: 11.5, color: kSub)),
                    ],
                  ]),
                ]),
              ),
            );
          },
        ),
      );

  Widget _footer() {
    final up = area == null ? '' : store.updatedOf(area!.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(color: kLine, height: 1),
      const SizedBox(height: 14),
      Text('업체 정보는 카카오 장소 정보를 바탕으로 모았어요${up.isEmpty ? '' : ' · $up 기준'}',
          style: const TextStyle(fontSize: 11.5, color: kMute, height: 1.4)),
      const SizedBox(height: 3),
      const Text('틀린 정보는 가게 화면의 「정보 수정 신고」로 알려 주세요', style: TextStyle(fontSize: 11.5, color: kMute, height: 1.4)),
      const SizedBox(height: 10),
      const Text('디자인필', style: TextStyle(fontSize: 11.5, color: kMute, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _CatTile extends StatefulWidget {
  final Cat cat;
  final int? count;
  final VoidCallback onTap;
  const _CatTile({required this.cat, required this.count, required this.onTap});
  @override
  State<_CatTile> createState() => _CatTileState();
}

class _CatTileState extends State<_CatTile> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            AnimatedSlide(
              offset: hover ? const Offset(0, -0.06) : Offset.zero,
              duration: const Duration(milliseconds: 180),
              child: LineIcon(widget.cat.id, size: 38),
            ),
            const SizedBox(height: 7),
            Text(widget.cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.2)),
            const SizedBox(height: 1),
            Text(widget.count == null ? ' ' : '${widget.count}', style: const TextStyle(fontSize: 10.5, color: kMute, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}

// ---------------- 동네 고르기 ----------------

class AreaSheet extends StatelessWidget {
  final Area? current;
  const AreaSheet({super.key, this.current});

  @override
  Widget build(BuildContext context) {
    final bySido = <String, List<Area>>{};
    for (final a in store.areas) {
      bySido.putIfAbsent(a.sido, () => []).add(a);
    }
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text('동네 고르기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ),
          Flexible(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), shrinkWrap: true, children: [
              for (final e in bySido.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(e.key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kMute)),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in e.value)
                    InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: a.ready ? () => Navigator.pop(context, a) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: a.id == current?.id ? kBlue : Colors.white,
                          border: Border.all(color: a.id == current?.id ? kBlue : kLine),
                        ),
                        child: Text(
                          a.ready ? a.name : '${a.name} · 모으는 중',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: a.id == current?.id ? Colors.white : (a.ready ? kInk : kMute),
                          ),
                        ),
                      ),
                    ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
