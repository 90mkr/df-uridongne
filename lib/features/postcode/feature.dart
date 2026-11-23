// 우편번호 찾기 (이 폴더는 우편번호 담당 방만 고침)
// 카카오(다음) 우편번호 서비스를 web/postcode.html 로 띄운다 — 열쇠값 필요 없음
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class PostcodeFeature extends Feature {
  @override
  String get id => 'postcode';
  @override
  String get name => '우편번호';
  @override
  String get icon => 'post';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 40;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftYellow;

  static String get url => kIsWeb && Uri.base.host.endsWith('github.io') ? 'postcode.html' : '${kSiteUrl}postcode.html';

  @override
  Widget page(BuildContext context, Complex c) => DetailPage(
        title: '우편번호 찾기',
        icon: icon,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 30, kPad, 30),
          child: Column(children: [
            const LineIcon('post', size: 54, fill: kSoftYellow),
            const SizedBox(height: 14),
            const MixTitle('주소로', '우편번호 찾기', size: 18),
            const SizedBox(height: 6),
            const Text('도로명·건물명·지번으로 찾고, 우편번호를 바로 복사할 수 있어요', textAlign: TextAlign.center, style: T.small),
            const SizedBox(height: 20),
            Btn('우편번호 찾기 열기', primary: true, onTap: () => openUrl(url, inApp: true)),
          ]),
        ),
      );
}
