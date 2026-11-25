// 주유소 상세 화면 (주유소 담당 방만 고침)
// 디자인 0.2.0 (대표님 시안 11-25): 사진 머리(아래·왼쪽은 바탕에 녹임) · 아이콘 기름 고르기 · 반경 알약
//   · 파란 그림 요약판(주유기) · 1위 강조 카드 + 싼 순 목록 · 「지도 보기」는 공용 지도(DnMap)에 가격 말풍선
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/dnmap.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _page = Color(0xFFF4F7FB);
const _chipLine = Color(0xFFD3DDEB);
const _rowLine = Color(0xFFEEF1F5);
const _gold = Color(0xFFF2B01E);

IconData fuelIcon(String code) => switch (code) {
      'D047' => Icons.local_shipping_outlined,
      'K015' => Icons.propane_tank_outlined,
      'B034' => Icons.diamond_outlined,
      _ => Icons.local_gas_station_outlined,
    };

// 정유사 짧은 표시 (상표 그림이 아니라 글자)
String brandShort(String code) => switch (code) {
      'SKE' || 'SKG' => 'SK',
      'GSC' => 'GS',
      'HDO' => 'HD',
      'SOL' => 'S-OIL',
      'RTE' || 'RTX' || 'NHO' || 'RTO' => '알뜰',
      'E1G' => 'E1',
      _ => '자가',
    };

class GasPage extends StatefulWidget {
  final Complex c;
  const GasPage(this.c, {super.key});
  @override
  State<GasPage> createState() => _GasPageState();
}

class _GasPageState extends State<GasPage> {
  String fuel = 'B027';
  int radius = 5000;
  bool showMap = false;
  bool loading = true;
  GasData? data;
  String? sel;
  final ctl = DnMapCtl();

  Complex get c => widget.c;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final f = await prefGet('gas.fuel');
    final r = int.tryParse(await prefGet('gas.radius') ?? '');
    final d = await loadGas(c.pos);
    if (!mounted) return;
    setState(() {
      if (f != null && kFuels.any((x) => x.$1 == f)) fuel = f;
      if (r != null && kRadii.contains(r)) radius = r;
      data = d;
      loading = false;
    });
  }

  double get zoom => radius <= 3000 ? 13.0 : (radius <= 5000 ? 12.3 : 11.3);

  void _fuel(String f) {
    setState(() {
      fuel = f;
      sel = null;
    });
    prefSet('gas.fuel', f);
  }

  void _radius(int r) {
    setState(() {
      radius = r;
      sel = null;
    });
    prefSet('gas.radius', '$r');
    if (showMap) ctl.move(c.pos, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final list = d == null ? <GasStation>[] : d.around(c.pos, fuel, radius);
    Widget inner(Widget w) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: w));
    return Scaffold(
      backgroundColor: _page,
      body: loading
          ? Column(children: [_head(false), const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))])
          : d == null || d.stations.isEmpty
              ? Column(children: [_head(false), const Expanded(child: _Empty())])
              : showMap
                  ? Column(children: [_head(true), _pickers(inner, compact: true), Expanded(child: _map(d, list))])
                  : ListView(padding: EdgeInsets.zero, children: [
                      _head(true),
                      _pickers(inner),
                      inner(Padding(
                        padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _summary(d, list),
                          const SizedBox(height: 10),
                          _basis(d, list),
                          const SizedBox(height: 14),
                          ..._list(d, list),
                        ]),
                      )),
                    ]),
    );
  }

  // ── 맨 위: 오른쪽 주유소 사진(왼쪽·아래는 바탕색으로 녹아 들어감) + ← 아이콘 제목 + 지도 보기 + 큰 제목
  Widget _head(bool canMap) {
    final top = MediaQuery.of(context).padding.top;
    final full = MediaQuery.of(context).size.width;
    final w = full.clamp(0, 720).toDouble();
    final narrow = w < 380;
    final side = (full - w) / 2;
    final h = top + (showMap ? 64.0 : 168.0);
    return SizedBox(
      height: h,
      child: Stack(children: [
        // 바탕: 위는 하늘색, 아래로 갈수록 화면 바탕색 — 사진 아래 끝이 여기에 녹아 경계선이 없다
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFDDEDFC), _page])),
          ),
        ),
        if (!showMap)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: (full * 0.74).clamp(0.0, 820.0),
            child: IgnorePointer(
              child: ShaderMask(
                // 왼쪽: 투명 → 불투명
                shaderCallback: (r) => const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF), Colors.white], stops: [0, 0.35, 1]).createShader(r),
                blendMode: BlendMode.dstIn,
                child: ShaderMask(
                  // 아래: 절반부터 서서히 투명 → 맨 아래는 완전히 바탕색
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Color(0x66FFFFFF), Color(0x00FFFFFF)],
                    stops: [0, 0.5, 0.8, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset('assets/art/gas_head.jpg', fit: BoxFit.cover, alignment: const Alignment(0.55, -0.2), filterQuality: FilterQuality.medium),
                ),
              ),
            ),
          ),
        Positioned(
          left: side + 2,
          right: side + kPad - 6,
          top: top + 8,
          child: Row(children: [
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 24, color: kInk)),
            Image.asset('assets/icons/gas.png', width: narrow ? 26 : 30, height: narrow ? 26 : 30),
            const SizedBox(width: 6),
            Flexible(
              child: Text(narrow ? '싼 주유소 찾기' : '가격 싼 주유소 찾기',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: narrow ? 16.5 : 18, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk)),
            ),
            const Spacer(),
            if (canMap)
              _GlassBtn(
                icon: Icon(showMap ? Icons.format_list_bulleted_rounded : Icons.map_outlined, size: 17, color: kInk),
                text: showMap ? '목록' : '지도',
                onTap: () => setState(() {
                  showMap = !showMap;
                  sel = null;
                }),
              ),
          ]),
        ),
        if (!showMap)
          Positioned(
            left: side + kPad,
            top: top + 66,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('내 주변', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300, color: kInk, height: 1.2, letterSpacing: -0.3)),
              Text('가격 싼 주유소',
                  style: TextStyle(fontSize: narrow ? 23 : 26, fontWeight: FontWeight.w800, color: kBlue, height: 1.2, letterSpacing: -0.9)),
              const SizedBox(height: 6),
              const Text('휘발유 · 경유 · LPG · 고급휘발유\n단지에서 가장 싼 곳을 찾아 드려요',
                  style: TextStyle(fontSize: 11.5, color: kSub, height: 1.4, letterSpacing: -0.2)),
            ]),
          ),
      ]),
    );
  }

  // ── 기름 고르기 · 반경
  Widget _pickers(Widget Function(Widget) inner, {bool compact = false}) => inner(Padding(
        padding: EdgeInsets.fromLTRB(0, compact ? 2 : 4, 0, compact ? 10 : 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kPad),
            child: Row(children: [
              for (final f in kFuels) ...[
                _Chip(f.$2, icon: fuelIcon(f.$1), on: fuel == f.$1, onTap: () => _fuel(f.$1)),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPad),
            child: Row(children: [
              const Text('단지에서', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kSub)),
              const SizedBox(width: 8),
              for (final r in kRadii) ...[
                _Chip('${r ~/ 1000}km', small: true, on: radius == r, onTap: () => _radius(r)),
                const SizedBox(width: 6),
              ],
            ]),
          ),
        ]),
      ));

  // ── 파란 주유기 그림 요약판: 반경 최저가 | 시도 평균 · 얼마 싼지
  Widget _summary(GasData d, List<GasStation> list) {
    final best = list.isEmpty ? null : list.first;
    final bp = best?.price(fuel);
    final avg = d.avg[fuel];
    final gap = (avg != null && bp != null) ? (avg - bp).round() : null;
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final h = w * 515 / 1600; // 그림 비율 그대로
      // 그림 안 파란 판: 위 20.5% ~ 아래 82.5%, 왼쪽 주유기 그림 끝 17%, 오른쪽 노즐 시작 71%
      final top = h * 0.205, bottom = h * (1 - 0.825);
      final narrow = w < 360;
      return SizedBox(
        height: h,
        child: Stack(children: [
          Positioned.fill(child: Image.asset('assets/art/gas_card.png', fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
          Positioned(
            left: w * 0.175,
            right: w * 0.30,
            top: top,
            bottom: bottom,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('반경 ${radius ~/ 1000}km 최저가', style: const TextStyle(fontSize: 11.5, color: Color(0xDDFFFFFF), fontWeight: FontWeight.w600)),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: bp == null ? '없음' : won(bp),
                        style: TextStyle(fontSize: narrow ? 24 : 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1, height: 1.15)),
                    if (bp != null) const TextSpan(text: '원', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ])),
                ]),
                if (avg != null) ...[
                  Container(width: 1, height: 34, color: const Color(0x55FFFFFF), margin: EdgeInsets.symmetric(horizontal: narrow ? 10 : 16)),
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d.sido} 평균', style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF))),
                    Text('${won(avg)}원', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
                    if (gap != null && gap > 0) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 2, 9, 2),
                        decoration: BoxDecoration(color: const Color(0xFF19A463), borderRadius: BorderRadius.circular(10)),
                        child: Text('▼ $gap원 저렴', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _basis(GasData d, List<GasStation> list) => Row(children: [
        const Icon(Icons.place_outlined, size: 14, color: kSub),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '단지에서 ${radius ~/ 1000}km 안 ${list.length}곳 · 오피넷 ${whenText(d.updatedFor(fuel))} 기준',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: kSub),
          ),
        ),
      ]);

  // ── 1위 강조 카드 + 나머지 싼 순 목록
  List<Widget> _list(GasData d, List<GasStation> list) {
    if (list.isEmpty) {
      return [
        const SizedBox(height: 24),
        Text('단지에서 ${radius ~/ 1000}km 안에 ${fuelName(fuel)}을 파는 곳이 없어요', textAlign: TextAlign.center, style: T.small),
        if (radius < kRadii.last) ...[
          const SizedBox(height: 14),
          Center(child: SizedBox(width: 180, child: Btn('${kRadii.last ~/ 1000}km까지 보기', h: 40, onTap: () => _radius(kRadii.last)))),
        ],
      ];
    }
    final avg = d.avg[fuel];
    final minP = list.first.price(fuel);
    final first = [for (final s in list) if (s.price(fuel) == minP) s];
    final rest = list.skip(first.length).toList();
    return [
      for (var i = 0; i < first.length; i++) ...[_TopCard(s: first[i], fuel: fuel, avg: avg, onTap: () => showStation(context, first[i], fuel, d)), const SizedBox(height: 8)],
      if (rest.isNotEmpty)
        Container(
          decoration: cardBox(),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < rest.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: _rowLine, indent: 14, endIndent: 14),
              _Row(rank: first.length + i + 1, s: rest[i], fuel: fuel, avg: avg, onTap: () => showStation(context, rest[i], fuel, d)),
            ],
          ]),
        ),
      const SizedBox(height: 12),
      const Text('한국석유공사 오피넷 「지역별 최저가 20곳」 기준이에요. 시군구마다 가장 싼 곳을 모아 보여 드려서, 비싼 주유소는 목록에 없을 수 있어요. 주유소가 알린 가격이라 실제와 다를 수 있어요.', style: T.tiny),
    ];
  }

  // ── 지도: 공용 지도(DnMap) 위 가격 말풍선, 가장 싼 곳은 파랑
  Widget _map(GasData d, List<GasStation> list) {
    final minP = list.isEmpty ? null : list.first.price(fuel);
    final picked = list.where((s) => s.id == sel).firstOrNull;
    return Stack(children: [
      DnMap(
        center: c.pos,
        zoom: zoom,
        ctl: ctl,
        circles: [DnCircle(c.pos, radius.toDouble(), fill: kBlue.withValues(alpha: 0.035), line: kBlue.withValues(alpha: 0.3))],
        onMapTap: () => setState(() => sel = null),
        marks: [
          for (final s in list)
            DnMark(
              id: s.id,
              pos: s.pos,
              key: '${s.id}|${s.price(fuel)}|${s.price(fuel) == minP}|${s.id == sel}',
              size: const Size(70, 30),
              z: s.id == sel ? 3 : (s.price(fuel) == minP ? 2 : 1),
              child: _Bubble(price: s.price(fuel)!, best: s.price(fuel) == minP, on: s.id == sel, onTap: () => setState(() => sel = s.id)),
              onTap: () => setState(() => sel = s.id),
            ),
        ],
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 14,
        child: picked != null
            ? _PickCard(s: picked, fuel: fuel, best: picked.price(fuel) == minP, onOpen: () => showStation(context, picked, fuel, d))
            : Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: cardBox(r: 20),
                  child: Text(list.isEmpty ? '이 반경엔 파는 곳이 없어요' : '가격을 누르면 주유소가 나와요 · ${list.length}곳', style: T.small),
                ),
              ),
      ),
    ]);
  }
}

// ── 작은 부품들
class _GlassBtn extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback onTap;
  const _GlassBtn({required this.icon, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xE6FFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE2E8F1))),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              icon,
              const SizedBox(width: 5),
              Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk)),
            ]),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool on, small;
  final VoidCallback onTap;
  const _Chip(this.text, {this.icon, this.small = false, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: on ? kBlue : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: on ? kBlue : _chipLine)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: small ? 30 : 36,
            padding: EdgeInsets.fromLTRB(icon == null ? (small ? 14 : 18) : 12, 0, small ? 14 : 16, 0),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 17, color: on ? Colors.white : kBlue), const SizedBox(width: 5)],
              Text(text, style: TextStyle(fontSize: small ? 12 : 13, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? Colors.white : kInk)),
            ]),
          ),
        ),
      );
}

// 정유사 글자 동그라미 (상표 그림 대신)
class _Brand extends StatelessWidget {
  final String code;
  const _Brand(this.code);
  @override
  Widget build(BuildContext context) {
    final t = brandShort(code);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFF2F4F8), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE3E7EE))),
      child: Text(t, style: TextStyle(fontSize: t.length > 3 ? 8.5 : (t.length > 2 ? 9.5 : 11), fontWeight: FontWeight.w800, color: const Color(0xFF4A5363), letterSpacing: -0.3)),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final GasStation s;
  const _NavBtn(this.s);
  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFDCE2EA))),
          child: const Icon(Icons.near_me_outlined, size: 16, color: Color(0xFF55607A)),
        ),
      );
}

String _diffText(int p, double? avg) {
  if (avg == null) return '';
  final d = (p - avg).round();
  if (d == 0) return '평균과 같아요';
  return d < 0 ? '평균 대비 ${-d}원↓' : '평균 대비 $d원↑';
}

// 1위: 노란 바탕 강조 카드 (같은 최저가가 여럿이면 모두)
class _TopCard extends StatelessWidget {
  final GasStation s;
  final String fuel;
  final double? avg;
  final VoidCallback onTap;
  const _TopCard({required this.s, required this.fuel, required this.avg, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = s.price(fuel)!;
    return Material(
      color: const Color(0xFFFFFAEB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius), side: const BorderSide(color: Color(0xFFF5E2A8))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/art/gas_thumb.jpg', width: 62, height: 44, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
              Positioned(
                left: -5,
                top: -5,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _gold, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
                  child: const Text('1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 2),
                Text(['최저가', brandName(s.brand), distText(s.dist), if (s.self) '셀프'].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: won(p), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: kBlue)),
                const TextSpan(text: '원', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kBlue)),
              ])),
              Text(_diffText(p, avg), style: const TextStyle(fontSize: 10.5, color: kSub)),
            ]),
            const SizedBox(width: 10),
            _NavBtn(s),
          ]),
        ),
      ),
    );
  }
}

// 나머지 줄: 순위 · 정유사 · 이름 · 가격 · 길안내
class _Row extends StatelessWidget {
  final int rank;
  final GasStation s;
  final String fuel;
  final double? avg;
  final VoidCallback onTap;
  const _Row({required this.rank, required this.s, required this.fuel, required this.avg, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = s.price(fuel)!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(children: [
          SizedBox(width: 20, child: Text('$rank', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kSub))),
          const SizedBox(width: 8),
          _Brand(s.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 1),
              Row(children: [
                Flexible(child: Text('${brandName(s.brand).isEmpty ? '' : '${brandName(s.brand)} · '}${distText(s.dist)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)),
                if (s.self) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(8)),
                    child: const Text('셀프', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF5A6475))),
                  ),
                ],
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: won(p), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: kInk)),
              const TextSpan(text: '원', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300)),
            ])),
            Text(_diffText(p, avg), style: const TextStyle(fontSize: 10.5, color: kSub)),
          ]),
          const SizedBox(width: 10),
          _NavBtn(s),
        ]),
      ),
    );
  }
}

// 지도 말풍선 (가격)
class _Bubble extends StatelessWidget {
  final int price;
  final bool best, on;
  final VoidCallback onTap;
  const _Bubble({required this.price, required this.best, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final bg = best ? kBlue : Colors.white;
    final fg = best ? Colors.white : kInk;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? kInk : (best ? kBlue : const Color(0xFFCFD3DA)), width: 1),
            boxShadow: kShadow,
          ),
          child: Text(won(price), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg, height: 1.25, letterSpacing: -0.2)),
        ),
        CustomPaint(size: const Size(8, 5), painter: _Tail(bg, on ? kInk : (best ? kBlue : const Color(0xFFCFD3DA)))),
      ]),
    );
  }
}

class _Tail extends CustomPainter {
  final Color fill, line;
  _Tail(this.fill, this.line);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(s.width, 0);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(p, Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _Tail o) => o.fill != fill || o.line != line;
}

// 지도에서 고른 주유소 (아래 카드)
class _PickCard extends StatelessWidget {
  final GasStation s;
  final String fuel;
  final bool best;
  final VoidCallback onOpen;
  const _PickCard({required this.s, required this.fuel, required this.best, required this.onOpen});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadius),
              onTap: onOpen,
              child: Ink(
                decoration: cardBox(),
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text([if (best) '가장 쌈', brandName(s.brand), distText(s.dist)].where((x) => x.isNotEmpty).join(' · '), style: T.tiny),
                    ]),
                  ),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: won(s.price(fuel) ?? 0), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: best ? kBlue : kInk)),
                    const TextSpan(text: '원', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w300)),
                  ])),
                  const SizedBox(width: 10),
                  SizedBox(width: 74, child: Btn('길안내', icon: 'route', primary: true, h: 38, onTap: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng))),
                ]),
              ),
            ),
          ),
        ),
      );
}

// 주유소 정보 (아래에서 올라오는 창)
Future<void> showStation(BuildContext context, GasStation s, String fuel, GasData d) => showSheet(
      context,
      (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 3),
          Text(
              [brandName(s.brand), s.lpg == 'Y' ? 'LPG 충전소' : (s.lpg == 'C' ? '주유·충전 겸업' : ''), '단지에서 ${distText(s.dist)}']
                  .where((x) => x.isNotEmpty)
                  .join(' · '),
              style: T.small),
          const SizedBox(height: 14),
          for (final f in kFuels)
            if (s.price(f.$1) != null) _PriceRow(name: f.$2, price: s.price(f.$1)!, avg: d.avg[f.$1], on: f.$1 == fuel),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (s.self) const Pill('셀프'),
            if (s.wash) const Pill('세차'),
            if (s.cvs) const Pill('편의점'),
            if (s.maint) const Pill('경정비'),
            if (s.kpetro) const Pill('품질인증'),
          ]),
          if (s.addr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(s.addr, style: T.small),
          ],
          const SizedBox(height: 6),
          Text('오피넷 ${whenText(d.updatedFor(fuel))} 기준 · 주유소가 알린 가격이라 실제와 다를 수 있어요', style: const TextStyle(fontSize: 10.5, color: kMute)),
          const SizedBox(height: 14),
          Row(children: [
            if (s.tel.isNotEmpty) ...[Expanded(child: Btn('전화', icon: 'phone', onTap: () => callTel(s.tel))), const SizedBox(width: 10)],
            Expanded(child: Btn('길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: s.name, lat: s.lat, lng: s.lng))),
          ]),
        ]),
      ),
    );

class _PriceRow extends StatelessWidget {
  final String name;
  final int price;
  final double? avg;
  final bool on;
  const _PriceRow({required this.name, required this.price, required this.avg, required this.on});
  @override
  Widget build(BuildContext context) {
    final diff = avg == null ? null : (price - avg!).round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F1F4)))),
      child: Row(children: [
        Expanded(child: Text(name, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w400))),
        Text('${won(price)}원', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: on ? kBlue : kInk)),
        SizedBox(
          width: 84,
          child: Text(diff == null ? '' : (diff == 0 ? '평균' : (diff < 0 ? '평균 ${-diff}↓' : '평균 $diff↑')),
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: kMute)),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LineIcon('gas', size: 54, fill: kSoftOrange),
            SizedBox(height: 14),
            Text('주유소 가격을 준비하고 있어요', style: T.h2),
            SizedBox(height: 6),
            Text('오피넷 가격이 들어오면 단지에서 가까운 주유소가\n기름별로 싼 순으로 나와요.', textAlign: TextAlign.center, style: T.small),
          ]),
        ),
      );
}
