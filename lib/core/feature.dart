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
  final String badge; // 지도에 핀 대신 보일 짧은 글자 (예: 「240면」·「1,689원」·「빈 3」) — 비우면 핀
  final LatLng pos;
  final void Function(BuildContext context)? onTap;
  final String icon; // 점마다 다른 아이콘 (비우면 기능 아이콘) — 예: 전화번호부 업종
  const MapPoint({required this.id, required this.name, this.sub = '', this.badge = '', required this.pos, this.onTap, this.icon = ''});
}

// 지도 탭 거르기 단추 하나 (예: 전화번호부의 「세탁소」)
class MapFilter {
  final String id, name, icon;
  const MapFilter(this.id, this.name, this.icon);
}

// 다른 화면에서 「지도로 보기」: 지도 탭으로 넘어가며 기능·거르기·고를 점을 정해 연다
class MapAsk {
  final String feature, filter, focus;
  const MapAsk(this.feature, {this.filter = '', this.focus = ''});
}

final mapAsk = ValueNotifier<MapAsk?>(null);

// 쌓인 화면을 닫고 하단 지도 탭으로
void openMapTab(BuildContext context, MapAsk ask) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  mapAsk.value = ask;
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

  // 지도 탭에서 이 기능을 골랐을 때 둘째 줄에 나올 거르기 단추 (없으면 빈 목록)
  List<MapFilter> mapFilters() => const [];

  // 거르기를 고른 점들 (기본: 거르기 없이 전부)
  Future<List<MapPoint>> mapPointsFor(Complex c, String filter) => mapPoints(c);

  // 단지 홈 맨 위 「지금 우리 단지」 카드에 낼 한 장 (없으면 null). 점수가 높을수록 앞에 나온다.
  // 시간대·날씨·배출일에 맞춰 기능이 스스로 점수를 매긴다 (예: 출근 시간 버스 80, 비 오기 전 날씨 90).
  Future<Brief?> brief(Complex c, DateTime now) async => null;
}

class Brief {
  final String icon; // 색 아이콘 이름
  final String kicker; // 맨 위 작은 글 (예: 「출근길 · 단지 앞 버스」)
  final String bold, hot, rest; // 큰 글: 굵게 + 노랑 강조 + 나머지
  final String sub; // 아래 작은 글
  final int score;
  const Brief({required this.icon, required this.kicker, this.bold = '', this.hot = '', this.rest = '', this.sub = '', this.score = 50});
}

void openFeature(BuildContext context, Feature f) {
  final c = complex.value;
  if (c == null) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => f.page(ctx, c)));
}
