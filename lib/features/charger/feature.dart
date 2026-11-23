// 충전소 (이 폴더는 충전소 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 전기차 충전기별 사용 가능·충전 중·고장 표시.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

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
  String get version => '0.0.1';
  @override
  Color get tint => kSoftGreen;

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('charger', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('전기차 충전기별 사용 가능·충전 중·고장 표시.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
