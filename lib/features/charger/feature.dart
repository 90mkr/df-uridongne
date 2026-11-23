// 전기차 충전소 (이 폴더는 충전소 담당 방만 고침)
// 단지 가까운 충전소 목록·지도, 충전기별 상태, 내 차 단자 맞춤, 빈자리 알림, 충전 타이머, 요금, 이용 조건, 고장 제보.
// 자료: 환경부 전기자동차 충전소 정보 (collector/features/charger.py 가 모으고, 앱은 가까운 곳 상태만 실시간으로 받음)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'page.dart';

class ChargerFeature extends Feature {
  @override
  String get id => 'charger';
  @override
  String get name => '충전소';
  @override
  String get icon => 'charger';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 20;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftGreen;

  @override
  Widget page(BuildContext context, Complex c) => ChargerPage(complex: c);

  // 단지 홈 본문: 「충전소 찾기」 (가장 가까운, 빈 충전기 있는 곳) — 자료 없으면 빈칸
  @override
  Widget? mainCard(BuildContext context, Complex c) => _NearCard(f: this, c: c);
  @override
  int get mainOrder => 1;

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final set = await stationsOf(c.areaId);
    final near = set.all.where((s) => meters(c.pos, s.pos) <= 3000).toList()
      ..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    return [
      for (final s in near.take(200))
        MapPoint(
          id: 'ev_${s.id}',
          name: s.name,
          sub: s.hasFast ? '급속' : '완속',
          badge: '빈 ${s.freeOf(null)}/${s.chargers.length}',
          pos: s.pos,
          onTap: (ctx) => showStation(ctx, s, c),
        ),
    ];
  }
}

class _NearCard extends StatelessWidget {
  final Feature f;
  final Complex c;
  const _NearCard({required this.f, required this.c});

  Future<(Station, int, int)?> _load() async {
    final set = await stationsOf(c.areaId);
    await loadMyPlugs();
    final mine = myPlugs.value;
    final near = set.all.where((s) => meters(c.pos, s.pos) <= 3000 && s.pick(plugs: mine).isNotEmpty).toList()
      ..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    if (near.isEmpty) return null;
    int free(Station s) => s.pick(plugs: mine).where((x) => x.use == Use.free).length;
    final best = near.firstWhere((s) => free(s) > 0, orElse: () => near.first);
    final spots = near.where((s) => free(s) > 0).length;
    return (best, free(best), spots);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(Station, int, int)?>(
        future: _load(),
        builder: (_, snap) {
          final r = snap.data;
          if (r == null) return const SizedBox.shrink();
          final (s, free, spots) = r;
          return MainRowCard(
            icon: 'charger',
            bold: '충전소',
            thin: '찾기',
            sub: '${s.name} · ${distText(meters(c.pos, s.pos))}${s.hasFast ? ' · 급속' : ''}',
            trailing: MainValue(free > 0 ? '빈 $free' : '꽉 참', spots > 0 ? '3km 안 $spots곳 비어요' : '3km 안'),
            onTap: () => openFeature(context, f),
          );
        },
      );
}
