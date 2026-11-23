// 쓰레기·분리수거 (이 폴더는 쓰레기·분리수거 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 지자체 배출 요일·방법과 대형폐기물 수수료, 단지별 배출 요일(주민·관리사무소 입력)을 보여 드려요.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class TrashFeature extends Feature {
  @override
  String get id => 'trash';
  @override
  String get name => '쓰레기·분리수거';
  @override
  String get icon => 'trash';
  @override
  Slot get slot => Slot.hero;
  @override
  int get order => 10;
  @override
  String get version => '0.0.1';
  @override
  Color get tint => kSoft;

  @override
  Widget? homeCard(BuildContext context, Complex c) => InkWell(borderRadius: BorderRadius.circular(16), onTap: () => openFeature(context, this), child: Container(
        decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: const Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('오늘의 단지 소식', style: TextStyle(fontSize: 11, color: Color(0xD9FFFFFF))),
              SizedBox(height: 3),
              MixTitle('쓰레기', '배출일을 준비하고 있어요', size: 17, color: Colors.white),
              SizedBox(height: 3),
              Text('단지별 배출 요일·시간을 곧 알려 드려요', style: TextStyle(fontSize: 11.5, color: Color(0xD9FFFFFF))),
            ]),
          ),
          LineIcon('trash', size: 50, line: Colors.white, fill: Color(0x38FFFFFF)),
        ]),
      ));

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('trash', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('지자체 배출 요일·방법과 대형폐기물 수수료, 단지별 배출 요일(주민·관리사무소 입력)을 보여 드려요.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
