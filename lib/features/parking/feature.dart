// 주차장 (이 폴더는 주차장 담당 방만 고침)
// 단지 둘레 주차장: 요금 말풍선 지도 · 가까운/싼 순 목록 · 지금 무료 · 내 차 어디 댔지 · 이웃 제보
// 자료: 공공데이터포털 전국주차장정보표준데이터 → collector/features/parking.py → web/data/parking/
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
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
  String get version => '0.3.0';
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
  // 단지 홈 본문: 「가까운 공영주차장」 3곳 (대표님 11-25: 「내 차」와는 다른 개념이라 카드를 따로 — 내 차는 MyCarFeature)
  @override
  Widget? mainCard(BuildContext context, Complex c) => NearLotsCard(c: c);
  @override
  int get mainOrder => 2;
  // 가게 화면 전화·길안내 아래 한 줄: 「근처 주차장 ○곳 · 가장 싼 곳 30분 ○원」 (없으면 null)
  static Future<String?> nearHint(LatLng p) => parkingHint(p);
  // 그 줄을 누르면: 그 가게 기준 주차장 지도
  static void openNear(BuildContext context, LatLng p, String name) => openParkingNear(context, p, name);
}

// 「내 차 어디 댔지」 — 공영주차장과 다른 기능으로 따로 (공터·길가 어디든 세운 곳·사진·찾아가기) · 홈 카드도 따로
// 공영주차장과 이어지는 곳: 「여기 세웠어요」 때 가까운 주차장이 있으면 자동으로 골라 예상 요금
class MyCarFeature extends Feature {
  @override
  String get id => 'mycar';
  @override
  String get name => '내 차';
  @override
  String get icon => 'car';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 31;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  Widget page(BuildContext context, Complex c) => MyCarPage(c: c);
  @override
  Widget? mainCard(BuildContext context, Complex c) => CarMainCard(c: c);
  @override
  int get mainOrder => 0;
}

class MyCarPage extends StatelessWidget {
  final Complex c;
  const MyCarPage({super.key, required this.c});
  @override
  Widget build(BuildContext context) => DetailPage(
        title: '내 차 어디 댔지',
        icon: 'car',
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 32), children: [
          CarMainCard(c: c),
          const SizedBox(height: 14),
          const Text('공터·길가·주차장 어디든 세운 곳을 남겨 두면, 나중에 걸어서 찾아가는 길과 (주차장이면) 예상 요금을 알려 드려요. 층·구역 사진도 남길 수 있어요.', style: T.small),
        ]),
      );
}
