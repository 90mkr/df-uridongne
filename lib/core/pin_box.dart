// 지도 점 모양 (본부): 콕플처럼 흰 상자 안에 색 아이콘 + 상호 (대표님 11-24 — 아이콘 아래 글씨는 잘 안 보임)
// 휴대폰 네이버 지도(그림으로 찍음)와 웹 미리보기 지도가 같은 모양을 쓴다.
import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

String pinLabel(String name) => name.length > 9 ? '${name.substring(0, 9)}…' : name;

/// 상자 크기 (그림으로 찍을 때 필요) — 글자 수로 어림
Size pinBoxSize(String name) {
  final t = pinLabel(name);
  var w = 0.0;
  for (final r in t.runes) {
    w += r > 0x3000 ? 11.6 : 6.6;
  }
  return Size((8 + 20 + 4 + w + 10).clamp(44, 170).toDouble(), 36);
}

class PinBox extends StatelessWidget {
  final String icon, name;
  final bool on;
  const PinBox({super.key, required this.icon, required this.name, this.on = false});
  @override
  Widget build(BuildContext context) {
    final sz = pinBoxSize(name);
    return SizedBox(
      width: sz.width,
      height: sz.height,
      child: Column(children: [
        Container(
          height: 29,
          padding: const EdgeInsets.fromLTRB(5, 0, 8, 0),
          decoration: BoxDecoration(
            color: on ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? kBlue : const Color(0xFFC9D1DE)),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 5)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: on ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)) : null,
              child: LineIcon(icon, size: 18),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(pinLabel(name),
                  maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.3, color: on ? Colors.white : kInk)),
            ),
          ]),
        ),
        CustomPaint(size: const Size(10, 6), painter: _Tip(on ? kBlue : Colors.white, on ? kBlue : const Color(0xFFC9D1DE))),
      ]),
    );
  }
}

class _Tip extends CustomPainter {
  final Color fill, line;
  _Tip(this.fill, this.line);
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(0, -1)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(s.width, -1);
    c.drawPath(p..close(), Paint()..color = fill);
    c.drawPath(Path()..moveTo(0, 0)..lineTo(s.width / 2, s.height)..lineTo(s.width, 0), Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_Tip o) => o.fill != fill;
}
