import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_core/firebase_core.dart' as fc;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'icons.dart';
part 'data.dart';
part 'home.dart';
part 'list.dart';
part 'shop.dart';

// ---------------- 색·글자 ----------------
const kBlue = Color(0xFF1F5EFF); // 강조는 파랑 한 가지
const kInk = Color(0xFF1A1D23); // 글자·선
const kSub = Color(0xFF6B717C);
const kMute = Color(0xFF9AA0AA);
const kLine = Color(0xFFE3E6EB);
const kSoft = Color(0xFFDCE6FF); // 아이콘 옅은 면
const kBg = Color(0xFFF6F7F9);

const kAppName = '우리동네';

final shadow = [BoxShadow(color: const Color(0xFF141E32).withValues(alpha: 0.05), blurRadius: 12, offset: Offset.zero)];

BoxDecoration cardBox({double r = 12}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: kLine, width: 1),
      boxShadow: shadow,
    );

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DongneApp());
}

class DongneApp extends StatelessWidget {
  const DongneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(seedColor: kBlue, primary: kBlue, surface: Colors.white),
      scaffoldBackgroundColor: Colors.white,
      splashFactory: NoSplash.splashFactory,
      highlightColor: kBlue.withValues(alpha: 0.04),
    );
    return MaterialApp(
      title: '$kAppName – 동네 생활정보',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
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
      ),
      // 휴대폰 글자 크기를 아주 크게 해 둔 분도 화면이 깨지지 않게 조금만 따라감
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final s = mq.textScaler.scale(1).clamp(0.9, 1.15);
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(s)), child: child!);
      },
      home: const HomePage(),
    );
  }
}

// ---------------- 공용 ----------------

Future<void> openUrl(String url, {bool inApp = false}) async {
  final u = Uri.parse(url);
  try {
    await launchUrl(u, mode: inApp && !kIsWeb ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> callTel(String tel) async {
  final t = tel.replaceAll(RegExp(r'[^0-9+]'), '');
  if (t.isEmpty) return;
  try {
    await launchUrl(Uri.parse('tel:$t'));
  } catch (_) {}
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13.5)), duration: const Duration(milliseconds: 1600)));
}

double meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

String distText(double m) => m < 1000 ? '${(m / 10).round() * 10}m' : '${(m / 1000).toStringAsFixed(1)}km';

// 작은 알약 모양 표시 (글자가 둥근 끝에 닿지 않게 옆 여백 넉넉히)
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const Pill(this.text, {super.key, this.color = kSub, this.bg = const Color(0xFFF1F3F6)});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color, height: 1.2)),
      );
}

// 위아래 꽉 찬 단추 (파랑 / 흰 바탕)
class Btn extends StatelessWidget {
  final String text;
  final String? icon;
  final VoidCallback? onTap;
  final bool primary;
  final double h;
  const Btn(this.text, {super.key, this.icon, this.onTap, this.primary = false, this.h = 46});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : kInk;
    return Material(
      color: primary ? kBlue : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: h,
          decoration: primary ? null : BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD5D9E0))),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              LineIcon(icon!, size: 19, line: fg, fill: primary ? Colors.white.withValues(alpha: 0.25) : kSoft),
              const SizedBox(width: 6),
            ],
            Text(text, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      ),
    );
  }
}
