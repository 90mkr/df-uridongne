// 기능이 앱에 붙는 방식 (본부 방만 고침)
//
// 기능 하나 = lib/features/<기능>/ 폴더 하나. 그 폴더의 feature.dart 에서 Feature 를 하나 만들어 내보낸다.
// 본부 방이 lib/features/registry.dart 에 그 Feature 를 한 줄 등록하면 앱 곳곳에 자동으로 나타난다.
//
//  ─ 단지 홈: slot 자리에 homeCard() 가 그린 카드 하나
//      hero    맨 위 큰 파랑 카드 (오늘의 단지 소식)
//      half    두 칸짜리 반쪽 카드 (버스 · 약국)
//      section 가로 꽉 찬 묶음 카드 (전화번호부)
//      wide    가로 꽉 찬 한 줄 카드 (실거래가)
//      tool    「생활 도구」 줄의 작은 칸 (주유소 · 충전소 · 주차장 · 우편번호)
//      header  머리 줄 오른쪽 작은 표시 (날씨)
//  ─ 카드를 누르면 page() 의 상세 화면
//  ─ 「생활 도구」 탭: 모든 기능이 아이콘 칸으로
//  ─ 「지도」 탭: mapPoints() 가 돌려준 점들이 「기능 고르기」 칩으로
//
// 카드 틀은 HomeCardBox(ui.dart), 상세 화면 틀은 DetailPage(ui.dart)를 쓴다. 기준 위치는 단지(c.pos).
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'theme.dart';

enum Slot { header, hero, half, section, wide, tool }

class MapPoint {
  final String id, name, sub;
  final LatLng pos;
  final void Function(BuildContext context)? onTap;
  const MapPoint({required this.id, required this.name, this.sub = '', required this.pos, this.onTap});
}

abstract class Feature {
  String get id; // 폴더 이름과 같게 (예: 'trash')
  String get name; // 화면에 보이는 이름 (예: '쓰레기·분리수거')
  String get icon; // core/icons.dart 의 아이콘 이름
  Slot get slot;
  int get order; // 같은 자리 안에서의 순서 (작을수록 위·왼쪽)
  String get version; // 기능 방이 올릴 때마다 올린다 (작업판과 같게)
  bool get ready => false; // 아직 준비 중이면 false → 카드에 「준비하고 있어요」

  Color get tint => kSoft; // 지도 점 · 아이콘 면 색

  // 단지 홈 카드 (null 이면 홈에 안 보임)
  Widget? homeCard(BuildContext context, Complex c) => null;

  // 상세 화면
  Widget page(BuildContext context, Complex c);

  // 지도 탭에 올릴 점 (없으면 빈 목록)
  Future<List<MapPoint>> mapPoints(Complex c) async => const [];
}

void openFeature(BuildContext context, Feature f) {
  final c = complex.value;
  if (c == null) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => f.page(ctx, c)));
}
