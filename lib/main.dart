// 우리동네 — 시작점 (본부 방만 고침)
import 'package:flutter/material.dart';

import 'core/shell.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DongneApp());
}

class DongneApp extends StatelessWidget {
  const DongneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '$kAppName – 우리 단지 생활정보',
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
