// 홈 맨 아래 배너 (본부, 대표님 11-24): 디자인필 홈페이지 제작 → 콕플 앱 … 천천히 넘어감
// 목록·그림은 web/data/banners.json 에서 받음 → 그림만 바꾸면 앱을 새로 깔지 않아도 바뀜
import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

class HomeBanners extends StatefulWidget {
  const HomeBanners({super.key});
  @override
  State<HomeBanners> createState() => _HomeBannersState();
}

class _HomeBannersState extends State<HomeBanners> {
  List<(String, String, String)> items = const []; // 그림 주소, 누르면 갈 곳, 설명
  final pc = PageController();
  int page = 0;
  Timer? t;

  @override
  void initState() {
    super.initState();
    getJson('${dataBase}banners.json').then((j) {
      if (!mounted || j is! Map) return;
      final l = <(String, String, String)>[
        for (final b in (j['b'] as List? ?? const []))
          if (b is Map && '${b['img'] ?? ''}'.isNotEmpty) ('${b['img']}'.startsWith('http') ? '${b['img']}' : '$dataBase${b['img']}', '${b['url'] ?? ''}', '${b['alt'] ?? ''}'),
      ];
      setState(() => items = l);
      if (l.length > 1) {
        t = Timer.periodic(const Duration(seconds: 6), (_) {
          if (!mounted || !pc.hasClients) return;
          pc.animateToPage((page + 1) % items.length, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
        });
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      AspectRatio(
        aspectRatio: 3, // 대표님 배너 그림 2172×724
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: PageView.builder(
            controller: pc,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (_, i) => Semantics(
              label: items[i].$3,
              button: true,
              child: GestureDetector(
                onTap: items[i].$2.isEmpty ? null : () => openUrl(items[i].$2),
                child: Image.network(items[i].$1, fit: BoxFit.contain, webHtmlElementStrategy: WebHtmlElementStrategy.prefer, errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
          ),
        ),
      ),
      if (items.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(color: i == page ? const Color(0xFF8A94A6) : const Color(0xFFD3D9E3), borderRadius: BorderRadius.circular(3)),
              ),
          ]),
        ),
    ]);
  }
}
