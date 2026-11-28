// 동네 전화번호부 — 업종 화면 (대표님 11-24: 목록 먼저, 지도는 하단 지도 탭 하나로)
// 명함 카드 목록 + 정렬·필터. 「지도로 보기」는 하단 지도 탭으로 넘어가며 이 업종이 골라진 채로 열린다.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../registry.dart';
import 'card.dart';
import 'data.dart';
import 'shop_sheet.dart';

enum Sort { rec, near }

const _gap = 10.0;

class ShopListPage extends StatefulWidget {
  final Complex complex;
  final List<Shop> all;
  final Cat? cat;
  const ShopListPage({super.key, required this.complex, required this.all, this.cat});
  @override
  State<ShopListPage> createState() => _ShopListPageState();
}

class _ShopListPageState extends State<ShopListPage> {
  final q = TextEditingController();
  final listCtl = ScrollController();
  Sort sort = Sort.near;
  bool openOnly = false;
  String sub = '';
  bool finding = false; // 업종 안에서 이름 찾기 (대표님 11-28: 병원 → 피부과만)

  Complex get c => widget.complex;
  LatLng get from => c.pos;

  @override
  void initState() {
    super.initState();
    recTick.addListener(_re);
    loadRecs(c.areaId);
    loadLotsAround(from).then((_) => _re());
  }

  @override
  void dispose() {
    recTick.removeListener(_re);
    listCtl.dispose();
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  // ---------- 고르기·정렬 ----------
  List<Shop> get base => widget.cat == null ? widget.all : shopsInCat(widget.all, widget.cat!.id);

  List<Shop> get items {
    var list = base;
    final t = q.text.trim().replaceAll(' ', '');
    if (t.isNotEmpty) {
      list = list.where((s) => '${s.name}${s.sub}${s.cats.map((c) => catOf(c).name).join()}${s.addr}'.replaceAll(' ', '').contains(t)).toList();
    }
    if (sub.isNotEmpty) list = list.where((s) => s.sub == sub).toList();
    final now = DateTime.now();
    if (openOnly) {
      list = list.where((s) {
        final o = s.openAt(now);
        return o == Open.open || o == Open.closing;
      }).toList();
    }
    final d = {for (final s in list) s.id: meters(from, s.pos)};
    final r = recsOf(c.areaId);
    int n(Shop s) => r[s.id]?.n ?? 0;
    return [...list]
      ..sort((a, b) {
        if (sort == Sort.rec) {
          final k = n(b).compareTo(n(a));
          if (k != 0) return k;
        }
        return d[a.id]!.compareTo(d[b.id]!);
      });
  }

  List<MapEntry<String, int>> get subs {
    if (widget.cat == null) return const [];
    final m = <String, int>{};
    for (final s in base) {
      if (s.sub.isNotEmpty) m[s.sub] = (m[s.sub] ?? 0) + 1;
    }
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.length < 2 ? const [] : e.take(8).toList();
  }

  // 언제나 지도로 먼저 열고, 목록은 원할 때만 (대표님 11-23)
  void _changed() {
    if (listCtl.hasClients) listCtl.jumpTo(0);
  }

  // 하단 지도 탭으로: 이 업종이 골라진 채로 (가게를 주면 그 가게까지 골라서)
  void _toMap([Shop? s]) => openMapTab(context, MapAsk('phonebook', filter: widget.cat?.id ?? '', focus: s?.id ?? ''));

  @override
  Widget build(BuildContext context) {
    final list = items;
    return ScrollConfiguration(
      behavior: const _Drag(),
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(builder: (ctx, box) {
            final wide = box.maxWidth >= 760;
            return Column(children: [
              Container(color: Colors.white, child: Column(children: [_head(wide), _bar(list.length, wide)])),
              const Divider(height: 1, color: kLine),
              Expanded(child: _list(list, box.maxWidth, wide)),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _head(bool wide) {
    final title = widget.cat?.name ?? '찾기';
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 4, right: 14),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kInk)),
        if (widget.cat == null || finding)
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(controller: q, autofocus: true, onChanged: (_) => setState(_changed), style: const TextStyle(fontSize: 14.5), decoration: inputDeco(widget.cat == null ? '세탁소, 떡집, 가게 이름' : '${widget.cat!.name} 안에서 찾기 (예: ${widget.cat!.id == 'hosp' ? '피부과' : '가게 이름'})')),
            ),
          )
        else ...[
          LineIcon(widget.cat!.id, size: 26),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(width: 6),
          Text('${items.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w300, color: kSub)),
          if (wide) ...[
            const SizedBox(width: 10),
            Flexible(child: Text('${c.name} 기준', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMute))),
          ],
          const Spacer(),
        ],
        const SizedBox(width: 6),
        if (widget.cat != null)
          IconButton(
            tooltip: finding ? '찾기 닫기' : '이름으로 찾기',
            onPressed: () => setState(() {
              finding = !finding;
              if (!finding) q.clear();
              _changed();
            }),
            icon: Icon(finding ? Icons.close_rounded : Icons.search_rounded, size: 23, color: kInk),
          ),
        if (widget.cat != null && !finding) _mapBtn(),
      ]),
    );
  }

  // 「지도로 보기」 단추 → 하단 지도 탭
  Widget _mapBtn() => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _toMap(),
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(9, 0, 12, 0),
          decoration: BoxDecoration(color: const Color(0xFFEEF3FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFCADAFD))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined, size: 17, color: kBlue),
            SizedBox(width: 4),
            Text('지도로 보기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: kBlue)),
          ]),
        ),
      );

  Widget _bar(int n, bool wide) {
    final ss = subs;
    return SizedBox(
      height: 46,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), children: [
        _chip('이웃 추천 순', sort == Sort.rec, () => setState(() {
              sort = Sort.rec;
              _changed();
            })),
        _chip('가까운 순', sort == Sort.near, () => setState(() {
              sort = Sort.near;
              _changed();
            })),
        _chip('지금 영업 중', openOnly, () => setState(() {
              openOnly = !openOnly;
              _changed();
            }), dot: true),
        if (ss.isNotEmpty) ...[
          Container(width: 1, margin: const EdgeInsets.fromLTRB(4, 8, 10, 8), color: kLine),
          _chip('전체', sub.isEmpty, () => setState(() {
                sub = '';
                _changed();
              }), light: true),
          for (final e in ss)
            _chip(e.key, sub == e.key, () => setState(() {
                  sub = sub == e.key ? '' : e.key;
                  _changed();
                }), light: true),
        ],
      ]),
    );
  }

  Widget _chip(String t, bool on, VoidCallback f, {bool dot = false, bool light = false}) {
    final bg = on ? (light ? const Color(0xFFEEF3FF) : kInk) : Colors.white;
    final fg = on ? (light ? kBlue : Colors.white) : kSub;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17), border: Border.all(color: on ? (light ? const Color(0xFFC9D8FF) : kInk) : kLine)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFF7FB0FF) : kBlue)),
              const SizedBox(width: 5),
            ],
            Text(t, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: fg)),
          ]),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                openOnly
                    ? '지금 영업 중인 곳을 찾지 못했어요'
                    : q.text.isEmpty
                        ? '아직 모은 곳이 없어요'
                        : '찾는 곳이 없어요',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (openOnly) ...[
              const SizedBox(height: 5),
              const Text('영업시간을 아는 가게만 골라 보여 드려요', style: TextStyle(fontSize: 12, color: kMute)),
            ],
            const SizedBox(height: 16),
            SizedBox(width: 210, child: Btn('우리 가게 등록하기', icon: 'owner', h: 42, onTap: () => openOwnerForm(context, c, cat: widget.cat?.id))),
          ]),
        ),
      );

  // 명함 카드 목록 (넓은 화면은 두 줄)
  Widget _list(List<Shop> list, double w, bool wide) {
    final car = widget.cat?.id == 'car';
    if (list.isEmpty && !car) return _empty();
    final n = list.length > 300 ? 300 : list.length;
    // 휴대폰도 태블릿도 두 줄 (대표님 11-24) — 휴대폰은 작은 카드, 태블릿은 큰 카드
    final phone = w < 600;
    final pad = phone ? 14.0 : 16.0;
    final colW = ((w - pad * 2 - _gap) / 2).floorToDouble();
    Widget card(Shop s) => SizedBox(width: colW, child: ShopCard(key: ValueKey(s.id), shop: s, complex: c, tapHint: '지도', compact: phone, onTap: () => _toMap(s)));
    return ListView(
      controller: listCtl,
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 30 + MediaQuery.of(context).padding.bottom),
      children: [
        if (car) ...[_gasLink(), const SizedBox(height: _gap)],
        if (list.isEmpty) _empty(),
        // 두 칸씩 같은 높이로 (들쭉날쭉하지 않게)
        for (var i = 0; i < n; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < n ? _gap : 0),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                card(list[i]),
                const SizedBox(width: _gap),
                if (i + 1 < n) card(list[i + 1]) else SizedBox(width: colW),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(list.length > n ? '가까운 $n곳까지 보여 드려요' : '${list.length}곳 · ${c.name} 기준', textAlign: TextAlign.center, style: T.small),
        ),
      ],
    );
  }

  // 자동차: 주유소는 주유소 화면(가격과 함께)으로
  Widget _gasLink() {
    final gas = featureById('gas');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: gas == null ? null : () => openFeature(context, gas),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: kLine), boxShadow: kShadow),
          child: const Row(children: [
            LineIcon('gas', size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('주유소 가격 보기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 1),
                Text('주유소·충전소는 가격과 함께 따로 모아 두었어요', style: TextStyle(fontSize: 11.5, color: kSub)),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, size: 19, color: kBlue),
          ]),
        ),
      ),
    );
  }
}

// 마우스로도 끌어 넘길 수 있게 (PC 화면에서 카드 넘기기)
class _Drag extends MaterialScrollBehavior {
  const _Drag();
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus};
}

