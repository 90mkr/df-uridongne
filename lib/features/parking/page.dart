// 주차장 상세 화면 — 위 지도 + 아래 가까운 순 목록 + 누르면 요금·운영시간 (이 폴더는 주차장 담당 방만 고침)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _fill = Color(0xFFE8EEFF);

class ParkingPage extends StatefulWidget {
  final Complex complex;
  const ParkingPage({super.key, required this.complex});
  @override
  State<ParkingPage> createState() => _ParkingPageState();
}

class _ParkingPageState extends State<ParkingPage> {
  List<Lot>? all;
  String updated = '';
  int km = 1;
  String kind = '전체'; // 전체 · 공영 · 무료 · 지금 운영
  bool mapBig = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await lotsNear(widget.complex.pos, km: 5);
    final u = await parkingUpdated();
    if (!mounted) return;
    // 처음 거리: 3곳 이상 보이는 가장 가까운 범위 (송도처럼 공영이 드문 곳은 넓혀서)
    final from = widget.complex.pos;
    var k = 5;
    for (final d in const [1, 2, 3]) {
      if (v.where((l) => meters(from, l.pos) <= d * 1000).length >= 3) {
        k = d;
        break;
      }
    }
    setState(() {
      all = v;
      updated = u;
      km = k;
    });
  }

  List<Lot> get items {
    final now = DateTime.now();
    final from = widget.complex.pos;
    return (all ?? const <Lot>[]).where((l) {
      if (meters(from, l.pos) > km * 1000) return false;
      if (kind == '공영') return l.isPublic;
      if (kind == '무료') return l.isFree;
      if (kind == '지금 운영') return l.openAt(now) == true;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    final h = MediaQuery.of(context).size.height;
    return DetailPage(
      title: '주차장',
      icon: 'parking',
      actions: [
        IconButton(
          tooltip: mapBig ? '목록 크게' : '지도 크게',
          onPressed: () => setState(() => mapBig = !mapBig),
          icon: LineIcon(mapBig ? 'list' : 'map', size: 23),
        ),
      ],
      body: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: mapBig ? h * 0.58 : h * 0.3,
          child: all == null
              ? Container(color: kBg)
              : DongneMap(
                  key: ValueKey('$km$kind'),
                  center: widget.complex.pos,
                  zoom: km == 1 ? 15 : (km == 2 ? 14 : (km == 3 ? 13.3 : 12.5)),
                  pinFill: _fill,
                  points: [
                    for (final l in list.take(300))
                      MapPoint(id: l.id, name: '${l.name} · ${l.feeShort}', sub: l.label, badge: l.badge, pos: l.pos, onTap: (ctx) => showLot(ctx, l, widget.complex)),
                  ],
                ),
        ),
        Container(height: 1, color: kLine),
        _bar(list.length),
        Expanded(child: _list(list)),
      ]),
    );
  }

  Widget _bar(int n) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 0), children: [
            for (final k in const ['전체', '공영', '무료', '지금 운영']) _chip(k, kind == k, () => setState(() => kind = k)),
            Container(width: 1, height: 20, margin: const EdgeInsets.fromLTRB(4, 7, 10, 7), color: kLine),
            for (final d in const [1, 2, 3, 5]) _chip('${d}km', km == d, () => setState(() => km = d)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const MixTitle('가까운', '주차장', size: 14.5),
            const SizedBox(width: 6),
            Text(all == null ? '' : '$n곳', style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w500)),
            const Spacer(),
            Flexible(child: Text('${widget.complex.name}에서', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)),
          ]),
        ),
      ]);

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

  Widget _list(List<Lot> list) {
    if (all == null) return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    final foot = Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Text(
        '지자체가 공공데이터포털에 올린 주차장 정보예요${updated.isEmpty ? '' : ' ($updated 받음)'}. 요금·운영시간은 바뀌었을 수 있으니 현장 안내를 함께 확인해 주세요.',
        style: T.tiny,
      ),
    );
    if (list.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(kPad, 40, kPad, 30), children: [
        const LineIcon('parking', size: 46, fill: _fill),
        const SizedBox(height: 12),
        Text(
          (all ?? const []).isEmpty ? '이 동네 주차장 정보를 아직 받지 못했어요' : '조건에 맞는 주차장이 없어요\n거리를 넓히거나 다른 조건을 골라 보세요',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: kSub, height: 1.45),
        ),
        foot,
      ]);
    }
    final now = DateTime.now();
    final from = widget.complex.pos;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(kPad, 2, kPad, 30),
      itemCount: list.length + 1,
      separatorBuilder: (_, i) => i == list.length - 1 ? const SizedBox() : const Divider(height: 1, color: Color(0xFFEFF1F4)),
      itemBuilder: (_, i) => i == list.length ? foot : LotRow(lot: list[i], dist: meters(from, list[i].pos), now: now, onTap: () => showLot(context, list[i], widget.complex)),
    );
  }
}

class LotRow extends StatelessWidget {
  final Lot lot;
  final double dist;
  final DateTime now;
  final VoidCallback onTap;
  const LotRow({super.key, required this.lot, required this.dist, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = lot;
    final open = l.openAt(now);
    final hrs = l.hoursText(now);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3))),
                const SizedBox(width: 6),
                Text(l.label, style: const TextStyle(fontSize: 11, color: kMute)),
              ]),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: distText(dist)),
                  if (open == false) const TextSpan(text: ' · 지금 운영 안 함', style: TextStyle(color: Color(0xFFC23B3B))),
                  if (open != false && hrs.isNotEmpty) TextSpan(text: ' · 오늘 $hrs'),
                  TextSpan(text: ' · ${l.feeShort}', style: TextStyle(color: l.isFree ? kInk : kSub, fontWeight: l.isFree ? FontWeight.w700 : FontWeight.w400)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.small,
              ),
            ]),
          ),
          const SizedBox(width: 10),
          if (l.spaces > 0)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l.spaces}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: kInk)),
                const TextSpan(text: '면', style: TextStyle(fontSize: 11, color: kSub)),
              ]),
            ),
        ]),
      ),
    );
  }
}

// 주차장 하나 자세히 (아래에서 올라오는 창)
Future<void> showLot(BuildContext context, Lot l, Complex c) => showSheet(context, (ctx) {
      final now = DateTime.now();
      final open = l.openAt(now);
      final rows = <(String, String)>[
        ('평일', _span(l.hours[0], l.hours[1])),
        ('토요일', l.days.isNotEmpty && !l.days.contains('토') ? '운영 안 함' : _span(l.hours[2], l.hours[3])),
        ('일·공휴일', l.days.isNotEmpty && !(l.days.contains('공휴') || l.days.contains('일요')) ? '운영 안 함' : _span(l.hours[4], l.hours[5])),
      ];
      final fees = <(String, String)>[
        if (l.isFree) ('요금', '무료'),
        if (!l.isFree && l.basicMin > 0) ('기본', '${l.basicMin}분 ${won(l.basicWon)}'),
        if (!l.isFree && l.addMin > 0) ('추가', '${l.addMin}분마다 ${won(l.addWon)}'),
        if (l.dayWon > 0) ('하루', won(l.dayWon)),
        if (l.monthWon > 0) ('월 정기', won(l.monthWon)),
      ];
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 14), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, style: T.h2),
              const SizedBox(height: 3),
              Text('${distText(meters(c.pos, l.pos))} · ${l.label}${l.addr.isEmpty ? '' : ' · ${l.addr}'}', style: T.small),
            ]),
          ),
          if (l.spaces > 0) ...[
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '${l.spaces}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: kBlue)),
                const TextSpan(text: '면', style: TextStyle(fontSize: 11.5, color: kSub)),
              ])),
              const Text('주차 구획', style: T.tiny),
            ]),
          ],
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (open == true) const Pill('지금 운영 중', color: Color(0xFF1E8A50), bg: Color(0xFFE7F6EE)),
          if (open == false) const Pill('지금 운영 안 함', color: Color(0xFFC23B3B), bg: Color(0xFFFBECEC)),
          if (l.disabled) const Pill('장애인 전용 구역'),
          if (l.pay.isNotEmpty) Pill('결제 ${l.pay}'),
        ]),
        if (fees.isNotEmpty) ...[
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in fees)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  constraints: const BoxConstraints(minWidth: 92),
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.$1, style: const TextStyle(fontSize: 10.5, color: kSub)),
                    const SizedBox(height: 1),
                    Text(f.$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        const Text('운영시간', style: T.title),
        const SizedBox(height: 6),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              SizedBox(width: 70, child: Text(r.$1, style: T.small)),
              Text(r.$2.isEmpty ? '정보 없음' : r.$2, style: const TextStyle(fontSize: 12.5, height: 1.35)),
            ]),
          ),
        if (l.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('안내', style: T.title),
          const SizedBox(height: 4),
          Text(l.note, style: const TextStyle(fontSize: 12.5, height: 1.45, color: kSub)),
        ],
        if (l.org.isNotEmpty || l.tel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('관리 ${[l.org, l.tel].where((s) => s.isNotEmpty).join(' · ')}', style: T.tiny),
        ],
        const SizedBox(height: 16),
        Row(children: [
          if (l.tel.isNotEmpty) ...[
            Expanded(child: Btn('전화', icon: 'phone', onTap: () => callTel(l.tel))),
            const SizedBox(width: 8),
          ],
          Expanded(child: Btn('여기로 길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: l.name, lat: l.lat, lng: l.lng))),
        ]),
        const SizedBox(height: 8),
        const Text('요금·운영시간은 지자체 공공데이터 기준이에요. 현장 안내와 다를 수 있어요.', textAlign: TextAlign.center, style: T.tiny),
      ]);
    });

String _span(String o, String c) {
  if (o.isEmpty || c.isEmpty) return '';
  if (o == '00:00' && (c == '23:59' || c == '24:00' || c == '00:00')) return '24시간';
  return '$o ~ $c';
}

// 지도 탭용 점
Future<List<MapPoint>> parkingPoints(Complex c) async {
  final v = await lotsNear(c.pos, km: 2);
  return [
    for (final l in v.take(200))
      MapPoint(id: 'parking_${l.id}', name: '${l.name} · ${l.feeShort}', sub: l.label, badge: l.badge, pos: l.pos, onTap: (ctx) => showLot(ctx, l, c)),
  ];
}
