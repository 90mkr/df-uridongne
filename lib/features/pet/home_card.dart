// 단지 홈 배너 「오늘의 반려 생활」 (대표님 11-26: 카드식으로, 켜면 첫 화면에 배너)
// 처음엔 꺼져 있음 → 테마 첫 화면의 「홈 첫 화면에 띄우기」나 홈 편집 ⊕, 또는 우리 아이를 등록하면 켜짐
import 'package:flutter/material.dart';

import '../../core/data.dart';
import 'guide.dart';
import 'hub.dart';
import 'kids.dart';
import 'kids_page.dart';
import 'walk.dart';

class PetHomeBanner extends StatefulWidget {
  final Complex complex;
  const PetHomeBanner({super.key, required this.complex});
  @override
  State<PetHomeBanner> createState() => _PetHomeBannerState();
}

class _PetHomeBannerState extends State<PetHomeBanner> {
  WalkDay? walk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await loadKids();
    final w = await Future.wait([walkProfile(), walkData(widget.complex)]);
    final wd = w[1] as WalkData?;
    if (!mounted) return;
    setState(() => walk = wd == null ? null : walkDay(wd, w[0] as WalkProfile));
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) {
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.complex;
    return PetTodayCard(
      head: '우리 동네 반려동물',
      walk: walk,
      onWalk: () => _go(PetHub(complex: c)),
      onKids: () => _go(const PetKidsPage()),
      onGuide: () => _go(PetGuidePage(complex: c)),
    );
  }
}
