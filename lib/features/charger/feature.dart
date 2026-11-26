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
  String get version => '0.3.3';
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
          badge: '빈곳 ${s.freeOf(null)}/${s.chargers.length}',
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

  // (가장 가까운 빈 곳, 그곳 빈 칸, 가까운 5곳 빈 칸 합, 지금 상태를 받았는지)
  Future<(Station, int, int, bool)?> _load() async {
    final set = await stationsOf(c.areaId);
    await loadMyPlugs();
    final mine = myPlugs.value;
    final near = set.all.where((s) => meters(c.pos, s.pos) <= 3000 && s.pick(plugs: mine).isNotEmpty).toList()
      ..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    if (near.isEmpty) return null;
    // 가까운 5곳은 지금 상태를 받아 온다 (안 받으면 모아 둔 숫자가 그대로 보임)
    final got = await refreshMany(near, max: 5);
    int free(Station s) => s.pick(plugs: mine).where((x) => x.use == Use.free).length;
    final top = near.take(5).toList();
    final best = top.firstWhere((s) => free(s) > 0, orElse: () => top.first);
    // 대표님 11-26: 「빈곳 2」가 늘 그대로 — 가장 가까운 한 곳만 세면 거의 안 바뀜 → 가까운 5곳 합으로
    final total = top.fold<int>(0, (a, s) => a + free(s));
    return (best, free(best), total, got > 0 || top.any((s) => s.liveAt != null));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(Station, int, int, bool)?>(
        future: _load(),
        builder: (_, snap) {
          final r = snap.data;
          if (r == null) return const SizedBox.shrink();
          final (s, one, total, live) = r;
          return MainRowCard(
            icon: 'charger',
            bold: '충전소',
            thin: '찾기',
            sub: one > 0 ? '가장 가까운 빈 곳 · ${s.name}' : '가까운 곳이 모두 충전 중이에요',
            subLines: 1,
            trailing: MainValue(total > 0 ? '빈곳 $total' : '꽉 참', live ? '가까운 5곳 · 지금' : '가까운 5곳'),
            onTap: () => openFeature(context, f),
          );
        },
      );
}
