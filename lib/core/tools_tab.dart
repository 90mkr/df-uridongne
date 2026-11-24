// 생활 도구 탭 (본부 방만 고침): 등록된 모든 기능을 칸으로
import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'feature.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';

class ToolsTab extends StatelessWidget {
  const ToolsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final list = [...features]..sort((a, b) => a.slot.index != b.slot.index ? a.slot.index.compareTo(b.slot.index) : a.order.compareTo(b.order));
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 28), children: [
              const MixTitle('생활', '도구', size: 19),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 520 ? 4 : 3;
                const gap = 10.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final f in list)
                    SizedBox(
                      width: w,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kRadius),
                          onTap: () => openFeature(context, f),
                          child: Ink(
                            decoration: cardBox(),
                            padding: const EdgeInsets.fromLTRB(8, 16, 8, 13),
                            child: Column(children: [
                              LineIcon(f.icon, size: 40), // 색 아이콘 (대표님 11-24: 모두 같은 그림체)
                              const SizedBox(height: 7),
                              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(f.ready ? ' ' : '준비 중', style: T.tiny),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
            ]),
          ),
        ),
      ),
    );
  }
}
