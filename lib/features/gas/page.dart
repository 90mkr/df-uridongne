// 주유소 상세 화면 (주유소 담당 방만 고침)
// 위: 기름 고르기 · 반경 · 「가장 싼 곳」 요약   아래: 싼 순 목록  ↔  「지도로 보기」(말풍선에 가격)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

class GasPage extends StatefulWidget {
  final Complex c;
  const GasPage(this.c, {super.key});
  @override
  State<GasPage> createState() => _GasPageState();
}

class _GasPageState extends State<GasPage> {
  String fuel = 'B027';
  int radius = 3000;
  bool showMap = false;
  bool loading = true;
  GasData? data;
  String? sel;
  final map = MapController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final f = await prefGet('gas.fuel');
    final r = int.tryParse(await prefGet('gas.radius') ?? '');
    final d = await loadGas(widget.c.areaId);
    if (!mounted) return;
    setState(() {
      if (f != null && kFuels.any((x) => x.$1 == f)) fuel = f;
      if (r != null && kRadii.contains(r)) radius = r;
      data = d;
      loading = false;
    });
  }

  double get zoom => radius <= 2000 ? 13.6 : (radius <= 3000 ? 13.0 : 12.3);

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
    if (showMap) {
      try {
        map.move(widget.c.pos, zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final list = d == null ? <GasStation>[] : d.around(widget.c.pos, fuel, radius);
    return DetailPage(
      title: '주유소',
      icon: 'gas',
      actions: [
        if (d != null && d.stations.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() {
              showMap = !showMap;
              sel = null;
            }),
            icon: LineIcon(showMap ? 'list' : 'map', size: 18),
            label: Text(showMap ? '목록으로 보기' : '지도로 보기', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
          ),
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : d == null || d.stations.isEmpty
              ? const _Empty()
              : Column(children: [
                  _controls(),
                  _summary(d, list),
                  Container(height: 1, color: kLine),
                  Expanded(child: showMap ? _map(d, list) : _list(d, list)),
                ]),
    );
  }

  // 기름 · 반경
  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in kFuels) ...[
                ChoiceChipBox(f.$2, on: fuel == f.$1, onTap: () => _fuel(f.$1)),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('단지에서', style: T.small),
            const SizedBox(width: 6),
            for (final r in kRadii)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _radius(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  child: Text('${r ~/ 1000}km',
                      style: TextStyle(fontSize: 12.5, fontWeight: radius == r ? FontWeight.w700 : FontWeight.w400, color: radius == r ? kInk : kMute)),
                ),
              ),
          ]),
        ]),
      );

  // 가장 싼 곳 · 시도 평균
  Widget _summary(GasData d, List<GasStation> list) {
    final best = list.isEmpty ? null : list.first;
    final avg = d.avg[fuel];
    final bp = best?.price(fuel);
    final gap = (avg != null && bp != null) ? (avg - bp).round() : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('반경 ${radius ~/ 1000}km 가장 싼 ${fuelName(fuel)}', style: T.small),
              const SizedBox(height: 2),
              if (best != null && bp != null) ...[
                Text.rich(TextSpan(children: [
                  TextSpan(text: won(bp), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.8, height: 1.1)),
                  const TextSpan(text: ' 원', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: kInk)),
                ])),
                const SizedBox(height: 2),
                Text('${best.name} · ${distText(best.dist)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
              ] else
                const Text('이 반경엔 파는 곳이 없어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.6)),
            ]),
          ),
          if (avg != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${d.sido} 평균', style: T.tiny),
              Text('${won(avg)}원', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
              if (gap != null && gap > 0) Text('$gap원 싸요', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kInk)),
            ]),
        ]),
        const SizedBox(height: 8),
        Text('오피넷 ${whenText(d.updated)} 기준 · 실제 가격은 주유소에서 다를 수 있어요', style: const TextStyle(fontSize: 10.5, color: kMute)),
      ]),
    );
  }

  // 싼 순 목록
  Widget _list(GasData d, List<GasStation> list) {
    if (list.isEmpty) {
      return ListView(padding: const EdgeInsets.all(kPad), children: [
        const SizedBox(height: 20),
        Text('단지에서 ${radius ~/ 1000}km 안에 ${fuelName(fuel)}을 파는 곳이 없어요', textAlign: TextAlign.center, style: T.small),
        if (radius < kRadii.last) ...[
          const SizedBox(height: 14),
          Center(child: SizedBox(width: 180, child: Btn('${kRadii.last ~/ 1000}km까지 보기', h: 40, onTap: () => _radius(kRadii.last)))),
        ],
      ]);
    }
    final avg = d.avg[fuel];
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F4), indent: kPad, endIndent: kPad),
      itemBuilder: (ctx, i) {
        final s = list[i];
        final p = s.price(fuel)!;
        final diff = avg == null ? null : (p - avg).round();
        final cheapest = p == list.first.price(fuel);
        return InkWell(
          onTap: () => showStation(ctx, s, fuel, d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 11),
            child: Row(children: [
              SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: i == 0 ? kInk : kMute))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
                  const SizedBox(height: 1),
                  Text([brandName(s.brand), distText(s.dist), if (s.self) '셀프'].where((x) => x.isNotEmpty).join(' · '), style: T.tiny),
                ]),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: won(p), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: cheapest ? kBlue : kInk)),
                  const TextSpan(text: '원', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w300)),
                ])),
                if (diff != null) Text(diff == 0 ? '평균과 같아요' : (diff < 0 ? '평균보다 ${-diff}원↓' : '평균보다 $diff원↑'), style: const TextStyle(fontSize: 10.5, color: kMute)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // 지도: 주유소마다 말풍선에 가격, 가장 싼 곳은 파랑
  Widget _map(GasData d, List<GasStation> list) {
    final c = widget.c;
    final minP = list.isEmpty ? null : list.first.price(fuel); // 같은 최저가가 여럿이면 모두 파랑
    final picked = list.where((s) => s.id == sel).firstOrNull;
    // 고른 것이 맨 위에 오게
    final order = [...list.reversed.where((s) => s.id != sel), if (picked != null) picked];
    return Stack(children: [
      FlutterMap(
        mapController: map,
        options: MapOptions(
          initialCenter: c.pos,
          initialZoom: zoom,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onTap: (_, __) => setState(() => sel = null),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
          CircleLayer(circles: [
            CircleMarker(
              point: c.pos,
              radius: radius.toDouble(),
              useRadiusInMeter: true,
              color: kBlue.withValues(alpha: 0.035),
              borderColor: kBlue.withValues(alpha: 0.3),
              borderStrokeWidth: 1,
            ),
          ]),
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
            for (final s in order)
              Marker(
                point: s.pos,
                width: 70,
                height: 30,
                alignment: Alignment.topCenter,
                child: _Bubble(
                  price: s.price(fuel)!,
                  best: s.price(fuel) == minP,
                  on: s.id == sel,
                  onTap: () => setState(() => sel = s.id),
                ),
              ),
          ]),
          const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
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
          Text('오피넷 ${whenText(d.updated)} 기준 · 주유소가 알린 가격이라 실제와 다를 수 있어요', style: const TextStyle(fontSize: 10.5, color: kMute)),
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
