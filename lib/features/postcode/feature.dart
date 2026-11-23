// 택배·우편 (이 폴더는 택배·우편 담당 방만 고침. 폴더 이름은 처음 이름 그대로 postcode)
// 첫 화면: 택배 조회 입력칸 + 조회한 택배 목록, 아래 우편번호 찾기 · 영문 주소 · 우체국 · 저장 주소 4칸
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'home.dart';
import 'office.dart';

class PostcodeFeature extends Feature {
  @override
  String get id => 'postcode';
  @override
  String get name => '택배·우편';
  @override
  String get icon => 'post';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 40;
  @override
  String get version => '0.3.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftYellow;

  @override
  Widget page(BuildContext context, Complex c) => PostHome(c);

  // 지도 탭에는 우체국만 (편의점은 너무 많아 상세 화면에서)
  @override
  Future<List<MapPoint>> mapPoints(Complex c) async => [
        for (final p in (await postPlaces(c)).where((p) => p.isPo))
          MapPoint(id: 'po_${p.id}', name: p.name, sub: p.label, pos: p.pos, onTap: (ctx) => showPlace(ctx, p, c)),
      ];
}
