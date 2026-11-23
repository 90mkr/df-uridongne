// 쓰레기·분리수거 (이 폴더는 쓰레기·분리수거 담당 방만 고침)
// 단지 홈 맨 위 파랑 카드 「오늘의 단지 소식」 + 상세 화면(이번 주 배출표·방법·대형폐기물·품목 사전·우리 단지 요일 입력)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'page.dart';
import 'trash_icons.dart';

class TrashFeature extends Feature {
  @override
  String get id => 'trash';
  @override
  String get name => '쓰레기·분리수거';
  @override
  String get icon => 'trash';
  @override
  Slot get slot => Slot.tool; // 대표님 11-24: 홈 맨 위 자리는 비우고, 배출 안내는 분리수거 화면 맨 위로
  @override
  int get order => 10;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget? homeCard(BuildContext context, Complex c) => TrashHero(c: c, f: this);

  @override
  Widget page(BuildContext context, Complex c) => TrashPage(complex: c);

  // 「지금 우리 단지」 카드: 오늘 배출일이면 저녁에 높게
  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    final info = await trashOf(c);
    if (info.empty) return null;
    final today = info.kindsOn(now);
    if (today.isNotEmpty) {
      final h = rangeText(info.hoursOf(today.first));
      return Brief(
        icon: 'trash',
        kicker: '오늘의 배출 안내',
        bold: '오늘은 ',
        hot: today.map((k) => kKindShort[k]).join('·'),
        rest: ' 배출일',
        sub: h.isEmpty ? '정해진 장소에 내 주세요' : '$h 사이에 내 주세요',
        score: now.hour >= 15 ? 85 : 55,
      );
    }
    final n = info.nextDay(now);
    if (n == null) return null;
    final tomorrow = n.difference(DateTime(now.year, now.month, now.day)).inDays == 1;
    return Brief(
      icon: 'trash',
      kicker: '오늘의 배출 안내',
      bold: '오늘은 배출하지 않는 날',
      sub: '${tomorrow ? '내일' : '${dayChar(n)}요일'} ${info.kindsOn(n).map((k) => kKindShort[k]).join('·')} 배출',
      score: 25,
    );
  }
}

// 오늘의 배출 안내 카드 (분리수거 화면 맨 위)
class TrashHero extends StatelessWidget {
  final Complex c;
  final Feature? f; // 있으면 누를 때 분리수거 화면 열기
  const TrashHero({super.key, required this.c, this.f});

  static const _w = Color(0xD9FFFFFF);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: trashTick,
        builder: (context, _, __) => FutureBuilder<TrashInfo>(
          key: ValueKey('${c.id}-${trashTick.value}'),
          future: trashOf(c),
          builder: (context, snap) {
            final info = snap.data;
            final now = DateTime.now();
            String bold, thin, sub;
            List<String> today = const [];
            if (info == null) {
              bold = '쓰레기';
              thin = '배출일을 확인하고 있어요';
              sub = '잠시만 기다려 주세요';
            } else if (info.empty && info.needPick) {
              bold = '배출 구역';
              thin = '을 골라 주세요';
              sub = '${info.gov!.gu}는 구역마다 배출 요일이 달라요';
            } else if (info.empty) {
              bold = '우리 단지';
              thin = '배출 요일을 알려 주세요';
              sub = '관리사무소가 정한 요일을 넣으면 이웃과 함께 봐요';
            } else {
              today = info.kindsOn(now);
              if (today.isNotEmpty) {
                bold = '오늘은';
                thin = '${today.map((k) => kKindShort[k]).join('·')} 배출일';
                final h = rangeText(info.hoursOf(today.first));
                sub = h.isEmpty ? '정해진 장소에 내 주세요' : '$h 사이에 내 주세요';
              } else {
                bold = '오늘은';
                thin = '배출하지 않는 날';
                final n = info.nextDay(now);
                sub = n == null
                    ? '이번 주 배출 요일을 확인해 주세요'
                    : '${n.difference(DateTime(now.year, now.month, now.day)).inDays == 1 ? '내일' : '${dayChar(n)}요일'} ${info.kindsOn(n).map((k) => kKindShort[k]).join('·')} 배출';
              }
            }
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: f == null ? null : () => openFeature(context, f!),
              child: Container(
                // 시안 11-23 (본부): 짙은 파랑 그라데이션 + 오른쪽 위 단지 그림
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1570EA), Color(0xFF0B4DBA)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF0B4DBA).withValues(alpha: 0.18), blurRadius: 18)],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    width: 236,
                    bottom: info != null && !info.empty ? 58 : 0,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0x8C000000), Color(0xE6000000)], stops: [0, 0.5, 1]).createShader(r),
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF000000), Color(0x00000000)], stops: [0.6, 1]).createShader(r),
                        child: Image.asset('assets/art/hero.png', fit: BoxFit.cover, alignment: Alignment.centerRight, filterQuality: FilterQuality.medium),
                      ),
                    ),
                  ),
                  Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('오늘의 배출 안내${info?.fromApt == true ? ' · 우리 단지 요일' : ''}', style: const TextStyle(fontSize: 11, color: _w)),
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w800)),
                            // 「일반·음식물 배출일」 → 종류만 노랑으로 강조
                            if (thin.endsWith(' 배출일')) ...[
                              TextSpan(text: thin.substring(0, thin.length - 4), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFFD84D))),
                              const TextSpan(text: ' 배출일', style: TextStyle(fontWeight: FontWeight.w800)),
                            ] else
                              TextSpan(text: thin, style: const TextStyle(fontWeight: FontWeight.w400)),
                          ]),
                          style: const TextStyle(fontSize: 20, color: Colors.white, letterSpacing: -0.6, height: 1.3, shadows: [Shadow(color: Color(0x33000000), blurRadius: 6)]),
                        ),
                        const SizedBox(height: 3),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _w)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    TrashIcon(today.isNotEmpty ? today.first : 'g', size: 46, line: Colors.white, fill: const Color(0x38FFFFFF)),
                  ]),
                  if (info != null && !info.empty) ...[
                    const SizedBox(height: 14),
                    _Week(info: info, now: now),
                  ],
                ]),
              ),
                ]),
              ),
            );
          },
        ),
      );
}

// 파랑 카드 아래 이번 주 7칸 (오늘부터)
class _Week extends StatelessWidget {
  final TrashInfo info;
  final DateTime now;
  const _Week({required this.info, required this.now});

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _cell(now.add(Duration(days: i)), i == 0)),
        ],
      ]);

  Widget _cell(DateTime d, bool today) {
    final ks = info.kindsOn(d);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: today ? Colors.white : const Color(0xFF0A3F99).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: today ? 1 : 0.16)),
      ),
      child: Column(children: [
        Text(today ? '오늘' : dayChar(d), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: today ? kBlue : Colors.white)),
        const SizedBox(height: 3),
        SizedBox(
          height: 14,
          child: ks.isEmpty
              ? Text('·', style: TextStyle(fontSize: 11, height: 1.1, color: today ? kMute : const Color(0x99FFFFFF)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final k in ks) TrashIcon(k, size: 14, line: today ? kInk : Colors.white, fill: today ? kSoft : const Color(0x33FFFFFF)),
                ]),
        ),
      ]),
    );
  }
}
