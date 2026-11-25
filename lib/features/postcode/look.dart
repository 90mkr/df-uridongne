// 택배·우편 안쪽 화면 공통 모양 (이 폴더는 택배·우편 담당 방만 고침)
// 첫 화면(0.4.0 대표님 시안)과 같은 바탕: 위→아래 옅은 파랑, 입체 아이콘 + 굵은 제목 머리, 둥근 흰 카드
import 'package:flutter/material.dart';

import '../../core/theme.dart';

const kPostBgTop = Color(0xFFF3F7FE), kPostBgBottom = Color(0xFFE2EDFC);
const kPostLine = Color(0xFFE1E9F5);

// 카드: 흰 바탕(또는 옅은 빛) · 둥근 20 · 1px 옅은 선 · 고르게 퍼지는 옅은 파랑 그림자
BoxDecoration postBox({List<Color>? grad, double r = 20}) => BoxDecoration(
      color: grad == null ? Colors.white : null,
      gradient: grad == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: kPostLine),
      boxShadow: const [BoxShadow(color: Color(0x120B52CF), blurRadius: 18)],
    );

// 칸마다 옅은 빛 (첫 화면 2×2 칸과 같은 색)
const kGlowYellow = [Color(0xFFFFFBF4), Color(0xFFFDF0E0)];
const kGlowBlue = [Color(0xFFF7FAFF), Color(0xFFE6EFFD)];
const kGlowViolet = [Color(0xFFFAF8FF), Color(0xFFEEEAFC)];
const kGlowMint = [Color(0xFFF6FDFB), Color(0xFFE3F5F0)];

Widget postArt(String name, double size) => Image.asset('assets/icons/$name.png', width: size, height: size, filterQuality: FilterQuality.medium);

class PostPage extends StatelessWidget {
  final String title, art;
  final String? sub;
  final Widget body;
  final List<Widget> actions;
  const PostPage({super.key, required this.title, required this.art, this.sub, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kPostBgTop,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kPostBgTop, kPostBgBottom])),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(kPad - 8, 6, kPad - 6, 0),
                    child: Row(children: [
                      IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 26, color: kInk)),
                      const SizedBox(width: 2),
                      postArt(art, 34),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk))),
                      ...actions,
                    ]),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(kPad + 2, 2, kPad, 0),
                      child: Text(sub!, style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
                    ),
                  const SizedBox(height: 12),
                  Expanded(child: body),
                ]),
              ),
            ),
          ),
        ),
      );
}
