// 복권 (이 폴더는 복권 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 이번 주 로또 당첨번호, 단지 근처 1등 나온 판매점 지도, 가까운 복권 판매점.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

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
  String get version => '0.0.1';
  @override
  Color get tint => kSoftYellow;

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('lotto', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('이번 주 로또 당첨번호, 단지 근처 1등 나온 판매점과 가까운 복권 판매점.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
