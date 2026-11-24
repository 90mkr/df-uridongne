// 우리 단지 게시판 (게시판 담당: 본부, 대표님 요청 11-24) — 소식·나눔·자유·업체 추천, 같은 단지 주민끼리
// 홈: 「우리 단지 이야기」 카드 — 최근 글 3줄(사진 없이 한 줄씩) + 글쓰기
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'page.dart';

class BoardFeature extends Feature {
  @override
  String get id => 'board';
  @override
  String get name => '우리 단지 이야기';
  @override
  String get icon => 'board';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 2;
  @override
  int get mainOrder => 1; // 내 차 다음
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;

  @override
  Widget? mainCard(BuildContext context, Complex c) => _HomeCard(c: c);

  @override
  Widget page(BuildContext context, Complex c) => BoardPage(c: c);
}

class _HomeCard extends StatefulWidget {
  final Complex c;
  const _HomeCard({required this.c});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  List<Post>? l;
  @override
  void initState() {
    super.initState();
    boardTick.addListener(_load);
    authTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    boardTick.removeListener(_load);
    authTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final v = await postsOf(widget.c);
    if (mounted) setState(() => l = v);
  }

  void _open([String cat = '']) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoardPage(c: widget.c, cat: cat)));

  @override
  Widget build(BuildContext context) {
    final v = l ?? const <Post>[];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: _open,
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const LineIcon('board', size: 32),
              const SizedBox(width: 10),
              const Expanded(child: MixTitle('우리 단지', '이야기', size: 15)),
              Text(v.isEmpty ? '소식·나눔·자유' : '글 ${v.length}', style: const TextStyle(fontSize: 12, color: kSub)),
              const Icon(Icons.chevron_right_rounded, color: kSub, size: 20),
            ]),
            const SizedBox(height: 8),
            if (l == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('불러오는 중…', style: T.small))
            else if (v.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(me == null ? '로그인하면 ${widget.c.name} 이웃 글을 볼 수 있어요' : '${widget.c.name} 이웃과 나눔·소식을 나눠 보세요. 첫 글을 남겨 주세요!', style: T.small),
              )
            else
              for (final p in v.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 46, child: Text(catName(p.cat), style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w600))),
                    Expanded(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: -0.3))),
                    if (p.comments > 0) Text(' [${p.comments}]', style: const TextStyle(fontSize: 11.5, color: kBlue, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text(agoText(p.at), style: const TextStyle(fontSize: 10.5, color: kMute)),
                  ]),
                ),
          ]),
        ),
      ),
    );
  }
}
