// 사료량·물 양 계산기 + 몸무게 기록 — 반려동물 테마 방 (대표님 11-26)
// 자료 없이 바로 작동. 하루 필요 열량 = 휴식 에너지(70 × 몸무게^0.75) × 생활 계수 (일반적인 수의 영양 기준)
// 몸무게 기록은 아이마다 'pet.weights' 에 날짜별로 (수첩 몸무게도 함께 바꿈)
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'kids.dart';

// ---------------- 몸무게 기록 ----------------

Future<Map<int, List<(DateTime, double)>>> loadWeights() async {
  final out = <int, List<(DateTime, double)>>{};
  try {
    final j = jsonDecode(await prefGet('pet.weights') ?? '{}');
    if (j is Map) {
      j.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id == null || v is! List) return;
        out[id] = [
          for (final e in v)
            if (e is List && e.length == 2 && DateTime.tryParse('${e[0]}') != null) (DateTime.parse('${e[0]}'), (e[1] as num).toDouble())
        ]..sort((a, b) => a.$1.compareTo(b.$1));
      });
    }
  } catch (_) {}
  return out;
}

Future<void> saveWeights(Map<int, List<(DateTime, double)>> m) => prefSet(
    'pet.weights',
    jsonEncode({
      for (final e in m.entries) '${e.key}': [for (final w in e.value) [w.$1.toIso8601String().substring(0, 10), w.$2]]
    }));

// ---------------- 계산 ----------------

enum Life { puppy, adult, neutered, senior, diet, active }

const kLife = [
  (Life.puppy, '1살 미만', 2.5),
  (Life.adult, '성체', 1.8),
  (Life.neutered, '중성화한 성체', 1.6),
  (Life.senior, '나이 든 아이', 1.4),
  (Life.diet, '살 빼는 중', 1.0),
  (Life.active, '활동량 많음', 2.5),
];
// 고양이는 계수가 조금 낮음
double lifeFactor(Life l, bool cat) {
  final f = kLife.firstWhere((x) => x.$1 == l).$3;
  if (!cat) return f;
  return switch (l) { Life.puppy => 2.5, Life.adult => 1.4, Life.neutered => 1.2, Life.senior => 1.1, Life.diet => 0.8, Life.active => 1.6 };
}

double rer(double kg) => 70 * math.pow(kg, 0.75).toDouble();

class PetCalcPage extends StatefulWidget {
  const PetCalcPage({super.key});
  @override
  State<PetCalcPage> createState() => _PetCalcPageState();
}

class _PetCalcPageState extends State<PetCalcPage> {
  Kid? kid;
  bool cat = false;
  double kg = 5;
  Life life = Life.neutered;
  int kcal100 = 370; // 사료 100g 열량 (포장지에 적힌 값, 보통 330~420)
  Map<int, List<(DateTime, double)>> weights = {};
  final kgCtl = TextEditingController(text: '5');
  final foodCtl = TextEditingController(text: '370');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await loadKids();
    final w = await loadWeights();
    if (!mounted) return;
    setState(() {
      weights = w;
      if (kids.value.isNotEmpty) _pick(kids.value.first);
    });
  }

  void _pick(Kid k) {
    kid = k;
    cat = k.kind == '고양이';
    final last = weights[k.id]?.lastOrNull?.$2;
    final v = last ?? (k.weight > 0 ? k.weight : kg);
    kg = v;
    kgCtl.text = _f(v);
    final b = k.birth;
    final y = b == null ? 3 : DateTime.now().difference(b).inDays / 365.25;
    life = y < 1 ? Life.puppy : (y >= (cat ? 11 : 7) ? Life.senior : Life.neutered);
  }

  String _f(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _record() async {
    final k = kid;
    if (k == null || kg <= 0) return;
    final today = DateTime.now();
    final list = [...?weights[k.id]]..removeWhere((e) => e.$1.year == today.year && e.$1.month == today.month && e.$1.day == today.day);
    list.add((DateTime(today.year, today.month, today.day), kg));
    weights[k.id] = list;
    await saveWeights(weights);
    // 수첩 몸무게도 최신으로
    k.weight = kg;
    await saveKids(kids.value);
    if (!mounted) return;
    setState(() {});
    toast(context, '${k.name} 몸무게 ${_f(kg)}kg 기록했어요');
  }

  @override
  Widget build(BuildContext context) {
    final need = kg > 0 ? rer(kg) * lifeFactor(life, cat) : 0.0;
    final grams = kcal100 > 0 ? need / kcal100 * 100 : 0.0;
    final water = kg * (cat ? 50 : 55);
    final hist = kid == null ? const <(DateTime, double)>[] : (weights[kid!.id] ?? const []);
    return DetailPage(
      title: '사료량·물 계산기',
      icon: 'pet',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
        if (kids.value.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in kids.value) ChoiceChipBox(k.name, on: kid?.id == k.id, onTap: () => setState(() => _pick(k))),
          ]),
          const SizedBox(height: 12),
        ] else ...[
          Wrap(spacing: 6, children: [
            ChoiceChipBox('강아지', on: !cat, onTap: () => setState(() => cat = false)),
            ChoiceChipBox('고양이', on: cat, onTap: () => setState(() => cat = true)),
          ]),
          const SizedBox(height: 12),
        ],
        // 결과 — 맨 위에 크게
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(children: [
            Expanded(child: _big('하루 사료', grams <= 0 ? '-' : '${grams.round()}g', '약 ${need.round()}kcal · 두 번 나누면 ${(grams / 2).round()}g씩')),
            Container(width: 1, height: 54, color: kLine),
            const SizedBox(width: 16),
            Expanded(child: _big('하루 물', water <= 0 ? '-' : '${water.round()}ml', '종이컵 약 ${(water / 180).toStringAsFixed(1)}잔')),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row('몸무게', kgCtl, 'kg', (v) => setState(() => kg = double.tryParse(v) ?? 0)),
            const SizedBox(height: 10),
            _row('사료 100g 열량', foodCtl, 'kcal', (v) => setState(() => kcal100 = int.tryParse(v) ?? 0)),
            Padding(padding: const EdgeInsets.only(top: 4, left: 2), child: Text('사료 포장지 성분표의 「대사 에너지」 값이에요. 모르면 370 그대로 두세요.', style: T.tiny)),
            const SizedBox(height: 14),
            Text('생활', style: T.small),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final l in kLife) ChoiceChipBox(l.$2, on: life == l.$1, onTap: () => setState(() => life = l.$1)),
            ]),
          ]),
        ),
        if (kid != null) ...[
          const SizedBox(height: 14),
          Container(
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: MixTitle(kid!.name, ' 몸무게 기록', size: 14.5)),
                SizedBox(width: 120, child: Btn('오늘 ${_f(kg)}kg 기록', h: 36, primary: true, onTap: _record)),
              ]),
              const SizedBox(height: 12),
              if (hist.length < 2)
                Text(hist.isEmpty ? '기록을 남기면 몸무게 변화가 그래프로 쌓여요.' : '한 번 더 기록하면 그래프가 그려져요.', style: T.small)
              else ...[
                SizedBox(height: 110, child: CustomPaint(size: Size.infinite, painter: _WeightChart(hist))),
                const SizedBox(height: 6),
                Text(_trend(hist), style: const TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Text('일반적인 수의 영양 기준으로 계산한 참고값이에요. 아이 상태에 따라 달라질 수 있으니 2~3주마다 몸무게와 체형을 보고 조절하고, 지병이 있으면 병원 처방을 따라 주세요.', style: T.tiny),
      ]),
    );
  }

  String _trend(List<(DateTime, double)> h) {
    final a = h.first, b = h.last;
    final d = b.$2 - a.$2;
    final days = b.$1.difference(a.$1).inDays;
    if (d.abs() < 0.05) return '$days일 동안 그대로예요';
    final pct = (d / a.$2 * 100).abs();
    return '$days일 동안 ${d > 0 ? '+' : '-'}${_f(d.abs())}kg (${pct.toStringAsFixed(1)}%)${pct >= 10 ? ' · 변화가 커요, 병원과 상의해 보세요' : ''}';
  }

  Widget _big(String label, String value, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.small),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.8)),
        Text(sub, style: T.tiny),
      ]);

  Widget _row(String label, TextEditingController c, String unit, ValueChanged<String> on) => Row(children: [
        SizedBox(width: 104, child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: c,
                  onChanged: on,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                ),
              ),
              Text(unit, style: T.small),
            ]),
          ),
        ),
      ]);
}

class _WeightChart extends CustomPainter {
  final List<(DateTime, double)> h;
  _WeightChart(this.h);
  @override
  void paint(Canvas canvas, Size size) {
    final ws = h.map((e) => e.$2);
    var lo = ws.reduce(math.min), hi = ws.reduce(math.max);
    if (hi - lo < 0.5) {
      lo -= 0.25;
      hi += 0.25;
    }
    final t0 = h.first.$1, span = math.max(1, h.last.$1.difference(t0).inDays);
    Offset at((DateTime, double) e) => Offset(
        8 + (size.width - 16) * e.$1.difference(t0).inDays / span, 10 + (size.height - 28) * (1 - (e.$2 - lo) / (hi - lo)));
    final grid = Paint()..color = const Color(0xFFEDF0F4);
    for (var i = 0; i < 3; i++) {
      final y = 10 + (size.height - 28) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path()..moveTo(at(h.first).dx, at(h.first).dy);
    for (final e in h.skip(1)) {
      path.lineTo(at(e).dx, at(e).dy);
    }
    canvas.drawPath(path, Paint()
      ..color = kBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
    for (final e in h) {
      canvas.drawCircle(at(e), 3, Paint()..color = kBlue);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, Offset o) {
      tp.text = TextSpan(text: s, style: const TextStyle(fontSize: 10, color: kSub));
      tp.layout();
      tp.paint(canvas, o);
    }

    label('${h.first.$1.month}/${h.first.$1.day}', Offset(0, size.height - 14));
    tp.text = TextSpan(text: '${h.last.$1.month}/${h.last.$1.day}', style: const TextStyle(fontSize: 10, color: kSub));
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width, size.height - 14));
  }

  @override
  bool shouldRepaint(_WeightChart o) => o.h != h;
}
