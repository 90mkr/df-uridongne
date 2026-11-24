// 지금 문 연 약국 (이 폴더는 지금 문 연 약국 담당 방만 고침)
// 단지 홈 반쪽 카드: 가장 가까운 지금 연 약국 · 몇 시까지 · 외 ○곳 · 전화 버튼 (연휴 3일 전부터 「연휴에 문 여는 약국」)
// 상세 화면: 전체 / 지금 영업 중 / 밤 10시 이후, 시각 골라 미리 보기, 영업시간 막대, 지도(상태 색 핀), 연휴 약국, 상비약 편의점·소아과·응급실
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'page.dart';

class PharmacyFeature extends Feature {
  @override
  String get id => 'pharmacy';
  @override
  String get name => '지금 문 연 약국';
  @override
  String get icon => 'pharm';
  @override
  Slot get slot => Slot.half;
  @override
  int get order => 20;
  @override
  String get version => '0.3.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftGreen;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HomeCard(feature: this, complex: c);

  @override
  Widget page(BuildContext context, Complex c) => PharmacyPage(complex: c);

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final now = DateTime.now();
    final list = await placesNear(c.pos, r: 3000);
    return [
      for (final p in list.where((p) => p.isPharm))
        if (p.stateAt(now) case final s when s.open)
          MapPoint(
            id: 'pharmacy.${p.id}',
            name: p.name,
            sub: '${distText(meters(c.pos, p.pos))} · ${s.untilText}',
            pos: p.pos,
            onTap: (ctx) => showPlace(ctx, p, c),
          ),
    ];
  }
}

class _HomeCard extends StatefulWidget {
  final PharmacyFeature feature;
  final Complex complex;
  const _HomeCard({required this.feature, required this.complex});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  late Future<List<Place>> _f;

  @override
  void initState() {
    super.initState();
    _f = placesNear(widget.complex.pos, r: 5000);
  }

  @override
  void didUpdateWidget(covariant _HomeCard old) {
    super.didUpdateWidget(old);
    if (old.complex.id != widget.complex.id) _f = placesNear(widget.complex.pos, r: 5000);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature, c = widget.complex;
    return FutureBuilder<List<Place>>(
      future: _f,
      builder: (context, snap) {
        Widget body;
        String? foot;
        Place? callTo;
        if (snap.connectionState != ConnectionState.done) {
          body = const ComingSoon('찾고 있어요…');
        } else {
          final now = DateTime.now();
          final pharm = (snap.data ?? const <Place>[]).where((p) => p.isPharm).toList();
          if (pharm.isEmpty) {
            body = const ComingSoon('약국 자료를 모으고 있어요');
          } else {
            final open = [for (final p in pharm) if (p.stateAt(now).open) p];
            final run = holidayRun(now);
            if (open.isNotEmpty) {
              final p = open.first, s = p.stateAt(now);
              callTo = p;
              foot = run.isNotEmpty ? '연휴에 문 여는 약국 보기 ›' : (open.length > 1 ? '5km 안 ${open.length}곳 영업 중 ›' : '5km 안 1곳 영업 중');
              final more = open.skip(1).take(2).toList();
              body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.25)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${distText(meters(c.pos, p.pos))} · '),
                    s.closingSoon
                        ? const TextSpan(text: '곧 마감', style: TextStyle(color: kWarn, fontWeight: FontWeight.w700))
                        : TextSpan(text: s.untilText, style: const TextStyle(color: kOpenC, fontWeight: FontWeight.w600)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small,
                ),
                // 가로 한 줄 전체일 때: 다음으로 가까운 영업 중 약국 두 곳
                if (more.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final m in more)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
                        child: Text('${m.name} · ${distText(meters(c.pos, m.pos))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, letterSpacing: -0.3)),
                      ),
                  ]),
                ],
              ]);
            } else {
              final p = pharm.first, s = p.stateAt(now);
              foot = holidayRun(now).isNotEmpty ? '연휴에 문 여는 약국 보기 ›' : '가까운 곳: ${p.name}';
              body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('지금 연 곳이 없어요', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 3),
                Text(s.next.isEmpty ? '응급실·편의점 보기' : '${s.next} 열어요', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]);
            }
          }
        }
        return HomeCardBox(
          icon: f.icon,
          title: '문 연 약국',
          foot: foot,
          onTap: () => openFeature(context, f),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: body),
            if (callTo != null && callTo.tel.isNotEmpty) ...[
              const SizedBox(width: 6),
              _CallMini(tel: callTo.tel, label: '${callTo.name} 전화', big: true),
            ],
          ]),
        );
      },
    );
  }
}

class _CallMini extends StatelessWidget {
  final String tel, label;
  final bool big;
  const _CallMini({required this.tel, required this.label, this.big = false});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => callTel(tel),
          child: Container(
            width: big ? 46 : 34,
            height: big ? 46 : 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(big ? 12 : 9), border: Border.all(color: kLine)),
            child: LineIcon('phone', size: big ? 24 : 20, fill: kSoft),
          ),
        ),
      );
}
