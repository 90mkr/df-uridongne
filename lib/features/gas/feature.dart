// 주유소 (이 폴더는 주유소 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 기름별 가격 싼 순 목록과 지도.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

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
  String get version => '0.0.1';
  @override
  Color get tint => kSoftOrange;

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('gas', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('기름별 가격 싼 순 목록과 지도.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
