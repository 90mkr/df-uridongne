// 우리 동네 지원금·혜택 (이 폴더는 지원금·혜택 방만 고침, 대표님 11-25)
// 커뮤니티 안에는 카드로 연결만 하고(게시판 쪽에서 featureById('benefit') 로 연다), 화면·자료는 따로인 기능.
// 자료: collector/features/benefit.py 가 매일 web/data/benefit/ 에 우리 구·시도·전국·청년정책으로 나눠 둔 것.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'page.dart';

class BenefitFeature extends Feature {
  @override
  String get id => 'benefit';
  @override
  String get name => '지원금·혜택';
  @override
  String get icon => 'public'; // 전용 아이콘은 본부에 요청 (requests/benefit-1125-…)
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 45;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget page(BuildContext context, Complex c) => BenefitPage(c: c);
}
