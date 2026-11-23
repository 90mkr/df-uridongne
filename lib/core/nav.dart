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
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('어느 앱으로 안내할까요', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final a in const [('kakao', '카카오맵'), ('naver', '네이버'), ('tmap', '티맵')])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Btn('${a.$2}으로 길안내', onTap: () {
                if (keep) prefSet('core.navApp', a.$1);
                Navigator.pop(ctx);
                _launch(a.$1, name, lat, lng);
              }),
            ),
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
