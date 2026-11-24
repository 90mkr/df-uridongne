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
  Slot get slot => Slot.tool; // 대표님 11-24: 낮엔 덜 중요 — 홈은 한 줄 카드(아래쪽)로, 밤엔 「지금 우리 단지」에 뜸
  @override
  int get order => 20;
  @override
  String get version => '0.3.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftGreen;

  @override
  Widget? mainCard(BuildContext context, Complex c) => _RowCard(f: this, c: c);
  @override
  int get mainOrder => 4;

  // 밤(9시~아침 9시)·주말엔 「지금 우리 단지」 맨 위 카드에 지금 연 약국을 띄운다
  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    final night = now.hour >= 21 || now.hour < 9;
    final weekend = now.weekday >= DateTime.saturday;
    if (!night && !weekend) return null;
    final list = (await placesNear(c.pos, r: 5000)).where((p) => p.isPharm && p.stateAt(now).open).toList();
    if (list.isEmpty) return null;
    final p = list.first;
    return Brief(
      icon: 'pharm',
      kicker: night ? '밤에도 · 지금 문 연 약국' : '주말 · 지금 문 연 약국',
      bold: p.name,
      rest: ' ${distText(meters(c.pos, p.pos))}',
      sub: '${p.stateAt(now).untilText}${list.length > 1 ? ' · 5km 안 ${list.length}곳 영업 중' : ''}',
      score: night ? 75 : 45,
    );
  }

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

// 단지 홈 한 줄 카드: 가장 가까운 지금 연 약국 · 몇 시까지 · 전화
class _RowCard extends StatefulWidget {
  final PharmacyFeature f;
  final Complex c;
  const _RowCard({required this.f, required this.c});
  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  late Future<List<Place>> _f = placesNear(widget.c.pos, r: 5000);

  @override
  void didUpdateWidget(covariant _RowCard old) {
    super.didUpdateWidget(old);
    if (old.c.id != widget.c.id) _f = placesNear(widget.c.pos, r: 5000);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Place>>(
        future: _f,
        builder: (context, snap) {
          final now = DateTime.now();
          final pharm = (snap.data ?? const <Place>[]).where((p) => p.isPharm).toList();
          final open = [for (final p in pharm) if (p.stateAt(now).open) p];
          String sub;
          Widget? trailing;
          if (snap.connectionState != ConnectionState.done) {
            sub = '찾고 있어요…';
          } else if (pharm.isEmpty) {
            sub = '약국 자료를 모으고 있어요';
          } else if (open.isEmpty) {
            final s = pharm.first.stateAt(now);
            sub = '지금 연 곳이 없어요${s.next.isEmpty ? '' : ' · ${s.next} 열어요'}';
          } else {
            final p = open.first, s = p.stateAt(now);
            sub = '${p.name} · ${distText(meters(widget.c.pos, p.pos))} · ${s.closingSoon ? '곧 마감' : s.untilText}';
            if (p.tel.isNotEmpty) trailing = _CallMini(tel: p.tel, label: '${p.name} 전화', big: true);
          }
          return MainRowCard(
            icon: 'pharm',
            bold: '문 연',
            thin: '약국',
            sub: sub,
            subLines: 1,
            trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: kSub),
            onTap: () => openFeature(context, widget.f),
          );
        },
      );
}
