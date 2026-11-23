// 전기차 충전소 (이 폴더는 충전소 담당 방만 고침)
// 단지 가까운 충전소 목록·지도, 충전기마다 비어 있음·충전 중·점검 표시, 길안내·운영기관 전화.
// 자료: 환경부 전기자동차 충전소 정보 (collector/features/charger.py 가 모으고, 앱은 가까운 곳 상태만 실시간으로 받음)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
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
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftGreen;

  @override
  Widget page(BuildContext context, Complex c) => ChargerPage(complex: c);

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final set = await stationsOf(c.areaId);
    final near = set.all.where((s) => meters(c.pos, s.pos) <= 3000).toList()
      ..sort((a, b) => meters(c.pos, a.pos).compareTo(meters(c.pos, b.pos)));
    return [
      for (final s in near.take(200))
        MapPoint(
          id: 'ev_${s.id}',
          name: '${s.name} · 빈 ${s.freeOf(null)}/${s.chargers.length}',
          sub: s.hasFast ? '급속' : '완속',
          pos: s.pos,
          onTap: (ctx) => showStation(ctx, s, c),
        ),
    ];
  }
}
