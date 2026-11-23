part of 'main.dart';

// ---------------- 분야별 목록 · 찾기 · 지도 ----------------

class ShopListPage extends StatefulWidget {
  final Area area;
  final List<Shop> all;
  final Cat? cat;
  final bool search;
  const ShopListPage({super.key, required this.area, required this.all, this.cat, this.search = false});
  @override
  State<ShopListPage> createState() => _ShopListPageState();
}

class _ShopListPageState extends State<ShopListPage> {
  final q = TextEditingController();
  bool mapView = false;
  bool byName = false;
  String sub = ''; // 세부 분류 거르기
  final mapCtl = MapController();
  static const _show = 300; // 목록에 한 번에 그리는 수

  @override
  void initState() {
    super.initState();
    myPos.addListener(_re);
  }

  @override
  void dispose() {
    myPos.removeListener(_re);
    q.dispose();
    super.dispose();
  }

  void _re() => mounted ? setState(() {}) : null;

  LatLng get from {
    final p = myPos.value;
    return p != null && meters(p, widget.area.center) < 15000 ? p : widget.area.center;
  }

  bool get nearMe => myPos.value != null && meters(myPos.value!, widget.area.center) < 15000;

  List<Shop> get base => widget.cat == null ? widget.all : widget.all.where((s) => s.cats.contains(widget.cat!.id)).toList();

  List<Shop> get items {
    var list = base;
    final t = q.text.trim().replaceAll(' ', '');
    if (t.isNotEmpty) {
      list = list.where((s) {
        final hay = '${s.name}${s.sub}${s.cats.map((c) => catOf(c).name).join()}${s.addr}'.replaceAll(' ', '');
        return hay.contains(t);
      }).toList();
    }
    if (sub.isNotEmpty) list = list.where((s) => s.sub == sub).toList();
    final f = from;
    final d = {for (final s in list) s.id: meters(f, s.pos)};
    list = [...list]..sort((a, b) => byName ? a.name.compareTo(b.name) : d[a.id]!.compareTo(d[b.id]!));
    return list;
  }

  // 세부 분류 (많은 순 8개)
  List<MapEntry<String, int>> get subs {
    if (widget.cat == null) return const [];
    final m = <String, int>{};
    for (final s in base) {
      if (s.sub.isNotEmpty) m[s.sub] = (m[s.sub] ?? 0) + 1;
    }
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.length < 2 ? const [] : e.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    final pad = MediaQuery.of(context).size.width < 600 ? 20.0 : 32.0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: widget.search
            ? _searchField()
            : Row(children: [
                LineIcon(widget.cat!.id, size: 24),
                const SizedBox(width: 8),
                Text(widget.cat!.name),
                const SizedBox(width: 8),
                Text('${base.length}', style: const TextStyle(fontSize: 13, color: kMute, fontWeight: FontWeight.w500)),
              ]),
        actions: [
          IconButton(
            tooltip: mapView ? '목록으로' : '지도로',
            onPressed: () => setState(() => mapView = !mapView),
            icon: LineIcon(mapView ? 'list' : 'map', size: 23),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: kLine)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mapView ? double.infinity : 720),
          child: Column(children: [
            _bar(list.length, pad),
            Expanded(child: mapView ? _map(list) : _list(list, pad)),
          ]),
        ),
      ),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TextField(
          controller: q,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            hintText: '세탁소, 떡집, 가게 이름',
            hintStyle: const TextStyle(color: kMute, fontSize: 15),
            filled: true,
            fillColor: kBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue)),
            suffixIcon: q.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: kMute),
                    onPressed: () => setState(() => q.clear()),
                  ),
          ),
        ),
      );

  Widget _bar(int n, double pad) {
    final ss = subs;
    return Container(
      color: Colors.white,
      child: Column(children: [
        if (ss.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
              children: [
                _chip('전체', sub.isEmpty, () => setState(() => sub = '')),
                for (final e in ss) _chip(e.key, sub == e.key, () => setState(() => sub = sub == e.key ? '' : e.key)),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 10, pad - 6, 6),
          child: Row(children: [
            Text(
              widget.search && q.text.trim().isEmpty ? '${widget.area.name} 전체 $n곳' : '$n곳',
              style: const TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            _sortBtn('가까운 순', !byName, () => setState(() => byName = false)),
            _sortBtn('이름 순', byName, () => setState(() => byName = true)),
          ]),
        ),
        if (!nearMe && !byName)
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
            child: InkWell(
              onTap: () async {
                final p = await myLocation();
                if (p == null && mounted) toast(context, '위치를 알 수 없어 동네 가운데에서 잰 거리예요');
              },
              child: Row(children: [
                const Text('동네 가운데에서 잰 거리예요 · ', style: TextStyle(fontSize: 11.5, color: kMute)),
                Text('내 위치로 보기', style: TextStyle(fontSize: 11.5, color: kBlue.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? kInk : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: on ? kInk : kLine),
            ),
            child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: on ? Colors.white : kSub)),
          ),
        ),
      );

  Widget _sortBtn(String t, bool on, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: on ? kInk : kMute)),
        ),
      );

  Widget _list(List<Shop> list, double pad) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(q.text.isEmpty ? '아직 모은 곳이 없어요' : '찾는 곳이 없어요', style: const TextStyle(fontSize: 14.5, color: kSub)),
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: Btn('우리 가게 등록하기', icon: 'owner', onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => OwnerForm(area: widget.area, cat: widget.cat)));
              }),
            ),
          ]),
        ),
      );
    }
    final f = from;
    final n = math.min(list.length, _show);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 4, pad, 30),
      itemCount: n + (list.length > n ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFF1F4)),
      itemBuilder: (_, i) {
        if (i == n) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text('가까운 $n곳까지 보여 드려요. 이름으로 찾아보세요', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: kMute)),
          );
        }
        final s = list[i];
        return ShopRow(shop: s, dist: meters(f, s.pos), onTap: () => showShop(context, s, widget.area));
      },
    );
  }

  Widget _map(List<Shop> list) {
    final f = from;
    final show = list.take(400).toList();
    return FlutterMap(
      mapController: mapCtl,
      options: MapOptions(
        initialCenter: f,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
        MarkerLayer(markers: [
          if (myPos.value != null && nearMe)
            Marker(
              point: myPos.value!,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: kBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: kBlue.withValues(alpha: 0.3), blurRadius: 8)],
                ),
              ),
            ),
          for (final s in show)
            Marker(
              point: s.pos,
              width: 34,
              height: 40,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => showShop(context, s, widget.area),
                child: LineIcon('pin', size: 34, fill: s.kok != null ? const Color(0xFFFFD9C2) : kSoft),
              ),
            ),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
      ],
    );
  }
}

// 목록 한 줄: 이름 · 세부 분류 · 주소 · 거리 · 전화 단추
class ShopRow extends StatelessWidget {
  final Shop shop;
  final double dist;
  final VoidCallback onTap;
  const ShopRow({super.key, required this.shop, required this.dist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = shop;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                ),
                const SizedBox(width: 6),
                Text(s.sub, style: const TextStyle(fontSize: 11.5, color: kMute)),
                if (s.kok != null) ...[
                  const SizedBox(width: 6),
                  const Pill('콕플 맛집', color: Color(0xFFE8540F), bg: Color(0xFFFFF1E8)),
                ],
              ]),
              const SizedBox(height: 3),
              Text('${distText(dist)} · ${s.addr}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kSub, height: 1.3)),
            ]),
          ),
          if (s.tel.isNotEmpty)
            IconButton(
              tooltip: '전화',
              onPressed: () => callTel(s.tel),
              icon: const LineIcon('phone', size: 22),
            ),
        ]),
      ),
    );
  }
}
