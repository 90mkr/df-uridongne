// 주차장 (이 폴더는 주차장 담당 방만 고침)
// 단지 둘레 공영·민영 주차장: 가까운 순 목록 + 지도 + 요금·운영시간·주차 구획 수 · 길안내
// 자료: 공공데이터포털 전국주차장정보표준데이터 → collector/features/parking.py → web/data/parking/
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'page.dart';

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
  String get version => '0.1.2';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget page(BuildContext context, Complex c) => ParkingPage(complex: c);

  @override
  Future<List<MapPoint>> mapPoints(Complex c) => parkingPoints(c);
}
