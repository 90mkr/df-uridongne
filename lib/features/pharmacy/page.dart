// 지금 문 연 약국 — 상세 화면 · 지도 · 시각 고르기 · 연휴 · 약국 창 (이 폴더는 약국 담당 방만 고침)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

// 상태 색: 영업 중 초록 / 30분 안에 닫음 주황 「곧 마감」 / 닫음 회색
const kOpenC = Color(0xFF22A861); // 영업 중 (핀·점·막대)
const kOpenDark = Color(0xFF0E6B3A); // 영업 중 글자 (짙은 녹색)
const kOpenSoft = Color(0xFFE3F5EA); // 영업 중 알약 바탕
const kSoonC = Color(0xFFE58A00);
const kWarn = Color(0xFFC76A00); // 곧 마감 글자
const kOffC = Color(0xFFA3A8B1);
const _barOpen = kOpenC;
const _barSoon = Color(0xFFF29B1D);
const _barOff = Color(0xFFE6E8EC);
const kCallNote = '방문 전 전화 확인을 권해요';

Color stateColor(OpenState s) => !s.open ? kOffC : (s.closingSoon ? kSoonC : kOpenC);

enum PFilter { all, open, late }

String filterName(PFilter f, When w) => switch (f) {
      PFilter.all => '전체',
      PFilter.open => w.live ? '지금 영업 중' : '그 시각 영업 중',
      PFilter.late => '밤 10시 이후',
    };

List<Place> applyFilter(List<Place> pharm, PFilter f, When w) => switch (f) {
      PFilter.all => pharm,
      PFilter.open => pharm.where((p) => p.stateBy(w).open).toList(),
      PFilter.late => pharm.where((p) {
          final s = p.span(w.idx);
          return s != null && s.$2 > 22 * 60;
        }).toList(),
    };

// 상태 한 줄: 「350m · 영업 중 · 밤 10시까지」
InlineSpan statusSpan(Place p, Complex c, When w, {bool dist = true}) {
  final s = p.stateBy(w);
  final d = dist ? '${distText(meters(c.pos, p.pos))} · ' : '';
  if (s.open) {
    return TextSpan(children: [
      TextSpan(text: d),
      TextSpan(
          text: s.closingSoon ? '곧 마감 (${s.minsLeft}분)' : '영업 중',
          style: TextStyle(color: s.closingSoon ? kWarn : kOpenDark, fontWeight: FontWeight.w700)),
      TextSpan(text: ' · ${s.untilText}'),
    ]);
  }
  final when = s.next.isEmpty ? (s.todayNone ? ' · 그날 쉼' : '') : ' · ${s.next}${w.live ? '' : '에'} 열어요';
  return TextSpan(children: [TextSpan(text: d), const TextSpan(text: '닫음', style: TextStyle(color: kOffC, fontWeight: FontWeight.w700)), TextSpan(text: when)]);
}

class PharmacyPage extends StatefulWidget {
  final Complex complex;
  const PharmacyPage({super.key, required this.complex});
  @override
  State<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  late Future<List<Place>> _f;
  Timer? _tick;
  When? pick; // null 이면 지금
  var filter = PFilter.open;
  var mapView = false;
  var show = 20;

  Complex get c => widget.complex;
  When get w => pick ?? When.now();

  @override
  void initState() {
    super.initState();
    _f = placesNear(c.pos, r: 5000);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => mounted && pick == null ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final r = await showSheet<Object>(context, (ctx) => WhenSheet(current: pick));
    if (!mounted || r == null) return;
    setState(() {
      pick = r is When ? r : null;
      show = 20;
    });
  }

  Widget _controls({bool onMap = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _WhenChip(when: w, onTap: _pickWhen, onReset: pick == null ? null : () => setState(() => pick = null), onMap: onMap),
            const SizedBox(width: 8),
            for (final f in PFilter.values) ...[
              _Chip(filterName(f, w), on: filter == f, onMap: onMap, onTap: () => setState(() {
                    filter = f;
                    show = 20;
                  })),
              const SizedBox(width: 6),
            ],
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) => DetailPage(
        title: '지금 문 연 약국',
        icon: 'pharm',
        white: false,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => mapView = !mapView),
            icon: LineIcon(mapView ? 'list' : 'map', size: 20),
            label: Text(mapView ? '목록으로 보기' : '지도로 보기', style: const TextStyle(fontSize: 13, color: kInk, fontWeight: FontWeight.w600)),
          ),
        ],
        body: FutureBuilder<List<Place>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            final all = snap.data ?? const <Place>[];
            final pharm = all.where((p) => p.isPharm).toList();
            if (pharm.isEmpty) return const _Empty();
            final ww = w;
            final list = applyFilter(pharm, filter, ww);
            final openCount = pharm.where((p) => p.stateBy(ww).open).length;
            final run = ww.live ? holidayRun(ww.date!) : const <DateTime>[];
            if (mapView) {
              return _PharmMap(key: ValueKey('$filter-${pick?.label}'), places: list, complex: c, when: ww, controls: _controls(onMap: true));
            }
            return ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
              if (run.isNotEmpty) ...[
                _HolidayBanner(run: run, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HolidayPage(complex: c, run: run, places: pharm)))),
                const SizedBox(height: 14),
              ],
              _controls(),
              const SizedBox(height: 16),
              _Summary(openCount: openCount, listCount: list.length, filter: filter, when: ww, nearest: pharm.where((p) => p.stateBy(ww).open).firstOrNull, complex: c),
              const SizedBox(height: 6),
              const Row(children: [Icon(Icons.info_outline_rounded, size: 13, color: kMute), SizedBox(width: 4), Text(kCallNote, style: T.tiny)]),
              const SizedBox(height: 12),
              if (openCount == 0) ...[
                _AltBlock(complex: c, places: all, when: ww, strong: true),
                const SizedBox(height: 16),
              ],
              if (list.isEmpty)
                Container(
                  decoration: cardBox(),
                  padding: const EdgeInsets.all(16),
                  child: Text(filter == PFilter.late ? '밤 10시 넘어서까지 여는 약국이 5km 안에 없어요.' : '조건에 맞는 약국이 없어요.', style: T.small),
                )
              else ...[
                _Timeline(places: list.take(6).toList(), when: ww),
                const SizedBox(height: 12),
                _Featured(place: list.first, complex: c, when: ww),
                if (list.length > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: cardBox(),
                    child: Column(children: [
                      for (final (i, p) in list.skip(1).take(show).indexed) PlaceRow(place: p, complex: c, when: ww, line: i < (list.length - 1).clamp(0, show) - 1),
                    ]),
                  ),
                  if (list.length - 1 > show)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Btn('더 보기 (${list.length - 1 - show}곳)', h: 40, onTap: () => setState(() => show += 30)),
                    ),
                ],
              ],
              if (openCount > 0) ...[
                const SizedBox(height: 24),
                _AltBlock(complex: c, places: all, when: ww, strong: false),
              ],
              const SizedBox(height: 16),
              FutureBuilder<Map?>(
                future: loadMeta(),
                builder: (_, m) => Text(
                  '국립중앙의료원 자료${m.data?['updated'] != null ? ' (${'${m.data!['updated']}'.split(' ').first} 기준)' : ''} · 점심시간·임시 휴무는 반영되지 않아요. $kCallNote.',
                  style: T.tiny,
                ),
              ),
            ]);
          },
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LineIcon('pharm', size: 54, fill: kSoftGreen),
            SizedBox(height: 14),
            Text('약국 자료를 모으고 있어요', style: T.h2),
            SizedBox(height: 6),
            Text('곧 이 단지 둘레의 약국 운영시간이 보여요.', textAlign: TextAlign.center, style: T.small),
          ]),
        ),
      );
}

// ---------------- 위쪽 칩 ----------------
class _Chip extends StatelessWidget {
  final String text;
  final bool on, onMap;
  final VoidCallback onTap;
  const _Chip(this.text, {required this.on, required this.onTap, this.onMap = false});
  @override
  Widget build(BuildContext context) => Material(
        color: on ? const Color(0xFFEEF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(9),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: on ? kBlue : kLine), boxShadow: onMap ? kShadow : null),
            child: Text(text, style: TextStyle(fontSize: 13, color: on ? kBlue : kInk, fontWeight: FontWeight.w500)),
          ),
        ),
      );
}

class _WhenChip extends StatelessWidget {
  final When when;
  final VoidCallback onTap;
  final VoidCallback? onReset;
  final bool onMap;
  const _WhenChip({required this.when, required this.onTap, this.onReset, this.onMap = false});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: when.live ? Colors.white : kInk,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: when.live ? kLine : kInk),
          boxShadow: onMap ? kShadow : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, size: 15, color: when.live ? kSub : Colors.white),
                const SizedBox(width: 5),
                Text(when.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: when.live ? kInk : Colors.white)),
                Icon(Icons.expand_more_rounded, size: 17, color: when.live ? kSub : Colors.white),
              ]),
            ),
          ),
          if (onReset != null)
            InkWell(
              onTap: onReset,
              child: const Padding(padding: EdgeInsets.fromLTRB(2, 8, 10, 8), child: Icon(Icons.close_rounded, size: 16, color: Colors.white)),
            ),
        ]),
      );
}

// ---------------- 연휴 알림 ----------------
class _HolidayBanner extends StatelessWidget {
  final List<DateTime> run;
  final VoidCallback onTap;
  const _HolidayBanner({required this.run, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(kRadius)),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              LineIcon('pharm', size: 30, line: Colors.white, fill: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const MixTitle('연휴에', '문 여는 약국', size: 15, color: Colors.white),
                  const SizedBox(height: 2),
                  Text('${dateText(run.first)} ~ ${dateText(run.last)} · 날짜별로 보기', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
            ]),
          ),
        ),
      );
}

class HolidayPage extends StatefulWidget {
  final Complex complex;
  final List<DateTime> run;
  final List<Place> places;
  const HolidayPage({super.key, required this.complex, required this.run, required this.places});
  @override
  State<HolidayPage> createState() => _HolidayPageState();
}

class _HolidayPageState extends State<HolidayPage> {
  var at = 0;
  @override
  Widget build(BuildContext context) {
    final d = widget.run[at];
    final idx = dayIdx(d);
    final c = widget.complex;
    final list = widget.places.where((p) => p.span(idx) != null).toList();
    final w = When.pick(idx, 12 * 60);
    return DetailPage(
      title: '연휴에 문 여는 약국',
      icon: 'pharm',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < widget.run.length; i++) ...[
              _Chip('${dateText(widget.run[i])}${isHoliday(widget.run[i]) ? ' 공휴일' : ''}', on: i == at, onTap: () => setState(() => at = i)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        MixTitle(dateText(d), '문 여는 약국 · ${list.length}곳', size: 16),
        const SizedBox(height: 4),
        const Text('약국이 신고한 공휴일·주말 운영시간이에요. 명절엔 바뀌는 곳이 많으니 꼭 전화로 확인해 주세요.', style: T.tiny),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Container(decoration: cardBox(), padding: const EdgeInsets.all(16), child: const Text('5km 안에 이날 연다고 알려진 약국이 없어요. 아래 응급실·편의점을 이용해 주세요.', style: T.small))
        else
          Container(
            decoration: cardBox(),
            child: Column(children: [
              for (final (i, p) in list.take(40).indexed)
                PlaceRow(place: p, complex: c, when: w, line: i < list.take(40).length - 1, hoursOf: idx),
            ]),
          ),
        const SizedBox(height: 24),
        _AltBlock(complex: c, places: widget.places, when: w, strong: false, showStores: true),
      ]),
    );
  }
}

// ---------------- 약국이 모두 닫았을 때 ----------------
class _AltBlock extends StatelessWidget {
  final Complex complex;
  final List<Place> places;
  final When when;
  final bool strong;
  final bool showStores;
  const _AltBlock({required this.complex, required this.places, required this.when, required this.strong, this.showStores = true});

  @override
  Widget build(BuildContext context) {
    final c = complex;
    final kids = places.where((p) => p.isKids).toList();
    final kidsOpen = kids.where((p) => p.stateBy(when).open).length;
    Widget row(String icon, Color fill, String title, String sub, VoidCallback onTap, bool line) => InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(border: line ? const Border(bottom: BorderSide(color: Color(0xFFECEDF1))) : null),
            child: Row(children: [
              LineIcon(icon, size: 28, fill: fill),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: kMute, size: 20),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MixTitle(strong ? (when.live ? '지금 문 연 약국이 없어요' : '그 시각엔 문 연 약국이 없어요') : '약국이 모두 닫았을 때', strong ? '' : '대안', size: 15),
      const SizedBox(height: 4),
      Text(strong ? '급하면 아래를 이용해 주세요. 생명이 위급하면 119.' : '밤늦게나 연휴에 약국이 다 닫았다면.', style: T.small),
      const SizedBox(height: 10),
      Container(
        decoration: cardBox(),
        child: Column(children: [
          if (showStores)
            row('mart', kSoftYellow, '안전상비의약품 파는 편의점', '해열제·소화제 등 · 24시간 편의점 위주', () => showSheet(context, (ctx) => _StoreSheet(complex: c)), true),
          row('kids', kSoft, '야간·휴일 소아과', kidsOpen > 0 ? '5km 안 지금 진료 중 $kidsOpen곳' : '밤·휴일 진료하는 소아청소년과', () => showSheet(context, (ctx) => _KidsSheet(complex: c, kids: kids, when: when)), true),
          row('hosp', kSoftOrange, '가까운 응급실', '24시간 · 응급실 직통 전화', () => showSheet(context, (ctx) => _ErSheet(complex: c)), false),
        ]),
      ),
    ]);
  }
}

// ---------------- 오늘 영업시간 막대 ----------------
class _Timeline extends StatelessWidget {
  final List<Place> places;
  final When when;
  const _Timeline({required this.places, required this.when});

  static const _from = 6 * 60, _to = 26 * 60; // 아침 6시 ~ 새벽 2시

  @override
  Widget build(BuildContext context) {
    final early = when.min < 6 * 60 && when.prevIdx >= 0;
    final nowMin = when.min + (early ? 1440 : 0);
    final idx = early ? when.prevIdx : when.idx;
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MixTitle(when.live ? '오늘 영업시간' : '그날 영업시간', '한눈에', size: 14),
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
                Positioned(left: (x(m) - (m == _from ? 0 : 10)).clamp(0.0, w > 24 ? w - 24 : 0.0), top: 0, child: Text(t, style: const TextStyle(fontSize: 10, color: kMute))),
              ],
              for (var i = 0; i < places.length; i++) _bar(places[i], idx, x, top + i * (rowH + gap), rowH, w),
              if (nowMin >= _from && nowMin <= _to)
                Positioned(left: x(nowMin) - 0.75, top: top - 4, bottom: 0, child: Container(width: 1.5, color: kInk)),
            ]),
          );
        }),
        const SizedBox(height: 6),
        const Wrap(spacing: 12, runSpacing: 4, children: [
          _Legend(kOpenC, '영업 중'),
          _Legend(kSoonC, '곧 마감 (30분 안)'),
          _Legend(kOffC, '닫음'),
        ]),
      ]),
    );
  }

  Widget _bar(Place p, int idx, double Function(int) x, double y, double h, double w) {
    final sp = p.span(idx);
    final s = p.stateBy(when);
    final color = s.open ? (s.closingSoon ? _barSoon : _barOpen) : _barOff;
    final label = sp == null ? '${p.name} · 쉼' : '${p.name} ${_hh(sp.$1)}–${_hh(sp.$2)}';
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
          width: (r - l).clamp(6.0, w > 6 ? w : 6.0),
          top: 0,
          bottom: 0,
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(h / 2))),
        ),
        Positioned(
          left: (l + 9).clamp(0.0, w > 60 ? w - 60 : 0.0),
          right: 0,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: s.open ? Colors.white : kSub, height: 1.1)),
          ),
        ),
      ]),
    );
  }

  static String _hh(int m) {
    final h = (m ~/ 60) % 24, mm = m % 60;
    return mm == 0 ? '$h' : '$h:${mm.toString().padLeft(2, '0')}';
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend(this.color, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: T.tiny),
      ]);
}

// ---------------- 가장 가까운 한 곳 (크게) ----------------
class _Featured extends StatelessWidget {
  final Place place;
  final Complex complex;
  final When when;
  const _Featured({required this.place, required this.complex, required this.when});

  @override
  Widget build(BuildContext context) {
    final p = place;
    final s = p.stateBy(when);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => showPlace(context, p, complex, when: when),
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: _Dot(stateColor(s), size: 9)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.25)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _StatePill(s),
                    const SizedBox(width: 8),
                    Flexible(child: Text('${distText(meters(complex.pos, p.pos))} · ${s.open ? s.untilText : (s.next.isEmpty ? '' : '${s.next} 열어요')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small)),
                  ]),
                ]),
              ),
              if (p.hasSunday || p.hasHoliday) ...[
                const SizedBox(width: 8),
                Pill(p.hasSunday && p.hasHoliday ? '일·공휴일 영업' : (p.hasSunday ? '일요일 영업' : '공휴일 영업')),
              ],
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (p.tel.isNotEmpty) ...[Expanded(child: Btn('전화하기', icon: 'phone', primary: true, h: 40, onTap: () => callTel(p.tel))), const SizedBox(width: 10)],
              Expanded(child: Btn('길안내', icon: 'route', h: 40, onTap: () => startNav(context, name: p.name, lat: p.pos.latitude, lng: p.pos.longitude))),
            ]),
          ]),
        ),
      ),
    );
  }
}

// 상태 알약: 영업 중(연녹 바탕·짙은 녹색 글자) / 곧 마감(주황) / 닫음(회색)
class _StatePill extends StatelessWidget {
  final OpenState s;
  const _StatePill(this.s);
  @override
  Widget build(BuildContext context) {
    final (bg, fg, t) = !s.open
        ? (const Color(0xFFF0F1F4), kSub, '닫음')
        : s.closingSoon
            ? (const Color(0xFFFFF0DC), kWarn, '곧 마감 ${s.minsLeft}분')
            : (kOpenSoft, kOpenDark, '영업 중');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: s.open ? (s.closingSoon ? kSoonC : kOpenC) : kOffC, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg, height: 1.2)),
      ]),
    );
  }
}

// 맨 위 요약: 지금 영업 중 ○곳 (초록 띠)
class _Summary extends StatelessWidget {
  final int openCount, listCount;
  final PFilter filter;
  final When when;
  final Place? nearest;
  final Complex complex;
  const _Summary({required this.openCount, required this.listCount, required this.filter, required this.when, required this.nearest, required this.complex});

  @override
  Widget build(BuildContext context) {
    final on = openCount > 0;
    final head = when.live ? '지금' : when.label;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: on ? const [Color(0xFF26B36A), Color(0xFF13924F)] : const [Color(0xFF5B606B), Color(0xFF3F434C)],
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$head${when.live && isHoliday(when.date!) ? ' · 공휴일' : ''}', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.82))),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: on ? '영업 중 ' : '문 연 약국 ', style: const TextStyle(fontWeight: FontWeight.w300)),
                TextSpan(text: on ? '$openCount' : '없음', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                if (on) const TextSpan(text: '곳', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
              style: const TextStyle(fontSize: 17, color: Colors.white, height: 1.15),
            ),
            const SizedBox(height: 4),
            Text(
              nearest != null ? '가장 가까운 곳 ${nearest!.name} · ${distText(meters(complex.pos, nearest!.pos))}' : '아래 응급실·편의점을 이용해 주세요',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          LineIcon('pharm', size: 44, line: Colors.white, fill: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 6),
          Text('5km 안 · ${filter == PFilter.all ? '전체 ' : ''}$listCount곳', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot(this.color, {this.size = 8});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ---------------- 목록 한 줄: 이름·상태 + 「전화하기」 「길안내」 ----------------
class PlaceRow extends StatelessWidget {
  final Place place;
  final Complex complex;
  final When when;
  final bool line;
  final int? hoursOf; // 이 요일 칸 운영시간을 상태 대신 보여 줌 (연휴 화면)
  const PlaceRow({super.key, required this.place, required this.complex, required this.when, required this.line, this.hoursOf});

  @override
  Widget build(BuildContext context) {
    final p = place;
    final s = p.stateBy(when);
    final sub = hoursOf != null
        ? TextSpan(text: '${distText(meters(complex.pos, p.pos))} · ${spanText(p.hours[hoursOf!])}')
        : statusSpan(p, complex, when);
    return InkWell(
      onTap: () => showPlace(context, p, complex, when: when),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(border: line ? const Border(bottom: BorderSide(color: Color(0xFFECEDF1))) : null),
        child: Row(children: [
          if (hoursOf == null) ...[_Dot(stateColor(s)), const SizedBox(width: 8)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 2),
              Text.rich(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 8),
          if (p.tel.isNotEmpty) ...[_MiniBtn('전화하기', onTap: () => callTel(p.tel)), const SizedBox(width: 6)],
          _MiniBtn('길안내', onTap: () => startNav(context, name: p.name, lat: p.pos.latitude, lng: p.pos.longitude)),
        ]),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _MiniBtn(this.text, {required this.onTap});
  @override
  Widget build(BuildContext context) {
    final call = text.startsWith('전화');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.fromLTRB(7, 0, 10, 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: call ? kOpenSoft : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: call ? const Color(0xFFBFE6CE) : const Color(0xFFD5D9E0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          LineIcon(call ? 'phone' : 'route', size: 17, line: call ? kOpenDark : kInk, fill: call ? Colors.white : kSoft),
          const SizedBox(width: 3),
          Text(call ? '전화' : '길안내', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: call ? kOpenDark : kInk)),
        ]),
      ),
    );
  }
}

// ---------------- 지도로 보기 ----------------
class _PharmMap extends StatefulWidget {
  final List<Place> places;
  final Complex complex;
  final When when;
  final Widget controls;
  const _PharmMap({super.key, required this.places, required this.complex, required this.when, required this.controls});
  @override
  State<_PharmMap> createState() => _PharmMapState();
}

class _PharmMapState extends State<_PharmMap> {
  String? sel;

  @override
  Widget build(BuildContext context) {
    final c = widget.complex, w = widget.when;
    final list = widget.places.take(300).toList();
    final picked = list.where((p) => p.id == sel).firstOrNull;
    // 닫은 곳 → 곧 마감 → 영업 중 → 고른 곳 순으로 쌓아 중요한 것이 위에
    int rank(Place p) {
      if (p.id == sel) return 9;
      final s = p.stateBy(w);
      return !s.open ? 0 : (s.closingSoon ? 1 : 2);
    }

    final order = [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: c.pos,
          initialZoom: 15,
          // 단지와 가까운 약국 몇 곳이 한 화면에 들어오게
          initialCameraFit: list.isEmpty
              ? null
              : CameraFit.coordinates(coordinates: [c.pos, for (final p in list.take(8)) p.pos], padding: const EdgeInsets.fromLTRB(40, 120, 40, 170), maxZoom: 16, forceIntegerZoomLevel: true),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onTap: (_, __) => setState(() => sel = null),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
          MarkerLayer(markers: [
            Marker(
              point: c.pos,
              width: 130,
              height: 46,
              alignment: Alignment.topCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(14)),
                  child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                const SizedBox(height: 2),
                const LineIcon('apt', size: 20),
              ]),
            ),
            for (final p in order)
              Marker(
                point: p.pos,
                width: p.id == sel ? 160 : 30,
                height: p.id == sel ? 64 : 36,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => setState(() => sel = p.id),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (p.id == sel)
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: cardBox(r: 9),
                        child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    _Pin(color: stateColor(p.stateBy(w)), on: p.id == sel),
                  ]),
                ),
              ),
          ]),
          const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
        ],
      ),
      Positioned(left: 12, right: 12, top: 12, child: widget.controls),
      Positioned(
        left: 12,
        right: 12,
        bottom: 14,
        child: picked != null
            ? _PickCard(place: picked, complex: c, when: w)
            : Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: cardBox(r: 20),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const _Dot(kOpenC),
                    const Text(' 영업 중  ', style: T.tiny),
                    const _Dot(kSoonC),
                    const Text(' 곧 마감  ', style: T.tiny),
                    const _Dot(kOffC),
                    Text(' 닫음 · ${list.length}곳 · $kCallNote', style: T.tiny),
                  ]),
                ),
              ),
      ),
    ]);
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  final bool on;
  const _Pin({required this.color, required this.on});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(on ? 30 : 24, on ? 36 : 30), painter: _PinPainter(color));
}

class _PinPainter extends CustomPainter {
  final Color color;
  _PinPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final path = Path()
      ..moveTo(r, s.height)
      ..quadraticBezierTo(r * 0.25, s.height * 0.62, 0.6, r)
      ..arcToPoint(Offset(s.width - 0.6, r), radius: Radius.circular(r - 0.6))
      ..quadraticBezierTo(s.width - r * 0.25, s.height * 0.62, r, s.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 1.5, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    // 가운데 흰 십자 (약국)
    final cx = r, cy = r, a = r * 0.42, t = r * 0.16;
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: a * 2, height: t * 2), Radius.circular(t)), white);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: t * 2, height: a * 2), Radius.circular(t)), white);
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.color != color;
}

class _PickCard extends StatelessWidget {
  final Place place;
  final Complex complex;
  final When when;
  const _PickCard({required this.place, required this.complex, required this.when});
  @override
  Widget build(BuildContext context) {
    final p = place;
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => showPlace(context, p, complex, when: when),
          child: Row(children: [
            _Dot(stateColor(p.stateBy(when)), size: 9),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text.rich(statusSpan(p, complex, when), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
            const Text('운영시간', style: T.tiny),
            const Icon(Icons.chevron_right_rounded, color: kMute, size: 18),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (p.tel.isNotEmpty) ...[Expanded(child: Btn('전화하기', icon: 'phone', primary: true, h: 38, onTap: () => callTel(p.tel))), const SizedBox(width: 10)],
          Expanded(child: Btn('길안내', icon: 'route', h: 38, onTap: () => startNav(context, name: p.name, lat: p.pos.latitude, lng: p.pos.longitude))),
        ]),
        const SizedBox(height: 6),
        const Text(kCallNote, style: T.tiny),
      ]),
    );
  }
}

// ---------------- 시각 고르기 ----------------
class WhenSheet extends StatefulWidget {
  final When? current;
  const WhenSheet({super.key, this.current});
  @override
  State<WhenSheet> createState() => _WhenSheetState();
}

class _WhenSheetState extends State<WhenSheet> {
  late int idx, hour, half;

  @override
  void initState() {
    super.initState();
    final w = widget.current ?? When.now();
    idx = w.idx;
    hour = w.min ~/ 60;
    half = w.min % 60 >= 30 ? 30 : 0;
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String t, bool on, VoidCallback tap) => ChoiceChipBox(t, on: on, onTap: tap);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MixTitle('몇 시에', '여는 곳 미리 보기', size: 17),
        const SizedBox(height: 4),
        const Text('요일과 시각을 고르면 그때 문 여는 약국만 보여 드려요.', style: T.small),
        const SizedBox(height: 14),
        const Text('자주 찾는 때', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (t, i, h) in [('오늘 밤 10시', dayIdx(DateTime.now()), 22), ('토요일 저녁 7시', 5, 19), ('일요일 낮 12시', 6, 12), ('일요일 밤 11시', 6, 23), ('공휴일 낮 12시', 7, 12)])
            chip(t, false, () => Navigator.pop(context, When.pick(i, h * 60))),
        ]),
        const SizedBox(height: 16),
        const Text('요일', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < 8; i++) ...[chip(kDayNames[i], idx == i, () => setState(() => idx = i)), const SizedBox(width: 6)],
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Text('시각', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          chip('정각', half == 0, () => setState(() => half = 0)),
          const SizedBox(width: 6),
          chip('30분', half == 30, () => setState(() => half = 30)),
        ]),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.6,
          children: [
            for (var h = 0; h < 24; h++)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => hour = h),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: hour == h ? const Color(0xFFEEF3FF) : Colors.white,
                    border: Border.all(color: hour == h ? kBlue : kLine),
                  ),
                  child: Text('$h시', style: TextStyle(fontSize: 12.5, color: hour == h ? kBlue : kInk, fontWeight: hour == h ? FontWeight.w700 : FontWeight.w400)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Btn('지금으로', onTap: () => Navigator.pop(context, 'now'))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Btn('${idx == 7 ? '공휴일' : '${kDayNames[idx]}요일'} ${clockText(hour * 60 + half)} 보기', primary: true, onTap: () => Navigator.pop(context, When.pick(idx, hour * 60 + half))),
          ),
        ]),
      ]),
    );
  }
}

// ---------------- 약국·병원 창 ----------------
Future<void> showPlace(BuildContext context, Place p, Complex c, {When? when}) => showSheet(context, (ctx) => _PlaceSheet(place: p, complex: c, when: when ?? When.now()));

class _PlaceSheet extends StatelessWidget {
  final Place place;
  final Complex complex;
  final When when;
  const _PlaceSheet({required this.place, required this.complex, required this.when});

  @override
  Widget build(BuildContext context) {
    final p = place;
    final today = when.idx;
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
                Text.rich(TextSpan(children: [TextSpan(text: '$kind · '), statusSpan(p, complex, when)]), style: T.small),
            ]),
          ),
          LineIcon(p.isPharm ? 'pharm' : (p.isKids ? 'kids' : 'hosp'), size: 38, fill: p.isPharm ? kSoftGreen : kSoft),
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
                    if (i == today) Pill(when.live ? '오늘' : '고른 날'),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('점심시간·임시 휴무는 반영되지 않아요.', style: T.tiny),
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
        const SizedBox(height: 8),
        const Center(child: Text(kCallNote, style: T.tiny)),
      ]),
    );
  }
}

// ---------------- 대안 창들 ----------------
class _SheetList extends StatelessWidget {
  final String bold, thin, lead;
  final Widget child;
  const _SheetList({required this.bold, required this.thin, required this.lead, required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          MixTitle(bold, thin, size: 17),
          const SizedBox(height: 4),
          Text(lead, style: T.small),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 8),
          const Center(child: Text(kCallNote, style: T.tiny)),
        ]),
      );
}

class _SimpleRow extends StatelessWidget {
  final String title, sub, tel;
  final double lat, lng;
  final bool line;
  final VoidCallback? onTap;
  const _SimpleRow({required this.title, required this.sub, required this.tel, required this.lat, required this.lng, required this.line, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(border: line ? const Border(bottom: BorderSide(color: Color(0xFFECEDF1))) : null),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 8),
            if (tel.isNotEmpty) ...[_MiniBtn('전화하기', onTap: () => callTel(tel)), const SizedBox(width: 6)],
            _MiniBtn('길안내', onTap: () => startNav(context, name: title, lat: lat, lng: lng)),
          ]),
        ),
      );
}

class _StoreSheet extends StatelessWidget {
  final Complex complex;
  const _StoreSheet({required this.complex});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Store>>(
        future: storesNear(complex),
        builder: (context, snap) {
          final list = snap.data ?? const <Store>[];
          return _SheetList(
            bold: '안전상비의약품',
            thin: '파는 편의점',
            lead: '해열제·소화제 등 안전상비의약품을 파는 편의점이에요. 24시간 편의점 위주로, 가게마다 갖춘 약은 다를 수 있어요.',
            child: snap.connectionState != ConnectionState.done
                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : list.isEmpty
                    ? const Text('이 동네 편의점 자료가 아직 없어요.', style: T.small)
                    : Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                        child: Column(children: [
                          for (var i = 0; i < list.length; i++)
                            _SimpleRow(
                              title: list[i].name,
                              sub: '${complex.name}에서 ${distText(meters(complex.pos, list[i].pos))}${list[i].allDay ? ' · 24시간' : ''}',
                              tel: list[i].tel,
                              lat: list[i].pos.latitude,
                              lng: list[i].pos.longitude,
                              line: i < list.length - 1,
                            ),
                        ]),
                      ),
          );
        },
      );
}

class _KidsSheet extends StatelessWidget {
  final Complex complex;
  final List<Place> kids;
  final When when;
  const _KidsSheet({required this.complex, required this.kids, required this.when});
  @override
  Widget build(BuildContext context) {
    final open = kids.where((p) => p.stateBy(when).open).toList();
    final late = kids.where((p) => !p.stateBy(when).open && (p.lateAny || p.hasSunday || p.hasHoliday)).toList();
    final list = [...open, ...late].take(12).toList();
    return _SheetList(
      bold: '야간·휴일',
      thin: '소아과',
      lead: open.isNotEmpty ? '5km 안 소아청소년과 중 ${when.live ? '지금' : '그 시각'} 진료 중인 곳부터 보여 드려요.' : '${when.live ? '지금' : '그 시각'} 진료 중인 곳이 없어 밤·휴일에 진료하는 곳을 보여 드려요.',
      child: list.isEmpty
          ? const Text('5km 안에 밤·휴일 진료 소아과 정보가 없어요. 아이가 많이 아프면 가까운 응급실로 가 주세요.', style: T.small)
          : Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
              child: Column(children: [
                for (var i = 0; i < list.length; i++) PlaceRow(place: list[i], complex: complex, when: when, line: i < list.length - 1),
              ]),
            ),
    );
  }
}

class _ErSheet extends StatelessWidget {
  final Complex complex;
  const _ErSheet({required this.complex});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Place>>(
        future: ersNear(complex.pos, n: 5),
        builder: (context, snap) {
          final list = snap.data ?? const <Place>[];
          return _SheetList(
            bold: '가까운',
            thin: '응급실',
            lead: '24시간 문을 여는 응급실이에요. 생명이 위급하면 바로 119에 전화해 주세요.',
            child: snap.connectionState != ConnectionState.done
                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : list.isEmpty
                    ? const Text('응급실 자료를 모으고 있어요.', style: T.small)
                    : Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                        child: Column(children: [
                          for (var i = 0; i < list.length; i++)
                            _SimpleRow(
                              title: list[i].name,
                              sub: [distText(meters(complex.pos, list[i].pos)), if (list[i].div.isNotEmpty) list[i].div].join(' · '),
                              tel: list[i].tel2.isNotEmpty ? list[i].tel2 : list[i].tel,
                              lat: list[i].pos.latitude,
                              lng: list[i].pos.longitude,
                              line: i < list.length - 1,
                              onTap: () => showPlace(context, list[i], complex),
                            ),
                        ]),
                      ),
          );
        },
      );
}
