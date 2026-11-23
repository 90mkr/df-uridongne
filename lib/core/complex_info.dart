// 「단지 정보」 화면 (본부 방만 고침): 홈 맨 위 단지 이름을 누르면 열린다.
// 단지 이름·주소·위치 + slot 이 Slot.info 인 기능 카드(예: 우리 단지 최근 거래) + 다른 단지로 바꾸기
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'dnmap.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';

void openComplexInfo(BuildContext context) {
  final c = complex.value;
  if (c == null) {
    pickComplex(context);
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => ComplexInfoPage(c: c)));
}

class ComplexInfoPage extends StatelessWidget {
  final Complex c;
  const ComplexInfoPage({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final infos = features.where((f) => f.slot == Slot.info).toList()..sort((a, b) => a.order.compareTo(b.order));
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('단지 정보', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 28), children: [
            // 단지 이름 · 주소 · 위치
            Container(
              decoration: cardBox(),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(height: 150, child: IgnorePointer(child: DnMap(center: c.pos, zoom: 16))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
                  child: Row(children: [
                    const LineIcon('apt', size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text.rich(
                          TextSpan(children: [
                            if (c.town.isNotEmpty) TextSpan(text: '${c.town} ', style: const TextStyle(fontWeight: FontWeight.w400)),
                            TextSpan(text: c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, letterSpacing: -0.5, height: 1.25),
                        ),
                        if (c.addr.isNotEmpty) ...[const SizedBox(height: 2), Text(c.addr, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)],
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Btn('단지 바꾸기', h: 38, onTap: () async {
                        await pickComplex(context);
                        if (context.mounted && complex.value?.id != c.id) Navigator.pop(context);
                      }),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            for (final f in infos) ...[f.homeCard(context, c) ?? const SizedBox(), const SizedBox(height: 12)],
          ]),
        ),
      ),
    );
  }
}
