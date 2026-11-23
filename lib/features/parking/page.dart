// 주차장 상세 화면 (이 폴더는 주차장 담당 방만 고침)
// 맨 위 「내 차 어디 댔지」 · 필터 줄(전체·지금 무료·공영·24시간) · 요금 말풍선 지도 · 아래 목록(가까운 순/싼 순, 줄마다 길안내)
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/fb.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'busy.dart';
import 'car.dart';
import 'data.dart';

const _fill = Color(0xFFE8EEFF);
const _freeColor = Color(0xFF1E8A50);

class ParkingPage extends StatefulWidget {
  final Complex complex;
  final LatLng? at; // 가게 화면 등에서 열 때 기준 위치 (없으면 단지)
  final String? atName;
  const ParkingPage({super.key, required this.complex, this.at, this.atName});
  @override
  State<ParkingPage> createState() => _ParkingPageState();
}

class _ParkingPageState extends State<ParkingPage> {
  List<Lot>? all;
  String updated = '';
  int km = 1;
  String filter = '전체'; // 전체 · 지금 무료 · 공영 · 24시간
  bool cheap = false; // 싼 순
  bool mapBig = false;

  LatLng get from => widget.at ?? widget.complex.pos;

  @override
  void initState() {
    super.initState();
    carAlert.addListener(_alert);
    _load();
  }

  @override
  void dispose() {
    carAlert.removeListener(_alert);
    super.dispose();
  }

  void _alert() {
    final m = carAlert.value;
    if (m != null && mounted) {
      toast(context, m);
      carAlert.value = null;
    }
  }

  Future<void> _load() async {
    final v = await lotsNear(from, km: 5);
    final u = await parkingUpdated();
    if (!mounted) return;
    // 처음 거리: 3곳 이상 보이는 가장 가까운 범위 (공영이 드문 동네는 넓혀서)
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
    final list = (all ?? const <Lot>[]).where((l) {
      if (meters(from, l.pos) > km * 1000) return false;
      if (filter == '지금 무료') return l.freeAt(now);
      if (filter == '공영') return l.isPublic;
      if (filter == '24시간') return l.allDay;
      return true;
    }).toList();
    if (cheap) {
      final d = {for (final l in list) l.id: meters(from, l.pos)};
      list.sort((a, b) {
        final c = (a.freeAt(now) ? 0 : a.hourCost).compareTo(b.freeAt(now) ? 0 : b.hourCost);
        return c != 0 ? c : d[a.id]!.compareTo(d[b.id]!);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    final h = MediaQuery.of(context).size.height;
    final now = DateTime.now();
    return DetailPage(
      title: widget.atName == null ? '주차장' : '${widget.atName} 근처 주차장',
      icon: 'parking',
      white: false,
      actions: [
        IconButton(
          tooltip: mapBig ? '목록 크게' : '지도 크게',
          onPressed: () => setState(() => mapBig = !mapBig),
          icon: LineIcon(mapBig ? 'list' : 'map', size: 23),
        ),
      ],
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 0), child: CarBar(lots: all ?? const [])),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 2), children: [
            for (final k in const ['전체', '지금 무료', '공영', '24시간']) _chip(k, filter == k, () => setState(() => filter = k)),
          ]),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: mapBig ? h * 0.52 : h * 0.26,
          decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: kLine))),
          child: all == null
              ? Container(color: kBg)
              : DongneMap(
                  key: ValueKey('$km$filter${from.latitude}'),
                  center: from,
                  zoom: km == 1 ? 15 : (km == 2 ? 14 : (km == 3 ? 13.3 : 12.5)),
                  pinFill: _fill,
                  points: [
                    for (final l in list.take(300))
                      MapPoint(id: l.id, name: l.name, sub: l.label, badge: l.freeAt(now) ? '무료' : l.badge, pos: l.pos, onTap: (ctx) => showLot(ctx, l, from)),
                  ],
                ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(children: [
              _head(list.length),
              Expanded(child: _list(list)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _head(int n) => Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 12, kPad - 6, 4),
        child: Row(children: [
          const MixTitle('가까운', '주차장', size: 14.5),
          const SizedBox(width: 6),
          Text(all == null ? '' : '$n곳', style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => km = const {1: 2, 2: 3, 3: 5, 5: 1}[km]!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${km}km 안', style: const TextStyle(fontSize: 12, color: kSub)),
                const Icon(Icons.unfold_more_rounded, size: 14, color: kMute),
              ]),
            ),
          ),
          const Spacer(),
          _sort('가까운 순', !cheap, () => setState(() => cheap = false)),
          _sort('싼 순', cheap, () => setState(() => cheap = true)),
        ]),
      );

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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

  Widget _list(List<Lot> list) {
    if (all == null) return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    final foot = Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 200, child: Btn('주차장 알려 주기', icon: 'parking', h: 40, onTap: () => openParkingReport(context, widget.complex))),
        const SizedBox(height: 10),
        Text(
          '지자체가 공공데이터포털에 올린 공영 위주 자료라 빠진 주차장이 있을 수 있어요${updated.isEmpty ? '' : ' ($updated 받음)'}. 「지금 무료」에는 노상 주차장의 요금 시간 밖(야간·주말)도 들어가요. 현장 안내를 함께 확인해 주세요.',
          style: T.tiny,
        ),
      ]),
    );
    if (list.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(kPad, 24, kPad, 30), children: [
        const LineIcon('parking', size: 46, fill: _fill),
        const SizedBox(height: 12),
        Text(
          (all ?? const []).isEmpty ? '이 동네 주차장 정보를 아직 받지 못했어요' : '조건에 맞는 주차장이 없어요\n「${km}km 안」을 눌러 거리를 넓혀 보세요',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: kSub, height: 1.45),
        ),
        foot,
      ]);
    }
    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 30),
      itemCount: list.length + 1,
      separatorBuilder: (_, i) => i == list.length - 1 ? const SizedBox() : const Divider(height: 1, color: Color(0xFFEFF1F4)),
      itemBuilder: (_, i) => i == list.length ? foot : LotRow(lot: list[i], dist: meters(from, list[i].pos), now: now, onTap: () => showLot(context, list[i], from)),
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
    final free = l.freeAt(now);
    final hrs = l.hoursText(now);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  TextSpan(text: free ? (l.isFree ? '무료' : '지금 무료') : l.feeShort, style: TextStyle(color: free ? _freeColor : kInk, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' · ${distText(dist)}'),
                  if (l.spaces > 0) TextSpan(text: ' · ${l.spaces}면'),
                  if (open == false && !free) const TextSpan(text: ' · 지금 운영 안 함'),
                  if (open != false && hrs.isNotEmpty) TextSpan(text: ' · $hrs'),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.small,
              ),
            ]),
          ),
          const SizedBox(width: 6),
          IconButton(tooltip: '길안내', onPressed: () => startNav(context, name: l.name, lat: l.lat, lng: l.lng), icon: const LineIcon('route', size: 23)),
        ]),
      ),
    );
  }
}

// 주차장 하나 자세히 (아래에서 올라오는 창)
Future<void> showLot(BuildContext context, Lot l, LatLng from) => showSheet(context, (ctx) {
      final now = DateTime.now();
      final open = l.openAt(now);
      final free = l.freeAt(now);
      final rows = <(String, String)>[
        ('평일', _span(l.hours[0], l.hours[1])),
        ('토요일', l.days.isNotEmpty && !l.days.contains('토') ? '운영 안 함' : _span(l.hours[2], l.hours[3])),
        ('일·공휴일', l.days.isNotEmpty && !(l.days.contains('공휴') || l.days.contains('일요')) ? '운영 안 함' : _span(l.hours[4], l.hours[5])),
      ];
      final fees = <(String, String)>[
        if (l.isFree) ('요금', '무료'),
        if (!l.isFree && l.basicMin > 0) ('기본', '${l.basicMin}분 ${won(l.basicWon)}'),
        if (!l.isFree && l.addMin > 0) ('추가', '${l.addMin}분마다 ${won(l.addWon)}'),
        if (!l.isFree && l.costFor(60) != null) ('1시간', won(l.costFor(60)!)),
        if (l.dayWon > 0) ('하루', won(l.dayWon)),
        if (l.monthWon > 0) ('월 정기', won(l.monthWon)),
      ];
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 14), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, style: T.h2),
              const SizedBox(height: 3),
              Text('${distText(meters(from, l.pos))} · ${l.label}${l.addr.isEmpty ? '' : ' · ${l.addr}'}', style: T.small),
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
          if (free) Pill(l.isFree ? '무료 주차장' : '지금 무료 (요금 시간 밖)', color: _freeColor, bg: const Color(0xFFE7F6EE)),
          if (open == true) const Pill('지금 운영 중'),
          if (open == false && !free) const Pill('지금 운영 안 함', color: Color(0xFFC23B3B), bg: Color(0xFFFBECEC)),
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
                  constraints: const BoxConstraints(minWidth: 84),
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
        const SizedBox(height: 12),
        BusyBox(lotId: l.id),
        const SizedBox(height: 12),
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
          Expanded(flex: 2, child: Btn('여기로 길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: l.name, lat: l.lat, lng: l.lng))),
        ]),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => openParkingReport(ctx, null, lot: l),
            child: const Text('정보가 틀려요', style: TextStyle(fontSize: 12, color: kSub)),
          ),
        ),
      ]);
    });

String _span(String o, String c) {
  if (o.isEmpty || c.isEmpty) return '';
  if (o == '00:00' && (c == '23:59' || c == '24:00' || c == '00:00')) return '24시간';
  return '$o ~ $c';
}

// 「주차장 알려 주기」 · 「정보가 틀려요」 — 관리자 확인 뒤 반영 (dn_reqs, kind fix · cat parking — 지금 규칙 그대로 됨)
Future<void> openParkingReport(BuildContext context, Complex? c, {Lot? lot}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ReportPage(complex: c ?? complex.value, lot: lot)));

class _ReportPage extends StatefulWidget {
  final Complex? complex;
  final Lot? lot;
  const _ReportPage({this.complex, this.lot});
  @override
  State<_ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<_ReportPage> {
  late final name = TextEditingController(text: widget.lot?.name ?? '');
  final addr = TextEditingController();
  final text = TextEditingController();
  final contact = TextEditingController();
  bool sending = false;

  @override
  Widget build(BuildContext context) {
    final fix = widget.lot != null;
    return FormPage(
      title: fix ? '주차장 정보가 틀려요' : '주차장 알려 주기',
      lead: fix ? '요금·운영시간·위치 중 다른 곳을 적어 주세요. 확인한 뒤 고쳐 둘게요.' : '목록에 없는 주차장을 알려 주세요. 이름과 위치만 있어도 돼요. 확인한 뒤 지도에 올려 둘게요.',
      button: '보내기',
      sending: sending,
      onSend: _send,
      children: [
        Field('주차장 이름', name, need: true, max: 60),
        if (!fix) Field('위치 (주소나 건물 이름)', addr, hint: '예: ○○마트 지하, 송도동 ○○번지', max: 100),
        Field(fix ? '틀린 곳' : '요금·운영시간 (아는 만큼)', text, hint: fix ? '예: 요금이 30분 1,000원으로 올랐어요' : '예: 30분 무료, 이후 10분 500원', lines: 3, max: 300),
        Field('연락처 (선택)', contact, hint: '답을 받고 싶으면 적어 주세요', max: 60),
      ],
    );
  }

  Future<void> _send() async {
    if (name.text.trim().isEmpty) {
      toast(context, '주차장 이름을 적어 주세요');
      return;
    }
    setState(() => sending = true);
    final ok = await sendRequest({
      'kind': 'fix',
      'cat': 'parking',
      'sid': widget.lot?.id ?? 'parking_new',
      'sname': name.text.trim(),
      'area': widget.complex?.areaId ?? '',
      if (addr.text.trim().isNotEmpty) 'addr': addr.text.trim(),
      'text': text.text.trim(),
      'contact': contact.text.trim(),
    });
    if (!mounted) return;
    setState(() => sending = false);
    toast(context, ok ? '고마워요. 확인한 뒤 반영할게요' : '보내지 못했어요. 잠시 뒤 다시 해 주세요');
    if (ok) Navigator.pop(context);
  }
}

// 지도 탭용 점
Future<List<MapPoint>> parkingPoints(Complex c) async {
  final v = await lotsNear(c.pos, km: 2);
  final now = DateTime.now();
  return [
    for (final l in v.take(200))
      MapPoint(id: 'parking_${l.id}', name: l.name, sub: l.label, badge: l.freeAt(now) ? '무료' : l.badge, pos: l.pos, onTap: (ctx) => showLot(ctx, l, c.pos)),
  ];
}

// 가게 화면 연결용 한 줄: 「근처 주차장 ○곳 · 가장 싼 곳 30분 ○원」 (본부가 가게 화면에 붙임 — 요청 파일 참고)
Future<String?> parkingHint(LatLng p) async {
  final v = await lotsNear(p, km: 0.5);
  if (v.isEmpty) return null;
  final now = DateTime.now();
  if (v.any((l) => l.freeAt(now))) return '근처 주차장 ${v.length}곳 · 지금 무료인 곳 있어요';
  final priced = v.where((l) => l.basicMin > 0 && l.basicWon > 0).toList()..sort((a, b) => a.hourCost.compareTo(b.hourCost));
  if (priced.isEmpty) return '근처 주차장 ${v.length}곳';
  return '근처 주차장 ${v.length}곳 · 가장 싼 곳 ${priced.first.basicMin}분 ${won(priced.first.basicWon)}';
}

void openParkingNear(BuildContext context, LatLng p, String name) {
  final c = complex.value;
  if (c == null) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParkingPage(complex: c, at: p, atName: name)));
}
