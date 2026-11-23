// 단지 앞 버스 (이 폴더는 단지 앞 버스 담당 방만 고침)
// 지금은 본부가 만든 빈 틀입니다. 담당 방이 이 폴더 안에서 채웁니다.
// 할 일: 단지에서 가장 가까운 정류장의 실시간 도착 정보와 자주 타는 정류장 고정.
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class BusFeature extends Feature {
  @override
  String get id => 'bus';
  @override
  String get name => '단지 앞 버스';
  @override
  String get icon => 'bus';
  @override
  Slot get slot => Slot.half;
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
              LineIcon('bus', size: 54),
              SizedBox(height: 14),
              Text('준비하고 있어요', style: T.h2),
              SizedBox(height: 6),
              Text('단지에서 가장 가까운 정류장의 실시간 도착 정보와 자주 타는 정류장 고정.', textAlign: TextAlign.center, style: T.small),
            ]),
          ),
        ),
      );
}
