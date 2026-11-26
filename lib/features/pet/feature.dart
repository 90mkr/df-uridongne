// 우리 동네 반려동물 — 테마 방 (requests/pet-1125-반려동물-테마-방.md · 대표님 11-25)
// 생활 도구 한 칸 → 테마 첫 화면(PetHub): 응급·24시 / 동물병원 / 미용 / 호텔·돌봄 / 용품 / 동물약국 / 같이 갈 곳 / 우리 아이 수첩
// 지도 탭: 반려동물 칸별 거르기
// 「지금 우리 단지」: 수첩에 챙길 날이 다가오면, 또는 수첩이 있는 집에 밤·주말이면 한 장
// 나중에 반려동물 전용 앱으로 떼어 낼 수 있게 이 폴더 안에서만 완결 (공통은 core 만 씀)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'home_card.dart';
import 'hub.dart';
import 'kids.dart';
import 'places.dart';
import 'walk.dart';

class PetFeature extends Feature {
  @override
  String get id => 'pet';
  @override
  String get name => '반려동물';
  @override
  String get icon => 'pet';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 5;
  @override
  String get version => '0.8.0'; // 0.8.0 우리 구 멍냥 소통방 (talk.dart) · 0.7.0 추천 영상
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftOrange;

  @override
  Widget page(BuildContext context, Complex c) => PetHub(complex: c);

  // 단지 홈 배너 「오늘의 반려 생활」 — 처음엔 꺼 둠 (홈 편집·테마 첫 화면에서 켬, 대표님 11-26)
  @override
  Widget? mainCard(BuildContext context, Complex c) => PetHomeBanner(complex: c);

  @override
  List<MapFilter> mapFilters() => [for (final k in kPetKinds) MapFilter(k.$1.name, k.$2, kindIcon(k.$1))];

  @override
  Future<List<MapPoint>> mapPoints(Complex c) => mapPointsFor(c, PetKind.hosp.name);

  @override
  Future<List<MapPoint>> mapPointsFor(Complex c, String filter) async {
    final k = PetKind.values.where((x) => x.name == filter).firstOrNull ?? PetKind.hosp;
    final v = await petNear(c.pos, km: k == PetKind.hosp || k == PetKind.shop ? 3 : 6);
    return [for (final x in v.where((x) => x.$1.kind == k).take(200)) petPoint(x.$1, x.$2)];
  }

  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    await loadKids();
    if (kids.value.isEmpty) return null; // 반려동물 키우는 집에만
    final due = dueList(now).where((x) => dayDiff(x.$2.next, now) <= 3).firstOrNull;
    if (due != null) {
      final (k, care) = due;
      final n = dayDiff(care.next, now);
      return Brief(
        icon: 'pet',
        kicker: '우리 아이 수첩',
        bold: '${k.name} ',
        hot: careById(care.id).name,
        rest: n == 0 ? ' 오늘이에요' : (n > 0 ? ' $n일 남았어요' : ' ${-n}일 지났어요'),
        sub: '${care.next.month}월 ${care.next.day}일',
        score: n <= 0 ? 80 : (n == 1 ? 70 : 50),
      );
    }
    // 강아지 키우는 집: 아침·저녁 산책 무렵 오늘의 산책 (11-26)
    final hr = now.hour;
    if (kids.value.any((k) => k.kind == '강아지') && ((hr >= 7 && hr <= 9) || (hr >= 16 && hr <= 19))) {
      final d = await walkData(c);
      if (d == null) return null;
      final w = walkDay(d, await walkProfile());
      final j = w.nowJudge;
      if (j == null) return null;
      final b = w.best;
      return Brief(
        icon: 'pet',
        kicker: '오늘의 산책',
        bold: '지금 산책 ',
        hot: kWalkShort[j.level],
        sub: b == null ? (j.why.isEmpty ? '' : j.why.take(2).join(' · ')) : '추천 ${runText(b)}${j.why.isEmpty ? '' : ' · ${j.why.first}'}',
        score: j.level >= 2 ? 45 : 35,
      );
    }
    return null;
  }
}
