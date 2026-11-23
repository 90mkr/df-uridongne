// 길안내 (본부 방만 고침): 카카오맵 · 네이버 · 티맵 중 골라 목적지로 바로. 모든 기능이 이걸 쓴다.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';
import 'theme.dart';
import 'ui.dart';

Future<void> startNav(BuildContext context, {required String name, required double lat, required double lng}) async {
  final saved = await prefGet('core.navApp') ?? '';
  if (!context.mounted) return;
  if (saved.isNotEmpty) return _launch(saved, name, lat, lng);
  var keep = false;
  await showSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('어느 앱으로 길안내할까요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 3),
          Text('도착: $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kSub)),
          const SizedBox(height: 16),
          Row(children: [
            for (final (i, a) in _apps.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _AppTile(a, onTap: () {
                  if (keep) prefSet('core.navApp', a.id);
                  Navigator.pop(ctx);
                  _launch(a.id, name, lat, lng);
                }),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => set(() => keep = !keep),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(keep ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 19, color: keep ? kBlue : kMute),
                const SizedBox(width: 6),
                const Text('다음부터 이 앱으로 바로 열기', style: TextStyle(fontSize: 13, color: kSub)),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );
}

// 길안내 앱 (상표 대신 앱 색 + 직접 그린 작은 그림)
class _NavApp {
  final String id, name, glyph;
  final Color bg, fg;
  const _NavApp(this.id, this.name, this.glyph, this.bg, this.fg);
}

const _apps = [
  _NavApp('kakao', '카카오맵', 'pin', Color(0xFFFFE14A), Color(0xFF3A2A12)),
  _NavApp('naver', '네이버 지도', 'map', Color(0xFF1FC864), Colors.white),
  _NavApp('tmap', '티맵', 'car', Color(0xFF3A6BFF), Colors.white),
];

class _AppTile extends StatefulWidget {
  final _NavApp a;
  final VoidCallback onTap;
  const _AppTile(this.a, {required this.onTap});
  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: down ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine), boxShadow: kShadow),
          child: Column(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: a.bg,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: a.bg.withValues(alpha: 0.45), blurRadius: 10)],
              ),
              alignment: Alignment.center,
              child: CustomPaint(size: const Size(28, 28), painter: _Glyph(a.glyph, a.fg)),
            ),
            const SizedBox(height: 8),
            Text(a.name, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 1),
            const Text('길안내', style: TextStyle(fontSize: 11, color: kSub)),
          ]),
        ),
      ),
    );
  }
}

// 핀 · 접은 지도 · 자동차 (가는 선 대신 꽉 찬 귀여운 모양)
class _Glyph extends CustomPainter {
  final String kind;
  final Color c;
  _Glyph(this.kind, this.c);
  @override
  void paint(Canvas cv, Size s) {
    final p = Paint()..color = c;
    final w = s.width;
    if (kind == 'pin') {
      final path = Path()
        ..moveTo(w * .5, w * .96)
        ..cubicTo(w * .2, w * .62, w * .1, w * .48, w * .1, w * .38)
        ..arcToPoint(Offset(w * .9, w * .38), radius: Radius.circular(w * .4))
        ..cubicTo(w * .9, w * .48, w * .8, w * .62, w * .5, w * .96)
        ..close();
      cv.drawPath(path, p);
      cv.drawCircle(Offset(w * .5, w * .38), w * .14, Paint()..color = const Color(0xFFFFE14A));
    } else if (kind == 'map') {
      final path = Path()
        ..moveTo(w * .06, w * .2)
        ..lineTo(w * .36, w * .08)
        ..lineTo(w * .64, w * .2)
        ..lineTo(w * .94, w * .08)
        ..lineTo(w * .94, w * .8)
        ..lineTo(w * .64, w * .92)
        ..lineTo(w * .36, w * .8)
        ..lineTo(w * .06, w * .92)
        ..close();
      cv.drawPath(path, p);
      final l = Paint()
        ..color = const Color(0xFF1FC864)
        ..strokeWidth = w * .06;
      cv.drawLine(Offset(w * .36, w * .1), Offset(w * .36, w * .8), l);
      cv.drawLine(Offset(w * .64, w * .2), Offset(w * .64, w * .9), l);
    } else {
      final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * .06, w * .4, w * .88, w * .34), Radius.circular(w * .12));
      final top = Path()
        ..moveTo(w * .22, w * .42)
        ..lineTo(w * .32, w * .18)
        ..lineTo(w * .68, w * .18)
        ..lineTo(w * .78, w * .42)
        ..close();
      cv.drawPath(top, p);
      cv.drawRRect(body, p);
      final win = Paint()..color = const Color(0xFF3A6BFF);
      cv.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .34, w * .24, w * .32, w * .14), Radius.circular(w * .04)), win);
      cv.drawCircle(Offset(w * .28, w * .78), w * .1, p);
      cv.drawCircle(Offset(w * .72, w * .78), w * .1, p);
      cv.drawCircle(Offset(w * .22, w * .56), w * .055, Paint()..color = const Color(0xFFFFD84D));
      cv.drawCircle(Offset(w * .78, w * .56), w * .055, Paint()..color = const Color(0xFFFFD84D));
    }
  }

  @override
  bool shouldRepaint(covariant _Glyph o) => o.kind != kind || o.c != c;
}

Future<void> _launch(String app, String name, double lat, double lng) async {
  final n = Uri.encodeComponent(name);
  final web = app == 'naver' ? 'https://map.naver.com/p/search/$n' : 'https://map.kakao.com/link/to/$n,$lat,$lng';
  if (kIsWeb) return openUrl(web);
  final scheme = switch (app) {
    'kakao' => 'kakaomap://route?ep=$lat,$lng&by=CAR',
    'naver' => 'nmap://route/car?dlat=$lat&dlng=$lng&dname=$n&appname=kr.designfeel.dongne',
    _ => 'tmap://route?goalname=$n&goalx=$lng&goaly=$lat',
  };
  try {
    if (await launchUrl(Uri.parse(scheme), mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  await openUrl(web);
}
