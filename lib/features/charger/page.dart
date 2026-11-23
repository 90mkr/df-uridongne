// 충전소 상세 화면 · 충전소 창 · 내 차 · 타이머 · 고장 제보 (이 폴더는 충전소 담당 방만 고침)
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/me.dart' show openLogin;
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'watch.dart';

// 상태 색: 빈 충전기 있음 초록 · 모두 사용 중 주황 · 고장·점검 회색
const kFree = Color(0xFF1E9E5A);
const kBusy = Color(0xFFEF7D22);
const kOff = Color(0xFFA3A7B0);

enum Mode { all, fast, free }

// 충전소 한 곳의 상태 (고른 조건에 맞는 충전기 기준)
Color stationColor(List<Charger> list) {
  if (list.any((c) => c.use == Use.free)) return kFree;
  if (list.any((c) => c.use == Use.busy)) return kBusy;
  return kOff;
}

String stationWord(List<Charger> list) {
  if (list.any((c) => c.use == Use.free)) return '빈자리 있음';
  if (list.any((c) => c.use == Use.busy)) return '모두 사용 중';
  if (list.any((c) => c.use == Use.off)) return '고장·점검';
  return '상태 모름';
}

class ChargerPage extends StatefulWidget {
  final Complex complex;
  const ChargerPage({super.key, required this.complex});
  @override
  State<ChargerPage> createState() => _ChargerPageState();
}

class _ChargerPageState extends State<ChargerPage> {
  StationSet? set;
  bool loading = true;
  Mode mode = Mode.all;
  bool byFree = false; // false 가까운 순 · true 빈자리 많은 순
  bool openOnly = false;
  bool mapView = false;
  double radius = 2000;
  DateTime? liveAt;
  Timer? _auto;

  Complex get c => widget.complex;
  Set<String> get plugs => myPlugs.value;

  @override
  void initState() {
    super.initState();
    _load();
    // 화면을 보는 동안 2분마다 상태 새로 받기
    _auto = Timer.periodic(const Duration(minutes: 2), (_) => _live());
    myPlugs.addListener(_re);
    chargeTimer.addListener(_re);
    watches.addListener(_re);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindRoot(context);
  }

  @override
  void dispose() {
    _auto?.cancel();
    myPlugs.removeListener(_re);
    chargeTimer.removeListener(_re);
    watches.removeListener(_re);
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final first = await loadMyPlugs();
    await Future.wait([loadPrices(), loadTimer()]);
    final s = await stationsOf(c.areaId);
    if (!mounted) return;
    final near2 = s.all.where((x) => meters(c.pos, x.pos) <= 2000).length;
    setState(() {
      set = s;
      loading = false;
      radius = near2 >= 5 ? 2000 : 5000;
    });
    if (first && s.all.isNotEmpty) await showMyCar(context);
    _live();
  }

  Future<void> _live() async {
    if (!canLive) return;
    await refreshMany(items, max: 14);
    if (!mounted) return;
    setState(() => liveAt = DateTime.now());
  }

  List<Charger> mine(Station s) => s.pick(fastOnly: mode == Mode.fast, plugs: plugs);
  int freeN(Station s) => mine(s).where((x) => x.use == Use.free).length;

  bool _isHome(Station s) => meters(c.pos, s.pos) <= 250 && (s.kind == '공동주택' || s.name.contains(c.name.split(' ').first));

  List<Station> get items {
    final all = set?.all ?? const <Station>[];
    var list = all.where((s) => meters(c.pos, s.pos) <= radius && mine(s).isNotEmpty).toList();
    if (mode == Mode.free) list = list.where((s) => freeN(s) > 0).toList();
    if (openOnly) list = list.where((s) => !s.limited).toList();
    final d = {for (final s in list) s.id: meters(c.pos, s.pos)};
    list.sort((a, b) {
      if (byFree) {
        final x = freeN(b).compareTo(freeN(a));
        if (x != 0) return x;
      }
      return d[a.id]!.compareTo(d[b.id]!);
    });
    return list;
  }

  // 가까운 10곳 중 가장 싼 곳
  String? get cheapId {
    String? id;
    double? best;
    for (final s in items.take(10)) {
      final p = cheapest(s, mine(s));
      if (p != null && (best == null || p < best)) {
        best = p;
        id = s.id;
      }
    }
    return id;
  }

  String get basis {
    if (liveAt != null) {
      final m = DateTime.now().difference(liveAt!).inMinutes;
      return m < 1 ? '방금 받은 상태' : '$m분 전 기준';
    }
    return set?.updated.isNotEmpty == true ? '${set!.updated.substring(5)} 모은 자료 기준' : '';
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
          onPressed: () => showMyCar(context),
          child: const Text('내 차', style: TextStyle(fontSize: 13.5, color: kInk, fontWeight: FontWeight.w600)),
        ),
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
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: kLine))),
        padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in const [(Mode.all, '전체'), (Mode.fast, '급속만'), (Mode.free, '지금 빈 곳')]) ...[
                ChoiceChipBox(f.$2, on: mode == f.$1, onTap: () => setState(() => mode = f.$1)),
                const SizedBox(width: 6),
              ],
              Container(width: 1, height: 18, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 6)),
              ChoiceChipBox('누구나 이용', on: openOnly, onTap: () => setState(() => openOnly = !openOnly)),
            ]),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => showMyCar(context),
            child: Row(children: [
              const LineIcon('car', size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  plugs.isEmpty ? '내 차 단자를 고르면 맞는 충전기만 보여 드려요' : '내 차 ${plugs.map(plugName).join('·')} 맞춤',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: kSub),
                ),
              ),
              const Text('  바꾸기', style: TextStyle(fontSize: 11.5, color: kBlue, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _list(List<Station> list) {
    final home = list.where(_isHome).firstOrNull;
    final rest = [for (final s in list) if (s != home) s];
    final cheap = cheapId;
    return RefreshIndicator(
      onRefresh: _live,
      child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
        if (chargeTimer.value != null) ...[_TimerCard(t: chargeTimer.value!), const SizedBox(height: 10)],
        for (final w in watches.value) ...[_WatchBar(w: w), const SizedBox(height: 8)],
        _summary(list),
        const SizedBox(height: 14),
        if (home != null) ...[
          const Padding(padding: EdgeInsets.only(left: 2, bottom: 7), child: Text('우리 단지', style: T.title)),
          _card(home, cheap),
          const SizedBox(height: 14),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Row(children: [
            Text('가까운 충전소 ${rest.length}곳', style: T.title),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => byFree = !byFree),
              child: Row(children: [
                const Icon(Icons.swap_vert_rounded, size: 16, color: kSub),
                Text(byFree ? '빈자리 많은 순' : '가까운 순', style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text('조건에 맞는 충전소가 없어요.\n위 고르기를 바꿔 보세요.', textAlign: TextAlign.center, style: T.small),
          ),
        for (final s in rest) ...[_card(s, cheap), const SizedBox(height: 8)],
        const SizedBox(height: 10),
        const _Legend(),
        const SizedBox(height: 10),
        Text(
          '환경부 전기차 충전소 정보 기준 · 운영기관 사정으로 상태가 늦거나 다를 수 있어요. 요금은 ${prices.source}(${prices.since}~) 기준이며 회원카드에 따라 달라요.'
          '${canLive ? '' : '\n지금 보이는 상태는 모아 둔 자료예요. 실시간 상태는 휴대폰 앱에서 보여요.'}',
          style: T.tiny,
        ),
      ]),
    );
  }

  Widget _card(Station s, String? cheap) => _StationCard(
        s: s,
        from: c,
        list: mine(s),
        cheapest: s.id == cheap,
        onTap: () => _open(s),
        onWatch: () {
          startWatch(s, plugs);
          toast(context, '비면 알려 드릴게요 (최대 1시간)');
        },
      );

  Widget _summary(List<Station> list) {
    var fast = 0, slow = 0;
    for (final s in list) {
      for (final x in mine(s)) {
        if (x.use != Use.free) continue;
        x.fast ? fast++ : slow++;
      }
    }
    final near = list.where((s) => freeN(s) > 0).toList()..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    return Container(
      decoration: cardBox(r: 16),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          MixTitle('지금', plugs.isEmpty ? '비어 있는 충전기' : '내 차에 맞는 빈 충전기', size: 14),
          const Spacer(),
          Text(basis, style: T.tiny),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _big('급속', fast),
          if (mode != Mode.fast) ...[
            Container(width: 1, height: 30, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _big('완속', slow),
          ],
          const Spacer(),
          Text('${distText(radius)} 안 ${list.length}곳', style: T.tiny),
        ]),
        if (near.isNotEmpty) ...[
          const SizedBox(height: 11),
          InkWell(
            onTap: () => _open(near.first),
            child: Row(children: [
              const Text('가장 가까운 빈 곳', style: T.tiny),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${near.first.name} · ${distText(meters(c.pos, near.first.pos))}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: kMute),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _big(String label, int n) => Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w500)),
        const SizedBox(width: 7),
        Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: n > 0 ? kFree : kMute, height: 1)),
        const SizedBox(width: 2),
        const Text('대', style: TextStyle(fontSize: 12, color: kSub)),
      ]);

  Widget _map(List<Station> list) => Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: c.pos,
            initialZoom: radius > 2000 ? 13.5 : 14.5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
            MarkerLayer(markers: [
              Marker(
                point: c.pos,
                width: 120,
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
              for (final s in list.reversed.take(150))
                Marker(
                  point: s.pos,
                  width: 104,
                  height: 34,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(onTap: () => _open(s), child: _Bubble(list: mine(s))),
                ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: cardBox(r: 9),
            child: const _Legend(small: true),
          ),
        ),
      ]);

  Future<void> _open(Station s) async {
    await showStation(context, s, c);
    if (mounted) setState(() {});
  }
}

// 지도 말풍선: 「빈 2/4 · 급속」
class _Bubble extends StatelessWidget {
  final List<Charger> list;
  const _Bubble({required this.list});
  @override
  Widget build(BuildContext context) {
    final col = stationColor(list);
    final free = list.where((c) => c.use == Use.free).length;
    final fast = list.any((c) => c.fast);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(20), boxShadow: kShadow),
        child: Text('빈 $free/${list.length} · ${fast ? '급속' : '완속'}',
            maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1, color: Colors.white)),
      ),
      CustomPaint(size: const Size(8, 5), painter: _Tail(col)),
    ]);
  }
}

class _Tail extends CustomPainter {
  final Color c;
  _Tail(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_Tail o) => o.c != c;
}

// ---------------- 충전소 카드 ----------------
class _StationCard extends StatelessWidget {
  final Station s;
  final Complex from;
  final List<Charger> list;
  final bool cheapest;
  final VoidCallback onTap, onWatch;
  const _StationCard({required this.s, required this.from, required this.list, required this.cheapest, required this.onTap, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    final free = list.where((x) => x.use == Use.free).length;
    final col = stationColor(list);
    final price = cheapest_(s, list);
    final fastL = list.where((x) => x.fast).toList(), slowL = list.where((x) => !x.fast).toList();
    final sub = [distText(meters(from.pos, s.pos)), if (s.owner.isNotEmpty) s.owner].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
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
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$free', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: col)),
                  TextSpan(text: ' / ${list.length}', style: const TextStyle(fontSize: 12, color: kSub)),
                ])),
                Text(stationWord(list), style: TextStyle(fontSize: 10.5, color: col, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 9),
            if (fastL.isNotEmpty) _Row(label: '급속', list: fastL),
            if (fastL.isNotEmpty && slowL.isNotEmpty) const SizedBox(height: 6),
            if (slowL.isNotEmpty) _Row(label: '완속', list: slowL),
            const SizedBox(height: 9),
            Wrap(spacing: 5, runSpacing: 5, children: [
              if (price != null) Pill('kWh당 ${wonText(price)}${list.length > 1 ? '~' : ''}', color: cheapest ? kBlue : kSub, bg: cheapest ? const Color(0xFFEEF3FF) : const Color(0xFFF1F3F6)),
              if (price == null) const Pill('요금 확인 필요'),
              if (cheapest) const Pill('가까운 곳 중 가장 저렴', color: kBlue, bg: Color(0xFFEEF3FF)),
              if (s.limited) Pill(_limitShort(s.limit)),
              Pill(s.parkFree ? '주차 무료' : '주차비 별도'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _SmallBtn('길안내', icon: Icons.near_me_outlined, onTap: () => startNav(context, name: s.name, lat: s.pos.latitude, lng: s.pos.longitude))),
              if (free == 0 && list.any((x) => x.use == Use.busy)) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: isWatching(s)
                      ? _SmallBtn('알림 대기 중', icon: Icons.notifications_active_outlined, onTap: () => stopWatch(s))
                      : _SmallBtn('비면 알려 주기', icon: Icons.notifications_none_rounded, onTap: onWatch),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

double? cheapest_(Station s, List<Charger> l) => cheapest(s, l);

String _limitShort(String l) {
  if (l.contains('입주') || l.contains('거주') || l.contains('아파트')) return '입주민 전용';
  if (l.contains('직원') || l.contains('관계자')) return '관계자 전용';
  return '이용 제한';
}

class _SmallBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _SmallBtn(this.text, {required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 34,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFD5D9E0))),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: kInk),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
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
          for (final c in list.take(show)) Dot(c.use),
          if (list.length > show) Text(' +${list.length - show}', style: T.tiny),
        ]),
      ),
    ]);
  }
}

class Dot extends StatelessWidget {
  final Use u;
  final double size;
  const Dot(this.u, {super.key, this.size = 11});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: switch (u) { Use.free => kFree, Use.busy => kBusy, Use.off => const Color(0xFFEDEEF1), Use.unknown => Colors.white },
          border: u == Use.unknown || u == Use.off ? Border.all(color: const Color(0xFFCDD0D6)) : null,
        ),
        child: u == Use.off ? CustomPaint(painter: _Slash()) : null,
      );
}

class _Slash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kOff
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width - 2, 2), Offset(2, size.height - 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  final bool small;
  const _Legend({this.small = false});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 4, children: [
        for (final e in const [(Use.free, '사용 가능'), (Use.busy, '충전 중'), (Use.off, '고장·점검'), (Use.unknown, '상태 모름')])
          if (!small || e.$1 != Use.unknown)
            Row(mainAxisSize: MainAxisSize.min, children: [Dot(e.$1, size: 10), const SizedBox(width: 4), Text(e.$2, style: T.tiny)]),
      ]);
}

// ---------------- 타이머 · 알림 표시 ----------------
class _TimerCard extends StatelessWidget {
  final ChargeTimer t;
  const _TimerCard({required this.t});
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(r: 16),
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(children: [
          const LineIcon('charger', size: 30, fill: kSoftGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '충전 중 ', style: TextStyle(fontWeight: FontWeight.w300)),
                TextSpan(text: '${clockText(t.end)} 완료', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]), style: const TextStyle(fontSize: 15, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text('${leftText(t.end)}${t.name.isEmpty ? '' : ' · ${t.name}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              if (t.fast) const Text('급속은 1시간 넘으면 과태료 — 끝나면 바로 차를 빼 주세요', style: T.tiny),
            ]),
          ),
          TextButton(onPressed: stopTimer, child: const Text('끝내기', style: TextStyle(fontSize: 12.5, color: kSub))),
        ]),
      );
}

class _WatchBar extends StatelessWidget {
  final Watch w;
  const _WatchBar({required this.w});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
        decoration: cardBox(r: 12),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined, size: 18, color: kInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${w.s.name} 비면 알림 · ${clockText(w.until)}까지',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: () => stopWatch(w.s), child: const Text('끄기', style: TextStyle(fontSize: 12, color: kSub))),
        ]),
      );
}

// ---------------- 내 차 (단자 고르기) ----------------
Future<void> showMyCar(BuildContext context) => showSheet(context, (ctx) => const _MyCar());

class _MyCar extends StatefulWidget {
  const _MyCar();
  @override
  State<_MyCar> createState() => _MyCarState();
}

class _MyCarState extends State<_MyCar> {
  late Set<String> sel = {...myPlugs.value};
  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14), children: [
        const MixTitle('내 차', '충전 단자', size: 17),
        const SizedBox(height: 4),
        const Text('고른 단자에 맞는 충전기만 보여 드려요. 여러 개 골라도 돼요.', style: T.small),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => sel = {'combo', 'ac'}),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Expanded(child: Text('잘 모르겠어요 → 요즘 전기차 대부분 (DC콤보 + AC완속)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right_rounded, size: 18, color: kMute),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        for (final p in kPlugs)
          InkWell(
            onTap: () => setState(() => sel.contains(p.$1) ? sel.remove(p.$1) : sel.add(p.$1)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(sel.contains(p.$1) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 21, color: sel.contains(p.$1) ? kBlue : kMute),
                const SizedBox(width: 10),
                SizedBox(width: 72, child: Text(p.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                Expanded(child: Text(p.$3, style: T.small)),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Btn('모두 보기', onTap: () {
              saveMyPlugs({});
              Navigator.pop(context);
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Btn('저장', primary: true, onTap: () {
              saveMyPlugs(sel);
              Navigator.pop(context);
            }),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('나중에 위쪽 「내 차」에서 바꿀 수 있어요.', textAlign: TextAlign.center, style: T.tiny),
      ]);
}

// ---------------- 충전소 창 (아래에서 올라옴) ----------------
Future<void> showStation(BuildContext context, Station s, Complex from) {
  bindRoot(context);
  return showSheet(context, (ctx) => _StationSheet(s: s, from: from));
}

class _StationSheet extends StatefulWidget {
  final Station s;
  final Complex from;
  const _StationSheet({required this.s, required this.from});
  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  bool busy = false;
  List<Report> reports = const [];
  Station get s => widget.s;
  Set<String> get plugs => myPlugs.value;

  @override
  void initState() {
    super.initState();
    _refresh();
    reportsOf(s).then((r) {
      if (mounted) setState(() => reports = r);
    });
  }

  Future<void> _refresh() async {
    if (!canLive) return;
    setState(() => busy = true);
    await refreshStation(s);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final fit = s.pick(plugs: plugs);
    final all = [...s.chargers]..sort((a, b) => a.fast != b.fast ? (a.fast ? -1 : 1) : a.id.compareTo(b.id));
    final free = fit.where((c) => c.use == Use.free).length;
    final col = stationColor(fit);
    final anyFast = fit.any((c) => c.fast);
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(s.name, style: T.h1)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '$free', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: col)),
            TextSpan(text: ' / ${fit.length}', style: const TextStyle(fontSize: 12, color: kSub)),
          ])),
          Text(plugs.isEmpty ? stationWord(fit) : '내 차 기준 ${stationWord(fit)}', style: TextStyle(fontSize: 10.5, color: col, fontWeight: FontWeight.w600)),
        ]),
      ]),
      const SizedBox(height: 4),
      Text('${distText(meters(widget.from.pos, s.pos))} · ${s.addr}${s.detail.isNotEmpty ? ' (${s.detail})' : ''}', style: T.small),
      const SizedBox(height: 8),
      Wrap(spacing: 5, runSpacing: 5, children: [
        if (s.hasFast) Pill('급속 최대 ${s.maxKw}kW'),
        if (s.limited) Pill(_limitShort(s.limit)),
        Pill(s.parkFree ? '주차 무료' : '주차비 별도'),
        if (s.kind.isNotEmpty) Pill(s.kind),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Btn('길안내', icon: 'car', primary: true, onTap: () => startNav(context, name: s.name, lat: s.pos.latitude, lng: s.pos.longitude))),
        if (s.tel.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(child: Btn('운영기관 전화', onTap: () => callTel(s.tel))),
        ],
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: free == 0
              ? (isWatching(s)
                  ? Btn('알림 끄기', h: 42, onTap: () => setState(() => stopWatch(s)))
                  : Btn('비면 알려 주기', h: 42, onTap: () {
                      startWatch(s, plugs);
                      setState(() {});
                      toast(context, '내 차에 맞는 충전기가 비면 알려 드릴게요 (최대 1시간)');
                    }))
              : Btn('충전 시작', h: 42, onTap: () => _timer(anyFast)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Btn('고장이에요', h: 42, onTap: _report)),
      ]),
      if (free == 0) ...[
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _timer(anyFast), child: const Text('충전 시작 타이머', style: TextStyle(fontSize: 12, color: kSub)))),
      ],
      const SizedBox(height: 12),
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
          for (var i = 0; i < all.length; i++) _chargerRow(all[i], i == 0),
        ]),
      ),
      const SizedBox(height: 14),
      if (reports.isNotEmpty) ...[
        const Text('최근 고장 제보', style: T.title),
        const SizedBox(height: 6),
        for (final r in reports.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 62, child: Text(_ago(r.at), style: T.tiny)),
              Expanded(child: Text('${r.cid}번 · ${r.kind}${r.text.isEmpty ? '' : ' — ${r.text}'}', style: const TextStyle(fontSize: 12.5, height: 1.35))),
            ]),
          ),
        const SizedBox(height: 10),
      ],
      if (s.hours.isNotEmpty) _info('이용 시간', s.hours),
      if (s.owner.isNotEmpty) _info('운영기관', '${s.owner}${s.tel.isNotEmpty ? ' · ${s.tel}' : ''}'),
      if (s.limited) _info('이용 조건', s.limit),
      _info('요금', s.isPublicPrice ? '공공요금 (출력별 5단계, ${prices.since}~)' : '운영기관마다 달라요 — 요금 확인 필요'),
      const SizedBox(height: 6),
      const Text('기후부 회원카드로 협약된 민간 충전기를 쓰면 공공요금이 적용될 수 있어요. 고장은 운영기관 전화로도 알려 주세요.', style: T.tiny),
    ]);
  }

  Widget _chargerRow(Charger c, bool first) {
    final ok = c.fits(plugs);
    final p = priceOf(s, c);
    return Opacity(
      opacity: ok ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: first ? null : const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F1F4)))),
        child: Row(children: [
          Dot(c.use, size: 10),
          const SizedBox(width: 8),
          SizedBox(width: 22, child: Text(c.id, style: const TextStyle(fontSize: 11.5, color: kSub))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.fast ? '급속' : '완속'} ${typeText(c.type)}${c.kw > 0 ? ' · ${c.kw}kW' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
              Text('${p != null ? 'kWh당 ${wonText(p)}' : '요금 확인 필요'}${ok ? '' : ' · 내 차와 안 맞음'}', style: T.tiny),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(useText(c.stat),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.use == Use.free ? kFree : (c.use == Use.busy ? kBusy : kMute))),
            Text(agoText(c.upd), style: T.tiny),
          ]),
        ]),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 64, child: Text(k, style: T.small)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, height: 1.4))),
        ]),
      );

  String _ago(DateTime t) {
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 60) return '${m < 1 ? 1 : m}분 전';
    if (m < 60 * 24) return '${m ~/ 60}시간 전';
    return '${m ~/ (60 * 24)}일 전';
  }

  Future<void> _timer(bool fast) async {
    final d = await showSheet<Duration>(context, (ctx) => _TimerPick(fast: fast));
    if (d == null) return;
    await startTimer(s.name, fast, d);
    if (!mounted) return;
    toast(context, '${clockText(DateTime.now().add(d))}에 알려 드릴게요');
    Navigator.pop(context);
  }

  Future<void> _report() async {
    final r = await showSheet<(Charger, String, String)>(context, (ctx) => _ReportPick(s: s));
    if (r == null || !mounted) return;
    var msg = await sendReport(s, r.$1, r.$2, r.$3);
    if (msg == 'login') {
      if (!mounted) return;
      toast(context, '고장 제보는 로그인한 뒤에 보낼 수 있어요');
      await openLogin(context);
      msg = await sendReport(s, r.$1, r.$2, r.$3);
      if (msg == 'login') return;
    }
    if (!mounted) return;
    toast(context, msg ?? '고마워요. 다른 이웃에게도 보여요');
    if (msg == null) {
      final list = await reportsOf(s);
      if (mounted) setState(() => reports = list);
    }
  }
}

// ---------------- 충전 타이머 고르기 ----------------
class _TimerPick extends StatelessWidget {
  final bool fast;
  const _TimerPick({required this.fast});
  @override
  Widget build(BuildContext context) {
    final opts = fast
        ? const [(20, '20분'), (30, '30분'), (40, '40분'), (50, '50분'), (60, '1시간')]
        : const [(60, '1시간'), (120, '2시간'), (240, '4시간'), (480, '8시간'), (720, '12시간')];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        MixTitle('충전', fast ? '얼마나 걸릴까요 (급속)' : '얼마나 걸릴까요 (완속)', size: 17),
        const SizedBox(height: 4),
        Text(fast ? '끝나는 시간에 「이제 차를 빼 주세요」 알림을 드려요. 급속 충전구역은 1시간을 넘기면 과태료(10만 원)가 나올 수 있어요.' : '끝나는 시간에 알려 드려요. 완속 충전구역은 14시간을 넘기면 과태료가 나올 수 있어요.',
            style: T.small),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in opts) ChoiceChipBox(o.$2, on: false, onTap: () => Navigator.pop(context, Duration(minutes: o.$1))),
          ChoiceChipBox('끝나는 시각 고르기', on: false, onTap: () async {
            final now = TimeOfDay.now();
            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute), helpText: '충전이 끝나는 시각');
            if (t == null || !context.mounted) return;
            final n = DateTime.now();
            var end = DateTime(n.year, n.month, n.day, t.hour, t.minute);
            if (!end.isAfter(n)) end = end.add(const Duration(days: 1));
            Navigator.pop(context, end.difference(n));
          }),
        ]),
        const SizedBox(height: 12),
        const Text('지금은 앱을 켜 둔 동안 알려 드려요. 앱을 닫아도 울리는 휴대폰 알림은 곧 붙여요.', style: T.tiny),
      ]),
    );
  }
}

// ---------------- 고장 제보 고르기 ----------------
class _ReportPick extends StatefulWidget {
  final Station s;
  const _ReportPick({required this.s});
  @override
  State<_ReportPick> createState() => _ReportPickState();
}

class _ReportPickState extends State<_ReportPick> {
  Charger? c;
  String kind = kReportKinds.first;
  final text = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.s.chargers.length == 1) c = widget.s.chargers.first;
  }

  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14), children: [
        const MixTitle('고장', '알려 주기', size: 17),
        const SizedBox(height: 4),
        const Text('이웃이 헛걸음하지 않게 최근 제보로 보여 드려요. 한 충전기에 하루 한 번만 보낼 수 있어요.', style: T.small),
        const SizedBox(height: 14),
        const Text('어느 충전기인가요', style: T.title),
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in widget.s.chargers)
            ChoiceChipBox('${x.id}번 ${x.fast ? '급속' : '완속'}', on: c == x, onTap: () => setState(() => c = x)),
        ]),
        const SizedBox(height: 14),
        const Text('어떤 문제인가요', style: T.title),
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in kReportKinds) ChoiceChipBox(k, on: kind == k, onTap: () => setState(() => kind = k)),
        ]),
        const SizedBox(height: 14),
        Field('', text, hint: '한 줄로 더 알려 주세요 (없어도 돼요)', max: 80),
        Btn('보내기', primary: true, onTap: c == null ? null : () => Navigator.pop(context, (c!, kind, text.text.trim()))),
        if (c == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('충전기를 먼저 골라 주세요', textAlign: TextAlign.center, style: T.tiny)),
      ]);
}
