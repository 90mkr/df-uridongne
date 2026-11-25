// 시세 흐름 그림 (실거래가 방만 고침): 카드용 작은 흐름선 · 상세 화면 1년 흐름
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'data.dart';

// 달마다 평균 (오래된 달 → 최근 달)
List<(int, double)> monthlyAvg(List<Sale> sales) {
  final m = <int, List<int>>{};
  for (final s in sales) {
    (m[s.ym] ??= []).add(s.price);
  }
  final keys = m.keys.toList()..sort();
  return [for (final k in keys) (k, m[k]!.reduce((a, b) => a + b) / m[k]!.length)];
}

class Spark extends StatelessWidget {
  final List<Sale> sales;
  const Spark({super.key, required this.sales});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SparkPainter(monthlyAvg(sales)));
}

class _SparkPainter extends CustomPainter {
  final List<(int, double)> pts;
  _SparkPainter(this.pts);
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final lo = pts.map((p) => p.$2).reduce(math.min), hi = pts.map((p) => p.$2).reduce(math.max);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    Offset at(int i) => Offset(size.width * i / (pts.length - 1), size.height - 4 - (pts[i].$2 - lo) / span * (size.height - 8));
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBlue.withValues(alpha: 0.16), kBlue.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()
      ..color = kBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(at(pts.length - 1), 2.6, Paint()..color = kBlue);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.pts != pts;
}

// 상세 화면: 거래 하나하나 점 + 달 평균 선 (최근 13달)
class FlowChart extends StatelessWidget {
  final List<Sale> sales;
  final List<int> months; // yyyymm 오래된 → 최근
  const FlowChart({super.key, required this.sales, required this.months});
  @override
  Widget build(BuildContext context) => SizedBox(height: 150, child: CustomPaint(painter: _FlowPainter(sales, months), size: Size.infinite));
}

class _FlowPainter extends CustomPainter {
  final List<Sale> sales;
  final List<int> months;
  _FlowPainter(this.sales, this.months);

  @override
  void paint(Canvas canvas, Size size) {
    if (sales.isEmpty || months.isEmpty) return;
    const left = 42.0, bottom = 18.0, top = 8.0;
    final w = size.width - left - 4, h = size.height - bottom - top;
    var lo = sales.map((s) => s.price).reduce(math.min).toDouble(), hi = sales.map((s) => s.price).reduce(math.max).toDouble();
    if (hi - lo < hi * 0.06) {
      lo -= hi * 0.04;
      hi += hi * 0.04;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;
    double x(int ym, int day) {
      final i = months.indexOf(ym);
      return left + w * ((i < 0 ? 0 : i) + (day.clamp(1, 28) - 1) / 28) / months.length;
    }

    double y(double p) => top + h - (p - lo) / (hi - lo) * h;
    final grid = Paint()
      ..color = kLine
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var k = 0; k < 3; k++) {
      final v = lo + (hi - lo) * (0.15 + 0.35 * k);
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), grid);
      tp.text = TextSpan(text: wonShort(v.round()), style: const TextStyle(fontSize: 9.5, color: kMute));
      tp.layout();
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }
    for (var i = 0; i < months.length; i += 3) {
      tp.text = TextSpan(text: '${months[i] % 100}월', style: const TextStyle(fontSize: 9.5, color: kMute));
      tp.layout();
      tp.paint(canvas, Offset(left + w * i / months.length, size.height - tp.height));
    }
    // 달 평균 선
    final avg = monthlyAvg(sales);
    if (avg.length >= 2) {
      final path = Path();
      for (var i = 0; i < avg.length; i++) {
        final o = Offset(x(avg[i].$1, 15), y(avg[i].$2));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, Paint()
        ..color = kBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round);
    }
    // 거래 점
    final dot = Paint()..color = kBlue.withValues(alpha: 0.28);
    for (final s in sales) {
      canvas.drawCircle(Offset(x(s.ym, s.ymd % 100), y(s.price.toDouble())), 3, dot);
    }
    final last = sales.first;
    canvas.drawCircle(Offset(x(last.ym, last.ymd % 100), y(last.price.toDouble())), 4, Paint()..color = kBlue);
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) => old.sales != sales;
}
