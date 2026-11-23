// 동네 전화번호부 — 명함 카드 (지도 아래 넘기는 줄 · 목록 · 태블릿 왼쪽 목록 모두 같은 카드)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const kCardH = 174.0; // 카드마다 같은 크기

class ShopCard extends StatelessWidget {
  final Shop shop;
  final Complex complex;
  final bool selected;
  final VoidCallback? onTap;
  final int maxStickers;
  const ShopCard({super.key, required this.shop, required this.complex, this.selected = false, this.onTap, this.maxStickers = 2});

  @override
  Widget build(BuildContext context) {
    final s = shop;
    final rec = recsOf(complex.areaId)[s.id];
    final open = s.openAt(DateTime.now());
    final lot = nearestLot(s.pos);
    final cat = s.cats.isEmpty ? '' : catOf(s.cats.first).name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: kCardH,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: selected ? kBlue : kLine, width: 1),
            boxShadow: kShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Thumb(s),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3)),
                    ),
                    if (s.owned) ...[
                      const SizedBox(width: 6),
                      const Pill('사장님 직접 관리', color: kBlue, bg: Color(0xFFEEF3FF)),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text([if (s.sub.isNotEmpty) s.sub, if (cat.isNotEmpty && cat != s.sub) cat].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub, height: 1.3)),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (open != Open.unknown) ...[OpenMark(open), const Text('  ·  ', style: TextStyle(fontSize: 11.5, color: kMute))],
                    Text('단지에서 ${distText(meters(complex.pos, s.pos))}', style: const TextStyle(fontSize: 11.5, color: kSub)),
                  ]),
                  const SizedBox(height: 5),
                  _RecLine(rec: rec, max: maxStickers),
                ]),
              ),
            ]),
            const Spacer(),
            // 근처 주차장 (없으면 주소)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(children: [
                if (lot != null)
                  Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFF9AA1AC))),
                    child: const Text('P', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: kSub, height: 1)),
                  )
                else
                  const LineIcon('pin', size: 16, line: Color(0xFF9AA1AC), fill: Colors.transparent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      lot != null ? '근처 주차장  ${lot.name} ${distText(lot.m)}${lot.fee.isEmpty ? '' : ' · ${lot.fee}'}' : (s.addr.isEmpty ? '주소 정보 없음' : s.addr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: kSub)),
                ),
              ]),
            ),
            Row(children: [
              Expanded(
                child: Btn(s.tel.isEmpty ? '번호 없음' : '전화하기', icon: 'phone', primary: s.tel.isNotEmpty, h: 36, onTap: s.tel.isEmpty ? null : () => callTel(s.tel)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Btn('길안내', icon: 'route', h: 36, onTap: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Shop s;
  const _Thumb(this.s);
  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(10));
    if (s.photo.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(s.photo, width: 62, height: 62, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon(box)),
      );
    }
    return _icon(box);
  }

  Widget _icon(BoxDecoration box) => Container(
        width: 62,
        height: 62,
        decoration: box,
        alignment: Alignment.center,
        child: LineIcon(s.cats.isEmpty ? 'pin' : s.cats.first, size: 34),
      );
}

// 영업 상태 표시 (점 + 글자)
class OpenMark extends StatelessWidget {
  final Open o;
  const OpenMark(this.o, {super.key});
  @override
  Widget build(BuildContext context) {
    final (t, c) = switch (o) {
      Open.open => ('영업 중', kBlue),
      Open.closing => ('곧 마감', const Color(0xFFE07A10)),
      Open.closed => ('영업 종료', kMute),
      Open.unknown => ('', kMute),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
    ]);
  }
}

class _RecLine extends StatelessWidget {
  final RecSum? rec;
  final int max;
  const _RecLine({required this.rec, required this.max});
  @override
  Widget build(BuildContext context) {
    final r = rec;
    if (r == null || r.n == 0) {
      return const Text('이웃 추천 0', style: TextStyle(fontSize: 12, color: kMute));
    }
    return Row(children: [
      Text('이웃 추천 ${r.n}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      for (final st in r.topStickers.take(max)) ...[
        const SizedBox(width: 5),
        Flexible(child: Pill(stickerText(st), color: kSub)),
      ],
    ]);
  }
}
