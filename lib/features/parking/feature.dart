// 주차장 (이 폴더는 주차장 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 공영 주차장 요금·운영시간·구획 수.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class ParkingFeature extends Feature {
  @override
  String get id => 'parking';
  @override
  String get name => '주차장';
  @override
  String get icon => 'parking';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 30;
  @override
  String get version => '0.0.1';
  @override
  Color get tint => kSoft;

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('parking', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('공영 주차장 요금·운영시간·구획 수.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
