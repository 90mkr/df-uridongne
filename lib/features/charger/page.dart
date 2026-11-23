// 충전소 상세 화면 · 충전소 창 (이 폴더는 충전소 담당 방만 고침)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _busy = Color(0xFF4A4E58); // 충전 중
const _offBg = Color(0xFFEDEEF1); // 멈춤·모름

class ChargerPage extends StatefulWidget {
  final Complex complex;
  const ChargerPage({super.key, required this.complex});
  @override
  State<ChargerPage> createState() => _ChargerPageState();
}

class _ChargerPageState extends State<ChargerPage> {
  StationSet? set;
  bool loading = true;
  bool? fast; // null 전체 · true 급속 · false 완속
  bool freeFirst = false;
  bool openOnly = false;
  bool mapView = false;
  double radius = 2000;

  Complex get c => widget.complex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await stationsOf(c.areaId);
    if (!mounted) return;
    // 2km 안에 충전소가 적으면 5km까지 넓힌다
    final near2 = s.all.where((x) => meters(c.pos, x.pos) <= 2000).length;
    setState(() {
      set = s;
      loading = false;
      radius = near2 >= 5 ? 2000 : 5000;
    });
    _live();
  }

  Future<void> _live() async {
    if (!canLive) return;
    await refreshMany(items, max: 14);
    if (mounted) setState(() {});
  }

  bool _isHome(Station s) => meters(c.pos, s.pos) <= 250 && (s.kind == '공동주택' || s.name.contains(c.name.split(' ').first));

  List<Station> get items {
    final all = set?.all ?? const <Station>[];
    var list = all.where((s) => meters(c.pos, s.pos) <= radius && s.of(fast).isNotEmpty).toList();
    if (openOnly) list = list.where((s) => !s.limited).toList();
    final d = {for (final s in list) s.id: meters(c.pos, s.pos)};
    list.sort((a, b) {
      if (freeFirst) {
        final fa = a.freeOf(fast) > 0 ? 0 : 1, fb = b.freeOf(fast) > 0 ? 0 : 1;
        if (fa != fb) return fa.compareTo(fb);
      }
      return d[a.id]!.compareTo(d[b.id]!);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return DetailPage(
      title: '전기차 충전소',
      icon: 'charger',
      white: false,
      actions: [
        TextButton(
          onPressed: () => setState(() => mapView = !mapView),
          child: Text(mapView ? '목록' : '지도', style: const TextStyle(fontSize: 13.5, color: kInk, fontWeight: FontWeight.w600)),
        ),
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (set?.all.isEmpty ?? true)
              ? _empty()
              : Column(children: [
                  _filters(),
                  Expanded(child: mapView ? _map(list) : _list(list)),
                ]),
    );
  }

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LineIcon('charger', size: 54, fill: kSoftGreen),
            SizedBox(height: 14),
            Text('이 동네 충전소 자료를 모으고 있어요', style: T.h2, textAlign: TextAlign.center),
            SizedBox(height: 6),
            Text('환경부 충전소 정보를 받아 오면 가까운 충전소와\n충전기별 빈자리를 보여 드려요.', textAlign: TextAlign.center, style: T.small),
          ]),
        ),
      );

  Widget _filters() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in const [(null, '전체'), (true, '급속'), (false, '완속')]) ...[
              ChoiceChipBox(f.$2, on: fast == f.$1, onTap: () => setState(() => fast = f.$1)),
              const SizedBox(width: 6),
            ],
            Container(width: 1, height: 18, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 6)),
            ChoiceChipBox('빈 곳 먼저', on: freeFirst, onTap: () => setState(() => freeFirst = !freeFirst)),
            const SizedBox(width: 6),
            ChoiceChipBox('누구나 이용', on: openOnly, onTap: () => setState(() => openOnly = !openOnly)),
          ]),
        ),
      );

  Widget _list(List<Station> list) {
    final home = list.where(_isHome).firstOrNull;
    final rest = [for (final s in list) if (s != home) s];
    final freeFast = list.fold<int>(0, (n, s) => n + s.freeOf(true));
    final freeSlow = list.fold<int>(0, (n, s) => n + s.freeOf(false));
    final near = list.where((s) => s.freeOf(fast) > 0).toList()..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    return RefreshIndicator(
      onRefresh: _live,
      child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
        _summary(list.length, freeFast, freeSlow, near.firstOrNull),
        const SizedBox(height: 14),
        if (home != null) ...[
          const Padding(padding: EdgeInsets.only(left: 2, bottom: 7), child: Text('우리 단지', style: T.title)),
          _StationCard(s: home, from: c, fast: fast, onTap: () => _open(home)),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.only(left: 2, bottom: 7), child: Text('가까운 충전소 ${rest.length}곳', style: T.title)),
        ],
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text('조건에 맞는 충전소가 없어요.\n위 고르기를 바꿔 보세요.', textAlign: TextAlign.center, style: T.small),
          ),
        for (final s in rest) ...[
          _StationCard(s: s, from: c, fast: fast, onTap: () => _open(s)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        const _Legend(),
        const SizedBox(height: 10),
        Text(
          '환경부 전기차 충전소 정보 기준 · 운영기관 사정으로 상태가 늦거나 다를 수 있어요.'
          '${canLive ? '' : '\n지금 보이는 상태는 ${set?.updated ?? ''}에 모은 자료예요. 실시간 상태는 휴대폰 앱에서 보여요.'}',
          style: T.tiny,
        ),
      ]),
    );
  }

  Widget _summary(int count, int freeFast, int freeSlow, Station? nearest) => Container(
        decoration: cardBox(r: 16),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const MixTitle('지금', '비어 있는 충전기', size: 14),
            const Spacer(),
            Text('${c.name} ${distText(radius)} 안 · $count곳', style: T.tiny),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _big('급속', freeFast),
            Container(width: 1, height: 30, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _big('완속', freeSlow),
          ]),
          if (nearest != null) ...[
            const SizedBox(height: 11),
            InkWell(
              onTap: () => _open(nearest),
              child: Row(children: [
                const Text('가장 가까운 빈 곳', style: T.tiny),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('${nearest.name} · ${distText(meters(c.pos, nearest.pos))}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: kMute),
              ]),
            ),
          ],
        ]),
      );

  Widget _big(String label, int n) => Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w500)),
        const SizedBox(width: 7),
        Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: n > 0 ? kBlue : kMute, height: 1)),
        const SizedBox(width: 2),
        const Text('대', style: TextStyle(fontSize: 12, color: kSub)),
      ]);

  Widget _map(List<Station> list) => Stack(children: [
        DongneMap(
          center: c.pos,
          zoom: radius > 2000 ? 13.5 : 14.5,
          pinFill: kSoftGreen,
          points: [
            for (final s in list)
              MapPoint(
                id: s.id,
                name: '${s.name} · 빈 ${s.freeOf(fast)}/${s.of(fast).length}',
                pos: s.pos,
                onTap: (_) => _open(s),
              ),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: cardBox(r: 9),
            child: Text('핀을 한 번 누르면 이름, 한 번 더 누르면 충전기 상태', style: T.tiny),
          ),
        ),
      ]);

  Future<void> _open(Station s) async {
    await showStation(context, s, c);
    if (mounted) setState(() {});
  }
}

// ---------------- 충전소 카드 ----------------
class _StationCard extends StatelessWidget {
  final Station s;
  final Complex from;
  final bool? fast;
  final VoidCallback onTap;
  const _StationCard({required this.s, required this.from, required this.fast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mine = s.of(fast);
    final free = mine.where((x) => x.use == Use.free).length;
    final sub = [
      distText(meters(from.pos, s.pos)),
      if (s.owner.isNotEmpty) s.owner,
      if (s.parkFree) '주차 무료',
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
                ]),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$free', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: free > 0 ? kBlue : kMute)),
                  TextSpan(text: ' / ${mine.length}', style: const TextStyle(fontSize: 12, color: kSub)),
                ]),
              ),
            ]),
            const SizedBox(height: 9),
            if (fast != false && s.hasFast) _Row(label: '급속', list: s.of(true)),
            if (fast != false && s.hasFast && fast == null && s.hasSlow) const SizedBox(height: 6),
            if (fast != true && s.hasSlow) _Row(label: '완속', list: s.of(false)),
            if (s.limited) ...[
              const SizedBox(height: 8),
              Text('이용 제한 · ${s.limit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ],
          ]),
        ),
      ),
    );
  }
}

// 「급속 100kW ■■□□」 한 줄
class _Row extends StatelessWidget {
  final String label;
  final List<Charger> list;
  const _Row({required this.label, required this.list});
  @override
  Widget build(BuildContext context) {
    final kw = list.fold(0, (m, c) => c.kw > m ? c.kw : m);
    const show = 20;
    return Row(children: [
      SizedBox(
        width: 74,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (kw > 0) TextSpan(text: ' ${kw}kW', style: const TextStyle(color: kSub, fontWeight: FontWeight.w400)),
        ]), style: const TextStyle(fontSize: 11.5)),
      ),
      Expanded(
        child: Wrap(spacing: 3, runSpacing: 3, children: [
          for (final c in list.take(show)) _Dot(c.use),
          if (list.length > show) Text(' +${list.length - show}', style: T.tiny),
        ]),
      ),
    ]);
  }
}

class _Dot extends StatelessWidget {
  final Use u;
  final double size;
  const _Dot(this.u, {this.size = 11});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: switch (u) { Use.free => kBlue, Use.busy => _busy, Use.off => _offBg, Use.unknown => Colors.white },
          border: u == Use.unknown || u == Use.off ? Border.all(color: const Color(0xFFCDD0D6)) : null,
        ),
        child: u == Use.off ? CustomPaint(painter: _Slash()) : null,
      );
}

class _Slash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFA9ADB6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width - 2, 2), Offset(2, size.height - 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 4, children: [
        for (final e in const [(Use.free, '비어 있음'), (Use.busy, '충전 중'), (Use.off, '점검·중지'), (Use.unknown, '상태 모름')])
          Row(mainAxisSize: MainAxisSize.min, children: [_Dot(e.$1, size: 10), const SizedBox(width: 4), Text(e.$2, style: T.tiny)]),
      ]);
}

// ---------------- 충전소 창 (아래에서 올라옴) ----------------
Future<void> showStation(BuildContext context, Station s, Complex from) => showSheet(context, (ctx) => _StationSheet(s: s, from: from));

class _StationSheet extends StatefulWidget {
  final Station s;
  final Complex from;
  const _StationSheet({required this.s, required this.from});
  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  bool busy = false;
  Station get s => widget.s;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!canLive) return;
    setState(() => busy = true);
    await refreshStation(s);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = [...s.chargers]..sort((a, b) => a.fast != b.fast ? (a.fast ? -1 : 1) : a.id.compareTo(b.id));
    final free = s.freeOf(null);
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(s.name, style: T.h1)),
        const SizedBox(width: 10),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$free', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: free > 0 ? kBlue : kMute)),
          TextSpan(text: ' / ${s.chargers.length} 비어 있음', style: const TextStyle(fontSize: 12, color: kSub)),
        ])),
      ]),
      const SizedBox(height: 4),
      Text('${distText(meters(widget.from.pos, s.pos))} · ${s.addr}${s.detail.isNotEmpty ? ' (${s.detail})' : ''}', style: T.small),
      const SizedBox(height: 8),
      Wrap(spacing: 5, runSpacing: 5, children: [
        if (s.hasFast) Pill('급속 최대 ${s.maxKw}kW'),
        if (s.parkFree) const Pill('주차 무료'),
        if (s.kind.isNotEmpty) Pill(s.kind),
        if (s.limited) const Pill('이용 제한'),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Btn('길안내', icon: 'car', primary: true, onTap: () => startNav(context, name: s.name, lat: s.pos.latitude, lng: s.pos.longitude))),
        if (s.tel.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(child: Btn('운영기관 전화', onTap: () => callTel(s.tel))),
        ],
      ]),
      const SizedBox(height: 16),
      Row(children: [
        const Text('충전기', style: T.title),
        const Spacer(),
        Text(
          busy
              ? '상태 받는 중…'
              : s.liveAt != null
                  ? '방금 받은 상태'
                  : canLive
                      ? '모아 둔 자료 기준'
                      : '모아 둔 자료 기준 (실시간은 앱에서)',
          style: T.tiny,
        ),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
        child: Column(children: [
          for (var i = 0; i < list.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: i == 0 ? null : const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F1F4)))),
              child: Row(children: [
                _Dot(list[i].use, size: 10),
                const SizedBox(width: 8),
                SizedBox(width: 24, child: Text(list[i].id, style: const TextStyle(fontSize: 11.5, color: kSub))),
                Expanded(
                  child: Text('${list[i].fast ? '급속' : '완속'} ${typeText(list[i].type)}${list[i].kw > 0 ? ' · ${list[i].kw}kW' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(width: 8),
                Text(useText(list[i].stat),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: list[i].use == Use.free ? kBlue : (list[i].use == Use.busy ? kInk : kMute))),
                SizedBox(width: 52, child: Text(agoText(list[i].upd), textAlign: TextAlign.right, style: T.tiny)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      if (s.hours.isNotEmpty) _info('이용 시간', s.hours),
      if (s.owner.isNotEmpty) _info('운영기관', '${s.owner}${s.tel.isNotEmpty ? ' · ${s.tel}' : ''}'),
      if (s.limited) _info('이용 제한', s.limit),
      const SizedBox(height: 6),
      const Text('요금은 운영기관·회원카드마다 달라요. 고장 신고는 운영기관 전화로 해 주세요.', style: T.tiny),
    ]);
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 64, child: Text(k, style: T.small)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, height: 1.4))),
        ]),
      );
}
