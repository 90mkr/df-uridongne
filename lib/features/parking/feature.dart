// 주차장 (이 폴더는 주차장 담당 방만 고침)
// 단지 둘레 주차장: 요금 말풍선 지도 · 가까운/싼 순 목록 · 지금 무료 · 내 차 어디 댔지 · 이웃 제보
// 자료: 공공데이터포털 전국주차장정보표준데이터 → collector/features/parking.py → web/data/parking/
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'package:latlong2/latlong.dart';

import 'car.dart';
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
  String get version => '0.2.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget page(BuildContext context, Complex c) => ParkingPage(complex: c);

  @override
  Future<List<MapPoint>> mapPoints(Complex c) => parkingPoints(c);

  // ── 본부가 붙여 줄 곳 (requests/parking-1123-홈카드-가게연결.md) ──
  // 단지 홈 맨 위: 주차 중일 때만 「주차 중 · 경과 시간 · 예상 요금」 카드 (아니면 빈칸)
  static Widget topCard() => const CarHomeCard();
  // 가게 화면 전화·길안내 아래 한 줄: 「근처 주차장 ○곳 · 가장 싼 곳 30분 ○원」 (없으면 null)
  static Future<String?> nearHint(LatLng p) => parkingHint(p);
  // 그 줄을 누르면: 그 가게 기준 주차장 지도
  static void openNear(BuildContext context, LatLng p, String name) => openParkingNear(context, p, name);
}
