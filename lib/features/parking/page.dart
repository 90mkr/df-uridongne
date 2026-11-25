// 주차장 상세 화면 (이 폴더는 주차장 담당 방만 고침)
// 맨 위 「내 차 어디 댔지」 · 필터 줄(전체·지금 무료·공영·24시간) · 요금 말풍선 지도 · 아래 목록(가까운 순/싼 순, 줄마다 길안내)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/fb.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/remote.dart';
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
    final full = MediaQuery.of(context).size;
    final top = MediaQuery.of(context).padding.top;
    final now = DateTime.now();
    Widget inner(Widget w) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: w));
    final mapH = (mapBig ? full.height * 0.55 : full.height * 0.25).clamp(180.0, 620.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _page,
        body: Stack(children: [
          // 맨 위 파란 물결 (아래 끝은 바탕색으로 녹아 경계선이 없다)
          Positioned(left: 0, right: 0, top: 0, height: top + 190, child: const _WaveHead()),
          ListView(padding: EdgeInsets.only(top: top, bottom: 30), children: [
            inner(_title()),
            inner(Padding(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 0), child: CarBar(lots: all ?? const []))),
            inner(SizedBox(
              height: 58,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 4), children: [
                for (final k in const ['전체', '지금 무료', '공영', '24시간']) _chip(k, filter == k, () => setState(() => filter = k)),
              ]),
            )),
            inner(Padding(
              padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: mapH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDE6F3)),
                  boxShadow: const [BoxShadow(color: Color(0x0F1E3A6E), blurRadius: 16)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: all == null
                      ? Container(color: kBg)
                      : DongneMap(
                          key: ValueKey('$km$filter${from.latitude}$mapBig'),
                          center: from,
                          zoom: km == 1 ? 15 : (km == 2 ? 14 : (km == 3 ? 13.3 : 12.5)),
                          pinFill: _fill,
                          points: [
                            for (final l in list.take(300))
                              MapPoint(id: l.id, name: l.name, sub: l.label, badge: l.freeAt(now) ? '무료' : l.badge, pos: l.pos, onTap: (ctx) => showLot(ctx, l, from)),
                          ],
                        ),
                ),
              ),
            )),
            inner(Padding(
              padding: const EdgeInsets.fromLTRB(kPad - 4, 16, kPad - 4, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4EAF3)),
                  boxShadow: const [BoxShadow(color: Color(0x0D1E3A6E), blurRadius: 18)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _head(list.length),
                  Container(height: 1, color: const Color(0xFFEEF1F6)),
                  ..._rows(list, now),
                ]),
              ),
            )),
            inner(_foot()),
          ]),
        ]),
      ),
    );
  }

  // ← P 주차장                                   지도 크게
  Widget _title() => Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, kPad - 8, 6),
        child: Row(children: [
          IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 26, color: kInk)),
          Image.asset('assets/icons/parking.png', width: 34, height: 34),
          const SizedBox(width: 8),
          Flexible(
            child: Text(widget.atName == null ? '주차장' : '${widget.atName} 근처',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk)),
          ),
          const Spacer(),
          IconButton(
            tooltip: mapBig ? '지도 작게' : '지도 크게',
            onPressed: () => setState(() => mapBig = !mapBig),
            icon: Icon(mapBig ? Icons.view_agenda_outlined : Icons.map_outlined, size: 25, color: _navy),
          ),
        ]),
      );

  Widget _head(int n) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
        child: Row(children: [
          const Text('가까운 주차장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
          const SizedBox(width: 8),
          Text(all == null ? '' : '$n곳 · ', style: const TextStyle(fontSize: 13, color: kSub)),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => km = const {1: 2, 2: 3, 3: 5, 5: 1}[km]!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${km}km 안', style: const TextStyle(fontSize: 13, color: kSub)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kSub),
              ]),
            ),
          ),
          const Spacer(),
          _sort('가까운 순', !cheap, () => setState(() => cheap = false)),
          _sort('싼 순', cheap, () => setState(() => cheap = true)),
        ]),
      );

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? _navy : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: on ? _navy : const Color(0xFFD6E0EE))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: f,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              child: Text(t, style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w700 : FontWeight.w600, color: on ? Colors.white : _navy, letterSpacing: -0.3)),
            ),
          ),
        ),
      );

  Widget _sort(String t, bool on, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: on ? kInk : kMute)),
        ),
      );

  List<Widget> _rows(List<Lot> list, DateTime now) {
    if (all == null) return const [Padding(padding: EdgeInsets.all(30), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))];
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
          child: Column(children: [
            Image.asset('assets/icons/parking.png', width: 48, height: 48),
            const SizedBox(height: 10),
            Text(
              (all ?? const []).isEmpty ? '이 동네 주차장 정보를 아직 받지 못했어요' : '조건에 맞는 주차장이 없어요\n「${km}km 안」을 눌러 거리를 넓혀 보세요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kSub, height: 1.45),
            ),
          ]),
        ),
      ];
    }
    return [
      for (var i = 0; i < list.length; i++) ...[
        if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0xFFF0F2F6)),
        LotRow(lot: list[i], dist: meters(from, list[i].pos), now: now, onTap: () => showLot(context, list[i], from)),
      ],
    ];
  }

  Widget _foot() => Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => openParkingReport(context, widget.complex),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_location_alt_outlined, size: 18, color: _navy),
                SizedBox(width: 6),
                Text('빠진 주차장 알려 주기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '지자체가 공공데이터포털에 올린 공영 위주 자료예요${updated.isEmpty ? '' : ' ($updated 받음)'}. 「지금 무료」에는 노상 주차장의 요금 시간 밖(야간·주말)도 들어가요. 현장 안내를 함께 확인해 주세요.',
            style: const TextStyle(fontSize: 11, color: kMute, height: 1.45),
          ),
        ]),
      );
}

const _page = Color(0xFFF3F7FD); // 물결 그림 아래 끝 색에 맞춘 바탕
const _navy = Color(0xFF173A73); // 시안의 짙은 남색 (고른 칩·글자)
const _tile = Color(0xFFEAF1FF);

// 맨 위 파란 물결 그림: 아래 40%에서 바탕색으로 서서히 녹인다
class _WaveHead extends StatelessWidget {
  const _WaveHead();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: _page),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
              stops: [0, 0.6, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: artImage('assets/art/parking_head.jpg', fit: BoxFit.cover, alignment: const Alignment(0, -0.6), filterQuality: FilterQuality.medium),
          ),
        ]),
      );
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
    final info = [
      distText(dist),
      if (l.spaces > 0) '${l.spaces}면',
      if (open == false && !free) '지금 운영 안 함' else if (hrs.isNotEmpty) hrs,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          // P 칸
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _tile, borderRadius: BorderRadius.circular(13)),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3B82F6), Color(0xFF1D5FD8)]),
              ),
              child: const Text('P', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.3))),
                if (l.label.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF1F3F7), borderRadius: BorderRadius.circular(20)),
                    child: Text(l.label, style: const TextStyle(fontSize: 10.5, color: kSub, height: 1.3)),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _FeePill(free ? (l.isFree ? '무료' : '지금 무료') : l.feeShort, free: free),
                const SizedBox(width: 6),
                Flexible(child: Text(info, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kSub, letterSpacing: -0.2))),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Material(
            color: _tile,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => startNav(context, name: l.name, lat: l.lat, lng: l.lng),
              child: const SizedBox(width: 52, height: 40, child: Center(child: LineIcon('route', size: 22, line: kBlue))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FeePill extends StatelessWidget {
  final String text;
  final bool free;
  const _FeePill(this.text, {required this.free});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: free ? const Color(0xFFE3F5EA) : const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: free ? const Color(0xFF1E8A50) : const Color(0xFF3D4452), height: 1.35)),
      );
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
