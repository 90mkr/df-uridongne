// 주유소 (이 폴더는 주유소 담당 방만 고침)
// 단지 반경 안 주유소를 휘발유·경유·LPG·고급휘발유 가격 싼 순으로 — 목록 ↔ 지도(말풍선에 가격), 길안내.
// 자료: 오피넷 → collector/features/gas.py → web/data/gas/<동네id>.json (앱은 열쇠값 없이 이 파일만 읽음)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'page.dart';

class GasFeature extends Feature {
  @override
  String get id => 'gas';
  @override
  String get name => '주유소';
  @override
  String get icon => 'gas';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 10;
  @override
  String get version => '0.1.1';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftOrange;

  @override
  Widget page(BuildContext context, Complex c) => GasPage(c);

  // 지도 탭: 단지 3km 안 주유소 (휘발유 싼 순, 이름 옆에 가격)
  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final d = await loadGas(c.areaId);
    if (d == null) return const [];
    final fuel = await prefGet('gas.fuel') ?? 'B027';
    final f = kFuels.any((x) => x.$1 == fuel) ? fuel : 'B027';
    final list = d.around(c.pos, f, 3000);
    return [
      for (final s in list)
        MapPoint(
          id: 'gas_${s.id}',
          name: '${s.name} ${won(s.price(f)!)}원',
          sub: fuelName(f),
          pos: s.pos,
          onTap: (ctx) => showStation(ctx, s, f, d),
        ),
    ];
  }
}
