// 우리 단지 실거래가 · 전월세 · 단지 정보 (이 폴더는 실거래가 방만 고침)
// 「단지 정보」 화면(홈 맨 위 단지 이름을 누르면)에 카드 두 장: 우리 단지 정보 · 우리 단지 최근 거래
// 자료: 국토교통부 실거래가(매매·전월세) → collector/features/deals.py → web/data/deals/<시군구>.json
//       단지 정보는 K-apt 공동주택 기본·상세정보를 그 자리에서 (dgGet, 12시간 묶음)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'info.dart';
import 'page.dart';

class DealsFeature extends Feature {
  @override
  String get id => 'deals';
  @override
  String get name => '우리 단지 최근 거래';
  @override
  String get icon => 'deals';
  @override
  Slot get slot => Slot.info; // 홈이 아니라 「단지 정보」 화면에 (대표님 요청 11-24)
  @override
  int get order => 10;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget? homeCard(BuildContext context, Complex c) => DealsInfoCards(key: ValueKey('deals-${c.id}'), c: c, f: this);

  @override
  Widget page(BuildContext context, Complex c) => DealsPage(c: c);
}
