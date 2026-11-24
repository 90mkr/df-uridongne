// 단지 앞 버스 — 화면 부품 (대표님 시안 11-24) (이 폴더는 단지 앞 버스 담당 방만 고침)
import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';

const kBusBlue2 = Color(0xFF1D4ED8);
const kBusTint = Color(0xFFEEF3FF);
const kBusGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3B82F6), kBusBlue2]);

/// 그림 머리 (하늘빛 바탕 + 오른쪽 정류장 그림). 뒤로 가기 · 아이콘 · 제목 · 오른쪽 버튼
class BusHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> actions;
  final bool art;
  const BusHeader({super.key, required this.title, this.trailing, this.actions = const [], this.art = true});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + (art ? 120 : 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFEAF2FD)]),
      ),
      child: Stack(children: [
        // 홈 카드와 같은 사진 머리띠 (대표님 사진 11-24) — 글자 쪽만 파랑 필터
        if (art) Positioned.fill(child: IgnorePointer(child: Image.asset('assets/art/bus_bg.jpg', fit: BoxFit.cover, alignment: const Alignment(0.7, 0.1)))),
        if (art)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xF20A5FE0), Color(0xCC1570EA), Color(0x2E1570EA)], stops: [0, 0.45, 0.8]))),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: top + 6,
          child: Row(children: [
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_back_rounded, size: 24, color: art ? Colors.white : kInk)),
            const LineIcon('bus', size: 30),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: art ? Colors.white : kInk)),
            ),
            const Spacer(),
            ...actions,
            if (trailing != null) ...[trailing!, const SizedBox(width: 12)],
          ]),
        ),
      ]),
    );
  }
}

/// 흰 알약 버튼 (지도 · 전체 노선 보기 · 내 정류장으로)
class BusPillBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  const BusPillBtn(this.text, this.icon, this.onTap, {super.key, this.iconColor = kInk});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: kLine), boxShadow: kShadow),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk)),
            ]),
          ),
        ),
      );
}

/// 파란 노선 번호 칸 (버스 아이콘 · 큰 번호 · 종류 테두리 알약)
class RouteBadge extends StatelessWidget {
  final String no, type;
  final bool vertical; // 세로(노선 화면) / 가로(도착 카드)
  final double width;
  final BorderRadius radius;
  const RouteBadge({super.key, required this.no, required this.type, this.vertical = false, this.width = 140, this.radius = const BorderRadius.all(Radius.circular(12))});

  @override
  Widget build(BuildContext context) {
    final big = no.length <= 4;
    final num = Text(no,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: vertical ? (big ? 34 : 26) : (big ? 26 : 20), fontWeight: FontWeight.w800, letterSpacing: -1, color: Colors.white, height: 1.05));
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.85))),
      child: Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
    );
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: vertical ? 10 : 12, vertical: vertical ? 16 : 12),
      decoration: BoxDecoration(gradient: kBusGrad, borderRadius: radius),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.directions_bus_outlined, size: 28, color: Colors.white),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: num),
              const SizedBox(height: 6),
              pill,
            ])
          : Row(children: [
              const Icon(Icons.directions_bus_outlined, size: 30, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: num),
                  const SizedBox(height: 5),
                  pill,
                ]),
              ),
            ]),
    );
  }
}

/// 가는 세로 구분선
Widget busVLine({double h = 26}) => Container(width: 1, height: h, color: kLine);

/// 「｜」 구분 글줄
class BusDotLine extends StatelessWidget {
  final List<InlineSpan> parts;
  final double size;
  const BusDotLine(this.parts, {super.key, this.size = 13});
  @override
  Widget build(BuildContext context) {
    final out = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) out.add(const TextSpan(text: '   |   ', style: TextStyle(color: Color(0xFFC9CED8))));
      out.add(parts[i]);
    }
    return Text.rich(TextSpan(children: out), style: TextStyle(fontSize: size, color: kSub, height: 1.35));
  }
}
