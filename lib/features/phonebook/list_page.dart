// 동네 전화번호부 — 업종 목록 · 찾기 · 지도 (이 폴더는 전화번호부 담당 방만 고침)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'shop_sheet.dart';

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
  bool mapView = false;
  bool byName = false;
  String sub = '';
  static const _show = 300;

  LatLng get from => widget.complex.pos;
  List<Shop> get base => widget.cat == null ? widget.all : widget.all.where((s) => s.cats.contains(widget.cat!.id)).toList();

  List<Shop> get items {
    var list = base;
    final t = q.text.trim().replaceAll(' ', '');
    if (t.isNotEmpty) {
      list = list.where((s) => '${s.name}${s.sub}${s.cats.map((c) => catOf(c).name).join()}${s.addr}'.replaceAll(' ', '').contains(t)).toList();
    }
    if (sub.isNotEmpty) list = list.where((s) => s.sub == sub).toList();
    final d = {for (final s in list) s.id: meters(from, s.pos)};
    return [...list]..sort((a, b) => byName ? a.name.compareTo(b.name) : d[a.id]!.compareTo(d[b.id]!));
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

  @override
  Widget build(BuildContext context) {
    final list = items;
    return DetailPage(
      title: widget.cat?.name ?? '찾기',
      icon: widget.cat?.id,
      actions: [
        IconButton(
          tooltip: mapView ? '목록으로' : '지도로',
          onPressed: () => setState(() => mapView = !mapView),
          icon: LineIcon(mapView ? 'list' : 'map', size: 23),
        ),
      ],
      body: Column(children: [
        if (widget.cat == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 0),
            child: TextField(controller: q, autofocus: true, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 14.5), decoration: inputDeco('세탁소, 떡집, 가게 이름')),
          ),
        _bar(list.length),
        Expanded(child: mapView ? _map(list) : _list(list)),
      ]),
    );
  }

  Widget _bar(int n) {
    final ss = subs;
    return Column(children: [
      if (ss.isNotEmpty)
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 0), children: [
            _chip('전체', sub.isEmpty, () => setState(() => sub = '')),
            for (final e in ss) _chip(e.key, sub == e.key, () => setState(() => sub = sub == e.key ? '' : e.key)),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 10, kPad - 6, 6),
        child: Row(children: [
          Text('$n곳 · ${widget.complex.name}에서 가까운 순', style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w500)),
          const Spacer(),
          _sort('가까운 순', !byName, () => setState(() => byName = false)),
          _sort('이름 순', byName, () => setState(() => byName = true)),
        ]),
      ),
    ]);
  }

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? kInk : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? kInk : kLine)),
            child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: on ? Colors.white : kSub)),
          ),
        ),
      );

  Widget _sort(String t, bool on, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(t, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: on ? kInk : kMute)),
        ),
      );

  Widget _list(List<Shop> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(q.text.isEmpty ? '아직 모은 곳이 없어요' : '찾는 곳이 없어요', style: const TextStyle(fontSize: 14, color: kSub)),
          const SizedBox(height: 14),
          SizedBox(width: 220, child: Btn('우리 가게 등록하기', icon: 'owner', onTap: () => openOwnerForm(context, widget.complex, cat: widget.cat?.id))),
        ]),
      );
    }
    final n = math.min(list.length, _show);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30),
      itemCount: n + (list.length > n ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFF1F4)),
      itemBuilder: (_, i) {
        if (i == n) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('가까운 $n곳까지 보여 드려요. 이름으로 찾아보세요', textAlign: TextAlign.center, style: T.small));
        }
        final s = list[i];
        return ShopRow(shop: s, dist: meters(from, s.pos), onTap: () => showShop(context, s, widget.complex));
      },
    );
  }

  Widget _map(List<Shop> list) => DongneMap(
        center: from,
        points: [
          for (final s in list.take(400))
            MapPoint(id: s.id, name: s.name, sub: s.sub, pos: s.pos, onTap: (ctx) => showShop(ctx, s, widget.complex)),
        ],
      );
}

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
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3))),
                const SizedBox(width: 6),
                Text(s.sub, style: const TextStyle(fontSize: 11, color: kMute)),
                if (s.kok != null) ...[const SizedBox(width: 6), const Pill('콕플 맛집', color: Color(0xFFE8540F), bg: Color(0xFFFFF1E8))],
              ]),
              const SizedBox(height: 2),
              Text('${distText(dist)} · ${s.addr}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
            ]),
          ),
          if (s.tel.isNotEmpty) IconButton(tooltip: '전화', onPressed: () => callTel(s.tel), icon: const LineIcon('phone', size: 22)),
        ]),
      ),
    );
  }
}
