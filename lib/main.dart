// 우리동네 — 시작점 (본부 방만 고침)
import 'package:flutter/material.dart';

import 'core/home_layout.dart';
import 'features/anniv/data.dart';
import 'core/nmap.dart';
import 'core/remote.dart';

import 'core/shell.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNaverMap(); // 휴대폰: 네이버 지도 준비 (웹은 아무것도 안 함)
  await loadRemote(); // 서버 설정(기능 숨기기·머리 그림) — 지난 설정 먼저, 새로 받기는 3초까지만
  await loadHomeLayout();
  loadAnnivs(); // 기념일 알림을 해마다 이어서 다시 맞춤 (기다리지 않음) // 「홈 화면 꾸미기」 설정 (이 휴대폰에 저장된 순서·끈 카드)
  runApp(const DongneApp());
}

class DongneApp extends StatelessWidget {
  const DongneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '$kAppName – 우리 동네, 필요한 것만 콕',
        debugShowCheckedModeBanner: false,
        theme: dongneTheme(),
        // 휴대폰 글자 크기를 아주 크게 해 둔 분도 화면이 깨지지 않게 조금만 따라감
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final s = mq.textScaler.scale(1).clamp(0.9, 1.15);
          return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(s)), child: child!);
        },
        home: const Shell(),
      );
}
