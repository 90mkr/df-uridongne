// 날씨 (이 폴더는 날씨 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 단지 기준 오늘 날씨와 미세먼지.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class WeatherFeature extends Feature {
  @override
  String get id => 'weather';
  @override
  String get name => '날씨';
  @override
  String get icon => 'weather';
  @override
  Slot get slot => Slot.header;
  @override
  int get order => 10;
  @override
  String get version => '0.0.1';
  @override
  Color get tint => kSoftYellow;

  @override
  Widget? homeCard(BuildContext context, Complex c) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: kLine)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          LineIcon('weather', size: 16, line: Color(0xFFE0A100), fill: kSoftYellow),
          SizedBox(width: 5),
          Text('날씨 준비 중', style: TextStyle(fontSize: 11)),
        ]),
      );

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: name,
        icon: icon,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('weather', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('단지 기준 오늘 날씨와 미세먼지.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
