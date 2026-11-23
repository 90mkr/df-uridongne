// 복권 (이 폴더는 복권 담당 방만 고침)
// 이번 주 로또 당첨번호 · 내 번호 확인(QR·번호) · 단지 근처 1등 나온 집 · 가까운 복권 판매점
// 자료: collector/features/lotto.py 가 web/data/lotto/ 에 모아 둔 것만 읽는다 (앱은 동행복권을 직접 부르지 않음).
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'page.dart';

class LottoFeature extends Feature {
  @override
  String get id => 'lotto';
  @override
  String get name => '복권';
  @override
  String get icon => 'lotto';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 50;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftYellow;

  @override
  Widget page(BuildContext context, Complex c) => LottoPage(complex: c);

  // 지도 탭: 단지 3km 안 1등 나온 집
  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final a = await loadArea(c.areaId);
    return [
      for (final s in a.wins)
        if (meters(c.pos, s.pos) <= kNear)
          MapPoint(
            id: s.id,
            name: '${s.name} · 1등 ${s.wins}회',
            sub: s.addr,
            pos: s.pos,
            onTap: (ctx) => showStore(ctx, s, c),
          ),
    ];
  }
}
