// 가까운 우체국 · 택배 접수 편의점 (이 폴더는 택배·우편 담당 방만 고침)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

class OfficePage extends StatefulWidget {
  final Complex c;
  const OfficePage(this.c, {super.key});
  @override
  State<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends State<OfficePage> {
  List<PostPlace>? all;
  String kind = '전체';

  @override
  void initState() {
    super.initState();
    postPlaces(widget.c).then((v) {
      if (mounted) setState(() => all = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = widget.c.pos;
    final l = (all ?? const <PostPlace>[])
        .where((p) => kind == '전체' || (kind == '우체국' ? p.isPo : !p.isPo))
        .where((p) => meters(from, p.pos) <= 3000)
        .toList()
      ..sort((a, b) => meters(from, a.pos).compareTo(meters(from, b.pos)));
    final h = MediaQuery.of(context).size.height;
    return DetailPage(
      title: '우체국·택배 접수',
      body: Column(children: [
        SizedBox(
          height: h * 0.32,
          child: all == null
              ? Container(color: kBg)
              : DongneMap(
                  key: ValueKey(kind),
                  center: from,
                  zoom: 14.6,
                  pinFill: kSoftOrange,
                  points: [
                    for (final p in l.take(150))
                      MapPoint(id: p.id, name: p.name, sub: p.label, badge: p.isPo ? '우체국' : '', pos: p.pos, onTap: (ctx) => showPlace(ctx, p, widget.c)),
                  ],
                ),
        ),
        Container(height: 1, color: kLine),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 0), children: [
            for (final k in const ['전체', '우체국', '편의점 택배']) _chip(k, kind == k, () => setState(() => kind = k)),
          ]),
        ),
        Expanded(
          child: all == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1.6))
              : all!.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30),
                      itemCount: l.length + 1,
                      itemBuilder: (_, i) => i == l.length ? _foot() : _row(l[i], meters(from, l[i].pos), now),
                    ),
        ),
      ]),
    );
  }

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? kInk : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: on ? kInk : kLine)),
            child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : kInk)),
          ),
        ),
      );

  Widget _row(PostPlace p, double m, DateTime now) {
    final open = p.openAt(now);
    return InkWell(
      onTap: () => showPlace(context, p, widget.c),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
        child: Row(children: [
          p.isPo ? const PostIcon('postbox', size: 26, fill: kSoftOrange) : const LineIcon('mart', size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title),
              const SizedBox(height: 2),
              Text('${distText(m)} · ${p.label}${p.addr.isEmpty ? '' : ' · ${p.addr}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
            ]),
          ),
          const SizedBox(width: 8),
          Text(open ? '영업 중' : '문 닫음', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: open ? kInk : kMute)),
        ]),
      ),
    );
  }

  Widget _foot() => const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Text('우체국 시간은 창구 기본 시간이에요. 우체국마다 다르고 공휴일엔 쉬니 방문 전 전화로 확인해 주세요. '
            '편의점 택배는 CU·GS25 대부분에서 접수하지만 안 되는 매장도 있어요.', style: T.tiny),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(kPad),
        child: Column(children: [
          const SizedBox(height: 20),
          const PostIcon('postbox', size: 44, fill: kSoftOrange),
          const SizedBox(height: 10),
          const Text('이 동네 우체국 자료를 아직 모으지 못했어요', style: T.title),
          const SizedBox(height: 4),
          const Text('다음 자료 모으기 때 채워져요', style: T.small),
          const SizedBox(height: 14),
          SizedBox(width: 220, child: Btn('지도 앱에서 우체국 찾기', h: 42, onTap: () => openUrl('https://map.kakao.com/?q=${Uri.encodeQueryComponent('${widget.c.town} 우체국')}'))),
        ]),
      );
}

void showPlace(BuildContext context, PostPlace p, Complex c) {
  final open = p.openAt(DateTime.now());
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: T.h2)),
          Text(open ? '영업 중' : '문 닫음', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: open ? kBlue : kMute)),
        ]),
        const SizedBox(height: 4),
        Text('${p.label} · ${distText(meters(c.pos, p.pos))}', style: T.small),
        const SizedBox(height: 12),
        if (p.addr.isNotEmpty) _kv('주소', p.addr),
        _kv('시간', p.hours),
        if (p.tel.isNotEmpty) _kv('전화', p.tel),
        const SizedBox(height: 4),
        const Text('방문 전 전화로 확인해 주세요', style: T.tiny),
        const SizedBox(height: 14),
        Row(children: [
          if (p.tel.isNotEmpty) ...[
            Expanded(child: Btn('전화', icon: 'phone', onTap: () => callTel(p.tel))),
            const SizedBox(width: 10),
          ],
          Expanded(child: Btn('여기로 길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: p.name, lat: p.lat, lng: p.lng))),
        ]),
      ]),
    ),
  );
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 40, child: Text(k, style: const TextStyle(fontSize: 12, color: kMute, height: 1.4))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
