// 지금 문 연 약국 (이 폴더는 지금 문 연 약국 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 요일별 운영시간 기준으로 지금 문 연 약국·병원, 야간 소아과, 응급실.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class PharmacyFeature extends Feature {
  @override
  String get id => 'pharmacy';
  @override
  String get name => '지금 문 연 약국';
  @override
  String get icon => 'pharm';
  @override
  Slot get slot => Slot.half;
  @override
  int get order => 20;
  @override
  String get version => '0.0.1';
  @override
  Color get tint => kSoftGreen;

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
              LineIcon('pharm', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('요일별 운영시간 기준으로 지금 문 연 약국·병원, 야간 소아과, 응급실.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
