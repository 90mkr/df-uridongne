// 게시판 알림 고르기 (대표님 11-25) — 내 정보 · 게시판 위 종에서 열림
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

class BoardNotiPage extends StatefulWidget {
  final Complex c;
  const BoardNotiPage({super.key, required this.c});
  @override
  State<BoardNotiPage> createState() => _BoardNotiPageState();
}

class _BoardNotiPageState extends State<BoardNotiPage> {
  final Map<String, bool> on = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get _keys => [
        for (final s in ['complex', 'town'])
          for (final b in kBoards) '$s.${b.$1}',
        'job',
        'mycomment',
      ];

  Future<void> _load() async {
    for (final k in _keys) {
      on[k] = await pushOn(k);
    }
    if (mounted) setState(() {});
  }

  String _topic(String key) {
    final c = widget.c;
    if (key == 'job') return jobTopic(c.areaId);
    if (key == 'mycomment') return userTopic(me?.uid ?? '');
    final p = key.split('.');
    return boardTopic(p[0] == 'town' ? 'a_${c.areaId}' : c.id, p[1]);
  }

  Future<void> _set(String key, bool v) async {
    setState(() => on[key] = v);
    if (key == 'mycomment' && me == null) return;
    await setPush(key, _topic(key), v);
  }

  Widget _sw(String key, String title, [String sub = '']) => SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: sub.isEmpty ? null : Text(sub, style: T.tiny),
        value: on[key] ?? defaultOn(key),
        activeTrackColor: kBlue,
        onChanged: (v) => _set(key, v),
      );

  Widget _group(String head, List<Widget> rows) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: cardBox(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: Text(head, style: T.h2)),
          ...rows,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final town = c.area?.name.split('/').first ?? '우리 동네';
    return DetailPage(
      title: '알림 설정',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
        const Text('받고 싶은 게시판만 켜 두세요. 처음엔 공지·소식만 켜져 있어요.', style: T.small),
        const SizedBox(height: 12),
        if (!c.isHome) _group('우리 단지 · ${c.name}', [for (final b in kBoards) _sw('complex.${b.$1}', b.$3)]),
        if (c.areaId.isNotEmpty) _group('우리 동네 · $town', [for (final b in kBoards) _sw('town.${b.$1}', b.$3)]),
        _group('그 밖에', [
          _sw('job', '일자리 마당 새 공고', '하루 한 번 모아서 「새 공고 ○건」'),
          _sw('mycomment', '내 글에 댓글이 달리면', me == null ? '로그인하면 받을 수 있어요' : ''),
        ]),
        const Text('휴대폰 설정에서 니즈콕 알림을 꺼 두면 여기서 켜도 오지 않아요.', style: T.tiny),
      ]),
    );
  }
}
