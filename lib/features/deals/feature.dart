// 우리 단지 최근 거래 (이 폴더는 우리 단지 최근 거래 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 평형별 최근 매매·전세, 1년 가격 흐름, 옆 단지 비교.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class DealsFeature extends Feature {
  @override
  String get id => 'deals';
  @override
  String get name => '우리 단지 최근 거래';
  @override
  String get icon => 'deals';
  @override
  Slot get slot => Slot.wide;
  @override
  int get order => 10;
  @override
  String get version => '0.0.1';
  @override
  Color get tint => kSoft;

  @override
  Widget? homeCard(BuildContext context, Complex c) => HomeCardBox(icon: icon, title: name, onTap: () => openFeature(context, this), child: const ComingSoon());

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('deals', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('평형별 최근 매매·전세, 1년 가격 흐름, 옆 단지 비교.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
