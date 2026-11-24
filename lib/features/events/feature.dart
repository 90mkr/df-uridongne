// 주변 행사·축제 (행사 담당: 본부, 대표님 요청 11-24)
// 홈: 사진 카드 한 줄(가까운 행사 사진 가로 넘김) · 금요일 낮~일요일엔 「지금 우리 단지」에 「이번 주말 근처 행사 ○곳」
// 화면: 지도 먼저 → 거르기 · 목록 · 바텀시트 / 「행사 알리기」(관리자 승인 뒤 공개)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'page.dart';

class EventsFeature extends Feature {
  @override
  String get id => 'events';
  @override
  String get name => '주변 행사·축제';
  @override
  String get icon => 'event';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 6;
  @override
  int get mainOrder => 5;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;

  @override
  Widget? mainCard(BuildContext context, Complex c) => _HomeCard(c: c);

  @override
  Widget page(BuildContext context, Complex c) => EventsPage(c: c);

  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    // 금요일 12시 ~ 일요일
    final wk = now.weekday;
    if (!((wk == DateTime.friday && now.hour >= 12) || wk == DateTime.saturday || wk == DateTime.sunday)) return null;
    final l = await _near(c);
    final r = whenRange(EvWhen.weekend, now);
    final w = l.where((e) => e.overlaps(r.$1, r.$2) && meters(c.pos, e.pos) <= 10000).toList();
    if (w.isEmpty) return null;
    return Brief(
      icon: 'event',
      kicker: '이번 주말 · 10km 안',
      bold: '근처 행사 ',
      hot: '${w.length}곳',
      sub: w.take(2).map((e) => e.title).join(' · '),
      score: wk == DateTime.friday ? 55 : 65,
    );
  }
}

Future<List<Ev>> _near(Complex c) async {
  final a = await autoEvents(c.areaId);
  final l = await localEvents(c);
  return [...l, ...a].where((e) => meters(c.pos, e.pos) <= 30000).toList()..sort((x, y) => x.start.compareTo(y.start));
}

class _HomeCard extends StatefulWidget {
  final Complex c;
  const _HomeCard({required this.c});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  List<Ev>? l;
  @override
  void initState() {
    super.initState();
    _near(widget.c).then((v) {
      if (!mounted) return;
      final now = DateTime.now();
      // 진행 중 → 가까운 날짜 순, 사진 있는 것 먼저
      v.sort((a, b) {
        final la = a.liveAt(now) ? 0 : 1, lb = b.liveAt(now) ? 0 : 1;
        if (la != lb) return la - lb;
        if (a.hasPhoto != b.hasPhoto) return a.hasPhoto ? -1 : 1;
        return a.start.compareTo(b.start);
      });
      setState(() => l = v);
    });
  }

  void _open([Ev? e]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventsPage(c: widget.c)));
    if (e != null) Future.delayed(const Duration(milliseconds: 380), () => mounted ? showEvent(context, e, widget.c) : null);
  }

  @override
  Widget build(BuildContext context) {
    final v = l;
    final now = DateTime.now();
    final wk = whenRange(EvWhen.weekend, now);
    final weekend = v?.where((e) => e.overlaps(wk.$1, wk.$2)).length ?? 0;
    return Container(
      decoration: cardBox(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 10),
            child: Row(children: [
              const LineIcon('event', size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const MixTitle('주변 행사', '·축제', size: 15),
                  const SizedBox(height: 2),
                  Text(
                    v == null
                        ? '불러오는 중…'
                        : v.isEmpty
                            ? '지금 30km 안에 알려진 행사가 없어요'
                            : '30km 안 ${v.length}곳${weekend > 0 ? ' · 이번 주말 $weekend곳' : ''}',
                    style: T.tiny,
                  ),
                ]),
              ),
              const Text('지도로 보기', style: TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
              const Icon(Icons.chevron_right_rounded, color: kSub, size: 20),
            ]),
          ),
        ),
        if (v != null && v.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              scrollDirection: Axis.horizontal,
              itemCount: v.length.clamp(0, 6),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _Tile(e: v[i], c: widget.c, onTap: () => _open(v[i])),
            ),
          ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final Ev e;
  final Complex c;
  final VoidCallback onTap;
  const _Tile({required this.e, required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final live = e.liveAt(DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 190,
          child: Stack(fit: StackFit.expand, children: [
            evPhoto(e),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x00000000), Color(0xB0000000)], stops: [0, 0.45, 1]),
              ),
            ),
            if (live)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: kEvColor[e.kind] ?? kBlue, borderRadius: BorderRadius.circular(20)),
                  child: const Text('진행 중', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 9,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                Text('${e.period} · ${distText(meters(c.pos, e.pos))}', style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 11)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
