// 주유소 (이 폴더는 주유소 담당 방만 고침)
// 단지 반경 안 주유소를 휘발유·경유·LPG·고급휘발유 가격 싼 순으로 — 목록 ↔ 지도(말풍선에 가격), 길안내.
// 자료: 오피넷 → collector/features/gas.py → web/data/gas/<동네id>.json (앱은 열쇠값 없이 이 파일만 읽음)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
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
  String get version => '0.1.2';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftOrange;

  @override
  Widget page(BuildContext context, Complex c) => GasPage(c);

  // 단지 홈 본문: 「제일 싼 주유소」 (단지 5km 안, 고른 기름 기준 — 대표님 11-24) — 자료 없으면 빈칸
  @override
  Widget? mainCard(BuildContext context, Complex c) => _CheapCard(f: this, c: c);
  @override
  int get mainOrder => 2;

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
          name: s.name,
          sub: '${fuelName(f)} ${won(s.price(f)!)}원',
          badge: '${won(s.price(f)!)}원', // 지도에 가격이 바로 보이게 (대표님 11-24)
          pos: s.pos,
          onTap: (ctx) => showStation(ctx, s, f, d),
        ),
    ];
  }
}

class _CheapCard extends StatelessWidget {
  final Feature f;
  final Complex c;
  const _CheapCard({required this.f, required this.c});

  Future<(GasStation, String)?> _load() async {
    final d = await loadGas(c.areaId);
    if (d == null) return null;
    final p = await prefGet('gas.fuel') ?? 'B027';
    final fuel = kFuels.any((x) => x.$1 == p) ? p : 'B027';
    final l = d.around(c.pos, fuel, 5000);
    return l.isEmpty ? null : (l.first, fuel);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(GasStation, String)?>(
        future: _load(),
        builder: (_, snap) {
          final r = snap.data;
          if (r == null) return const SizedBox.shrink();
          final (s, fuel) = r;
          return MainRowCard(
              icon: 'gas',
              bold: '제일 싼',
              thin: '주유소',
              sub: '5km 안 최저 · ${s.name}',
              subLines: 1,
              trailing: MainValue('${won(s.price(fuel)!)}원', '${fuelName(fuel)} · ${distText(s.dist)}'),
              onTap: () => openFeature(context, f),
          );
        },
      );
}
