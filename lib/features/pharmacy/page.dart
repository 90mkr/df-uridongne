// 지금 문 연 약국 — 상세 화면 · 약국 창 (이 폴더는 약국 담당 방만 고침)
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const kWarn = Color(0xFFC76A00); // 곧 닫음 (주황)
const _barOpen = Color(0xFFDCE6FD);
const _barSoon = Color(0xFFFFE3C2);
const _barOff = Color(0xFFEDEFF3);

enum _Filter { now, late, holiday, all }

const _filterNames = {_Filter.now: '지금 영업 중', _Filter.late: '밤 늦게까지', _Filter.holiday: '일요일·공휴일', _Filter.all: '전체'};

class PharmacyPage extends StatefulWidget {
  final Complex complex;
  const PharmacyPage({super.key, required this.complex});
  @override
  State<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  late Future<List<Place>> _f;
  Future<List<Place>>? _ers;
  Timer? _tick;
  var filter = _Filter.now;
  var mapView = false;
  var show = 20;

  Complex get c => widget.complex;

  @override
  void initState() {
    super.initState();
    _f = placesNear(c.pos, r: 5000);
    _ers = ersNear(c.pos);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  List<Place> _pick(List<Place> pharm, DateTime now) => switch (filter) {
        _Filter.now => pharm.where((p) => p.stateAt(now).open).toList(),
        _Filter.late => pharm.where((p) => p.lateAny).toList(),
        _Filter.holiday => pharm.where((p) => p.hasSunday || p.hasHoliday).toList(),
        _Filter.all => pharm,
      };

  @override
  Widget build(BuildContext context) => DetailPage(
        title: '지금 문 연 약국',
        icon: 'pharm',
        white: false,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => mapView = !mapView),
            icon: LineIcon(mapView ? 'list' : 'map', size: 20),
            label: Text(mapView ? '목록' : '지도', style: const TextStyle(fontSize: 13, color: kInk, fontWeight: FontWeight.w600)),
          ),
        ],
        body: FutureBuilder<List<Place>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            final now = DateTime.now();
            final all = snap.data ?? const <Place>[];
            final pharm = all.where((p) => p.isPharm).toList();
            final kids = all.where((p) => p.isKids).toList();
            final list = _pick(pharm, now);
            if (pharm.isEmpty) return _empty();
            if (mapView) return _map(list, now);
            return ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
              _chips(),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: MixTitle(_filterNames[filter]!, '5km 안 · ${list.length}곳', size: 16)),
                Text('지금 ${_hm(now)}${isHoliday(now) ? ' · 공휴일' : ''}', style: T.tiny),
              ]),
              const SizedBox(height: 10),
              if (list.isEmpty)
                _none(pharm, now)
              else ...[
                _Timeline(places: list.take(6).toList(), now: now),
                const SizedBox(height: 12),
                _Featured(place: list.first, complex: c, now: now),
                if (list.length > 1) ...[
                  const SizedBox(height: 12),
                  _rows(list.skip(1).take(show).toList(), now),
                  if (list.length - 1 > show)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Btn('더 보기 (${list.length - 1 - show}곳)', h: 40, onTap: () => setState(() => show += 30)),
                    ),
                ],
              ],
              const SizedBox(height: 22),
              _kidsSection(kids, now),
              const SizedBox(height: 22),
              _erSection(),
              const SizedBox(height: 22),
              _storeLink(),
              const SizedBox(height: 16),
              FutureBuilder<Map?>(
                future: loadMeta(),
                builder: (_, m) => Text(
                  '국립중앙의료원 자료${m.data?['updated'] != null ? ' (${'${m.data!['updated']}'.split(' ').first} 기준)' : ''} · 운영시간이 바뀌었을 수 있으니 가기 전에 전화로 확인해 주세요.',
                  style: T.tiny,
                ),
              ),
            ]);
          },
        ),
      );

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LineIcon('pharm', size: 54),
            SizedBox(height: 14),
            Text('약국 자료를 모으고 있어요', style: T.h2),
            SizedBox(height: 6),
            Text('곧 이 단지 둘레의 약국 운영시간이 보여요.', textAlign: TextAlign.center, style: T.small),
          ]),
        ),
      );

  Widget _chips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in _Filter.values) ...[
            ChoiceChipBox(_filterNames[f]!, on: filter == f, onTap: () => setState(() {
                  filter = f;
                  show = 20;
                })),
            const SizedBox(width: 6),
          ],
        ]),
      );

  Widget _none(List<Place> pharm, DateTime now) {
    // 지금 연 곳이 없으면 가장 빨리 여는 곳
    final soon = [...pharm]..removeWhere((p) => p.stateAt(now).next.isEmpty);
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(filter == _Filter.now ? '지금 문을 연 약국이 없어요' : '조건에 맞는 약국이 없어요', style: T.h2),
        const SizedBox(height: 4),
        const Text('급하면 아래 응급실이나 상비약 파는 편의점을 이용해 주세요.', style: T.small),
        if (filter == _Filter.now && soon.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final p in soon.take(3))
            _Row(place: p, complex: c, now: now, line: false),
        ],
      ]),
    );
  }

  Widget _rows(List<Place> list, DateTime now) => Container(
        decoration: cardBox(),
        child: Column(children: [
          for (var i = 0; i < list.length; i++) _Row(place: list[i], complex: c, now: now, line: i < list.length - 1),
        ]),
      );

  Widget _kidsSection(List<Place> kids, DateTime now) {
    // 지금 진료 중인 곳 먼저, 없으면 밤·휴일 진료하는 곳
    final open = kids.where((p) => p.stateAt(now).open).toList();
    final late = kids.where((p) => !p.stateAt(now).open && (p.lateAny || p.hasSunday || p.hasHoliday)).toList();
    final show = [...open, ...late].take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const MixTitle('아이가 아플 때', '소아청소년과', size: 15),
      const SizedBox(height: 4),
      Text(open.isNotEmpty ? '5km 안 지금 진료 중 ${open.length}곳' : '지금 진료 중인 곳이 없어 밤·휴일 진료하는 곳을 보여 드려요', style: T.small),
      const SizedBox(height: 10),
      if (show.isEmpty)
        Container(decoration: cardBox(), padding: const EdgeInsets.all(14), child: const Text('5km 안에 밤·휴일 진료 소아과 정보가 없어요.', style: T.small))
      else
        _rows(show, now),
    ]);
  }

  Widget _erSection() => FutureBuilder<List<Place>>(
        future: _ers,
        builder: (context, snap) {
          final ers = snap.data ?? const <Place>[];
          if (ers.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const MixTitle('응급실', '24시간', size: 15),
            const SizedBox(height: 4),
            const Text('밤늦게 크게 아프거나 다쳤을 때. 생명이 위급하면 119.', style: T.small),
            const SizedBox(height: 10),
            Container(
              decoration: cardBox(),
              child: Column(children: [
                for (var i = 0; i < ers.length; i++)
                  _InfoRow(
                    title: ers[i].name,
                    sub: [distText(meters(c.pos, ers[i].pos)), if (ers[i].div.isNotEmpty) ers[i].div].join(' · '),
                    tel: ers[i].tel2.isNotEmpty ? ers[i].tel2 : ers[i].tel,
                    line: i < ers.length - 1,
                    onTap: () => showPlace(context, ers[i], c),
                  ),
              ]),
            ),
          ]);
        },
      );

  Widget _storeLink() => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: () => showSheet(context, (ctx) => _StoreSheet(complex: c)),
          child: Ink(
            decoration: cardBox(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: const Row(children: [
              LineIcon('mart', size: 28, fill: kSoftYellow),
              SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('약국이 다 닫았을 땐', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('가까운 편의점 · 해열제·감기약·소화제 같은 상비약', style: T.tiny),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: kMute, size: 20),
            ]),
          ),
        ),
      );

  Widget _map(List<Place> list, DateTime now) => Stack(children: [
        DongneMap(
          center: c.pos,
          zoom: 15,
          pinFill: kSoftGreen,
          points: [
            for (final p in list.take(200))
              MapPoint(id: p.id, name: '${p.name} · ${_short(p.stateAt(now))}', pos: p.pos, onTap: (ctx) => showPlace(ctx, p, c)),
          ],
        ),
        Positioned(left: 12, right: 12, top: 12, child: _chips()),
      ]);
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _short(OpenState s) => s.open ? (s.closingSoon ? '${s.minsLeft}분 뒤 닫음' : s.untilText) : (s.next.isEmpty ? '문 닫음' : '${s.next} 열어요');

// 상태 한 줄: 「350m · 영업 중 · 밤 10시까지」
InlineSpan _status(Place p, Complex c, DateTime now) {
  final s = p.stateAt(now);
  final d = distText(meters(c.pos, p.pos));
  if (s.open && s.closingSoon) {
    return TextSpan(children: [
      TextSpan(text: '$d · '),
      TextSpan(text: '${s.minsLeft}분 뒤 닫음', style: const TextStyle(color: kWarn, fontWeight: FontWeight.w700)),
      TextSpan(text: ' · ${s.untilText}'),
    ]);
  }
  if (s.open) {
    return TextSpan(children: [
      TextSpan(text: '$d · '),
      const TextSpan(text: '영업 중', style: TextStyle(color: kInk, fontWeight: FontWeight.w700)),
      TextSpan(text: ' · ${s.untilText}'),
    ]);
  }
  return TextSpan(text: '$d · 문 닫음${s.next.isEmpty ? '' : ' · ${s.next} 열어요'}');
}

// ---------------- 오늘 영업시간 막대 ----------------
class _Timeline extends StatelessWidget {
  final List<Place> places;
  final DateTime now;
  const _Timeline({required this.places, required this.now});

  static const _from = 6 * 60, _to = 26 * 60; // 아침 6시 ~ 새벽 2시

  @override
  Widget build(BuildContext context) {
    final nowMin = now.hour * 60 + now.minute + (now.hour < 6 ? 1440 : 0);
    final idx = dayIdx(now.hour < 6 ? now.subtract(const Duration(days: 1)) : now);
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MixTitle('오늘 영업시간', '한눈에', size: 14),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          double x(int m) => ((m.clamp(_from, _to) - _from) / (_to - _from)) * w;
          const rowH = 24.0, gap = 6.0, top = 16.0;
          final h = top + places.length * (rowH + gap);
          return SizedBox(
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              for (final (m, t) in const [(6 * 60, '6시'), (12 * 60, '12시'), (18 * 60, '18시'), (24 * 60, '24시')]) ...[
                Positioned(left: x(m), top: top - 2, bottom: 0, child: Container(width: 1, color: const Color(0xFFF0F1F4))),
                Positioned(left: (x(m) - (m == _from ? 0 : 10)).clamp(0, w - 24), top: 0, child: Text(t, style: const TextStyle(fontSize: 10, color: kMute))),
              ],
              for (var i = 0; i < places.length; i++) _bar(places[i], i, idx, nowMin, x, top + i * (rowH + gap), rowH, w),
              if (nowMin >= _from && nowMin <= _to)
                Positioned(
                  left: x(nowMin) - 0.75,
                  top: top - 4,
                  bottom: 0,
                  child: Container(width: 1.5, color: kInk),
                ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        const Wrap(spacing: 12, runSpacing: 4, children: [
          _Legend(_barOpen, '영업 중'),
          _Legend(_barSoon, '1시간 안에 닫음'),
          _Legend(_barOff, '문 닫음'),
        ]),
      ]),
    );
  }

  Widget _bar(Place p, int i, int idx, int nowMin, double Function(int) x, double y, double h, double w) {
    final sp = p.span(idx);
    final s = p.stateAt(now);
    final color = s.open ? (s.closingSoon ? _barSoon : _barOpen) : _barOff;
    final label = sp == null ? '${p.name} · 오늘 쉼' : '${p.name} ${_hh(sp.$1)}–${_hh(sp.$2)}';
    if (sp == null) {
      return Positioned(left: 0, right: 0, top: y, height: h, child: Align(alignment: Alignment.centerLeft, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)));
    }
    final l = x(sp.$1), r = x(sp.$2);
    return Positioned(
      left: 0,
      right: 0,
      top: y,
      height: h,
      child: Stack(children: [
        Positioned(
          left: l,
          width: (r - l).clamp(6, w),
          top: 0,
          bottom: 0,
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(h / 2))),
        ),
        Positioned(
          left: (l + 9).clamp(0, w - 60),
          right: 0,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: s.open ? kInk : kSub, height: 1.1)),
          ),
        ),
      ]),
    );
  }

  static String _hh(int m) {
    final h = m ~/ 60, mm = m % 60;
    return mm == 0 ? '$h' : '$h:${mm.toString().padLeft(2, '0')}';
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend(this.color, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(text, style: T.tiny),
      ]);
}

// ---------------- 가장 가까운 한 곳 (크게) ----------------
class _Featured extends StatelessWidget {
  final Place place;
  final Complex complex;
  final DateTime now;
  const _Featured({required this.place, required this.complex, required this.now});

  @override
  Widget build(BuildContext context) {
    final p = place;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => showPlace(context, p, complex),
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.25)),
                  const SizedBox(height: 3),
                  Text.rich(_status(p, complex, now), style: T.small),
                ]),
              ),
              if (p.hasSunday || p.hasHoliday) ...[const SizedBox(width: 8), Pill(p.hasSunday && p.hasHoliday ? '일·공휴일 영업' : (p.hasSunday ? '일요일 영업' : '공휴일 영업'))],
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (p.tel.isNotEmpty) ...[Expanded(child: Btn('전화하기', icon: 'phone', primary: true, h: 40, onTap: () => callTel(p.tel))), const SizedBox(width: 8)],
              Expanded(child: Btn('길안내', icon: 'route', h: 40, onTap: () => startNav(context, name: p.name, lat: p.pos.latitude, lng: p.pos.longitude))),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ---------------- 목록 한 줄 ----------------
class _Row extends StatelessWidget {
  final Place place;
  final Complex complex;
  final DateTime now;
  final bool line;
  const _Row({required this.place, required this.complex, required this.now, required this.line});

  @override
  Widget build(BuildContext context) => _InfoRow(
        title: place.name,
        subSpan: _status(place, complex, now),
        tel: place.tel,
        line: line,
        onTap: () => showPlace(context, place, complex),
      );
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String sub;
  final InlineSpan? subSpan;
  final String tel;
  final bool line;
  final VoidCallback onTap;
  const _InfoRow({required this.title, this.sub = '', this.subSpan, required this.tel, required this.line, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
          decoration: BoxDecoration(border: line ? const Border(bottom: BorderSide(color: Color(0xFFECEDF1))) : null),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 2),
                Text.rich(subSpan ?? TextSpan(text: sub), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
              ]),
            ),
            if (tel.isNotEmpty)
              Semantics(
                button: true,
                label: '$title 전화',
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => callTel(tel),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: kLine)),
                    child: const LineIcon('phone', size: 20),
                  ),
                ),
              ),
          ]),
        ),
      );
}

// ---------------- 약국·병원 창 ----------------
Future<void> showPlace(BuildContext context, Place p, Complex c) => showSheet(context, (ctx) => _PlaceSheet(place: p, complex: c));

class _PlaceSheet extends StatelessWidget {
  final Place place;
  final Complex complex;
  const _PlaceSheet({required this.place, required this.complex});

  @override
  Widget build(BuildContext context) {
    final p = place, now = DateTime.now();
    final today = dayIdx(now);
    final kind = p.isEr ? '응급실' : (p.isKids ? '소아청소년과${p.div.isNotEmpty ? ' · ${p.div}' : ''}' : '약국');
    final tel = p.isEr && p.tel2.isNotEmpty ? p.tel2 : p.tel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.25)),
              const SizedBox(height: 4),
              if (p.isEr)
                Text('$kind · ${distText(meters(complex.pos, p.pos))}${p.div.isNotEmpty ? ' · ${p.div}' : ''}', style: T.small)
              else
                Text.rich(TextSpan(children: [TextSpan(text: '$kind · '), _status(p, complex, now)]), style: T.small),
            ]),
          ),
          LineIcon(p.isPharm ? 'pharm' : 'hosp', size: 38, fill: p.isPharm ? kSoftGreen : kSoft),
        ]),
        const SizedBox(height: 14),
        if (!p.isEr) ...[
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(
                      width: 52,
                      child: Text(kDayNames[i], style: TextStyle(fontSize: 12.5, fontWeight: i == today ? FontWeight.w800 : FontWeight.w400, color: i == today ? kInk : kSub)),
                    ),
                    Expanded(
                      child: Text(spanText(p.hours[i]),
                          style: TextStyle(fontSize: 12.5, fontWeight: i == today ? FontWeight.w700 : FontWeight.w400, color: p.hours[i].isEmpty ? kMute : kInk)),
                    ),
                    if (i == today) const Pill('오늘'),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('점심시간·임시 휴무는 반영되지 않아요. 가기 전에 전화로 확인해 주세요.', style: T.tiny),
          const SizedBox(height: 12),
        ],
        if (p.addr.isNotEmpty) ...[
          Text(p.addr, style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
          const SizedBox(height: 14),
        ],
        Row(children: [
          if (tel.isNotEmpty) ...[Expanded(child: Btn(p.isEr ? '응급실 전화' : '전화하기', icon: 'phone', primary: true, onTap: () => callTel(tel))), const SizedBox(width: 10)],
          Expanded(child: Btn('길안내', icon: 'route', primary: tel.isEmpty, onTap: () => startNav(context, name: p.name, lat: p.pos.latitude, lng: p.pos.longitude))),
        ]),
      ]),
    );
  }
}

// ---------------- 상비약 편의점 ----------------
class _StoreSheet extends StatelessWidget {
  final Complex complex;
  const _StoreSheet({required this.complex});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Store>>(
        future: storesNear(complex),
        builder: (context, snap) {
          final list = snap.data ?? const <Store>[];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MixTitle('상비약 파는', '편의점', size: 17),
              const SizedBox(height: 4),
              const Text('해열진통제·감기약·소화제·파스 같은 안전상비의약품을 팔아요. 가게마다 갖춘 약은 다를 수 있어요.', style: T.small),
              const SizedBox(height: 12),
              if (snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else if (list.isEmpty)
                const Text('이 동네 편의점 자료가 아직 없어요.', style: T.small)
              else
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                  child: Column(children: [
                    for (var i = 0; i < list.length; i++)
                      _InfoRow(
                        title: list[i].name,
                        sub: '${complex.name}에서 ${distText(meters(complex.pos, list[i].pos))}',
                        tel: list[i].tel,
                        line: i < list.length - 1,
                        onTap: () => startNav(context, name: list[i].name, lat: list[i].pos.latitude, lng: list[i].pos.longitude),
                      ),
                  ]),
                ),
            ]),
          );
        },
      );
}
