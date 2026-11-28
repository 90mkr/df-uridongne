// 우리동네 디자인 규칙 (본부 방만 고침)
// ─ 색: 글자·선은 거의 검정(kInk), 강조는 파랑(kBlue) 한 가지. 줄마다 반복되는 표시는 회색, 파랑은 꼭 짚을 것 하나에만.
// ─ 글꼴: Pretendard. 제목은 굵은 말 + 가는 말을 섞는다 (예: 「동네」 굵게 + 「전화번호부」 가늘게).
// ─ 카드: 흰 바탕 + 둥근 모서리 14 + 1px 옅은 회색 선 + 아주 옅은 그림자(아래로 처지지 않게 고르게).
// ─ 화면 바탕은 아주 옅은 회색(kBg), 카드는 흰색. 테두리는 1px 넘게 쓰지 않는다.
// ─ 아이콘: 가는 선 + 옅은 면 (icons.dart의 LineIcon). 동그라미 안에 넣지 않는다.
import 'package:flutter/material.dart';

const kBlue = Color(0xFF2563EB); // 강조 (시안 색)
const kInk = Color(0xFF17181C); // 글자·선
const kSub = Color(0xFF6B6F7A);
const kMute = Color(0xFF9A9EA8);
const kLine = Color(0xFFE1E6EE);
const kSoft = Color(0xFFE8EEFF); // 아이콘 옅은 면 (파랑 계열)
const kSoftGreen = Color(0xFFE7F6EE);
const kSoftOrange = Color(0xFFFFEFE3);
const kSoftYellow = Color(0xFFFFF4D6);
const kBg = Color(0xFFF1F5FB); // 아주 옅은 하늘빛 (시안 11-23)
const kAppName = '우동콕'; // 앱 이름 (대표님 11-26 요기콕 → 니즈콕, 11-28 → 우동콕 「우리 동네, 콕 눌러 선택」. 앱 고유 번호는 그대로)

const kRadius = 16.0;
const kPad = 20.0; // 휴대폰 화면 양옆 여백

final kShadow = [BoxShadow(color: const Color(0xFF1C3A6E).withValues(alpha: 0.06), blurRadius: 16, offset: Offset.zero)];

// 기본 카드 모양: 모든 기능 카드는 이걸 쓴다
BoxDecoration cardBox({double r = kRadius, Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: kLine, width: 1),
      boxShadow: kShadow,
    );

// 글자 크기 (작고 촘촘하게, 크기 차이로 위계)
class T {
  static const h1 = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.25);
  static const h2 = TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.25);
  static const thin = TextStyle(fontWeight: FontWeight.w300);
  static const title = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.3);
  static const body = TextStyle(fontSize: 13, height: 1.4);
  static const small = TextStyle(fontSize: 11.5, color: kSub, height: 1.35);
  static const tiny = TextStyle(fontSize: 10.5, color: kSub, height: 1.3);
}

ThemeData dongneTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(seedColor: kBlue, primary: kBlue, surface: Colors.white),
    scaffoldBackgroundColor: kBg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: kBlue.withValues(alpha: 0.04),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: kInk, displayColor: kInk),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 17, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -0.3),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: kInk),
  );
}
