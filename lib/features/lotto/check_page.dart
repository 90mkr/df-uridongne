// 복권 — 내 번호 확인 · 저장 (이 폴더는 복권 담당 방만 고침)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'widgets.dart';

class CheckPage extends StatefulWidget {
  final Draws draws;
  final Ticket? ticket; // QR 로 읽은 용지
  const CheckPage({super.key, required this.draws, this.ticket});
  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  late int round;
  List<Game> games = [];
  List<MyTicket> saved = [];
  bool weekly = false; // 매주 확인하는 고정 번호

  int get latest => widget.draws.latest?.no ?? 0;
  Draw? get draw => widget.draws.byNo(round);

  @override
  void initState() {
    super.initState();
    final t = widget.ticket;
    round = t?.round ?? latest;
    games = [...?t?.games];
    loadMine().then((m) {
      if (mounted) setState(() => saved = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = draw;
    final future = round > latest;
    return DetailPage(
      title: '내 번호 확인',
      icon: 'lotto',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 34), children: [
        if (widget.ticket != null) ...[
          Text('용지 QR에서 ${widget.ticket!.games.length}게임을 읽었어요.', style: const TextStyle(fontSize: 12.5, color: kSub)),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
          child: Column(children: [
            Row(children: [
              IconButton(
                onPressed: round > (widget.draws.list.isEmpty ? 1 : widget.draws.list.first.no) ? () => setState(() => round--) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                color: kInk,
                disabledColor: kLine,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Column(children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '$round회', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: future ? ' 추첨 전' : ' 당첨번호', style: const TextStyle(fontWeight: FontWeight.w300)),
                  ]), style: const TextStyle(fontSize: 16, letterSpacing: -0.4)),
                  const SizedBox(height: 2),
                  Text(d != null ? '${d.dayText} 추첨' : (future ? '추첨이 끝나면 여기서 바로 맞춰 볼 수 있어요' : '이 회차 자료가 없어요'), style: T.tiny),
                ]),
              ),
              IconButton(
                onPressed: round <= latest ? () => setState(() => round++) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 26),
                color: kInk,
                disabledColor: kLine,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            if (d != null) ...[const SizedBox(height: 10), BallRow(nums: d.nums, bonus: d.bonus, size: 30)],
          ]),
        ),
        const SizedBox(height: 18),
        const MixTitle('내', '번호'),
        const SizedBox(height: 8),
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          child: Column(children: [
            for (var i = 0; i < games.length; i++) ...[
              if (i > 0) Container(height: 1, color: const Color(0xFFF0F1F4)),
              GameLine(
                label: String.fromCharCode(65 + i),
                game: games[i],
                draw: d,
                onTap: () => _edit(i),
                trailing: IconButton(
                  onPressed: () => setState(() => games.removeAt(i)),
                  icon: const Icon(Icons.close_rounded, size: 17, color: kMute),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
            if (games.length < 5)
              InkWell(
                onTap: () => _edit(-1),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: games.isEmpty ? null : const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F1F4)))),
                  child: Text(games.isEmpty ? '+ 번호 6개 고르기' : '+ 게임 추가 (${games.length}/5)',
                      style: const TextStyle(fontSize: 13, color: kBlue, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
        if (games.isNotEmpty) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => weekly = !weekly),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(weekly ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 19, color: weekly ? kBlue : kMute),
                const SizedBox(width: 6),
                const Expanded(child: Text('매주 사는 고정 번호예요 (회차마다 자동으로 맞춰 봐요)', style: TextStyle(fontSize: 12.5, color: kSub))),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Btn('내 번호로 저장', primary: true, onTap: _save),
        ],
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 28),
          const MixTitle('저장한', '번호'),
          const SizedBox(height: 8),
          Container(
            decoration: cardBox(),
            child: Column(children: [
              for (var i = 0; i < saved.length; i++) ...[
                if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: const Color(0xFFF0F1F4)),
                _savedLine(saved[i]),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 22),
        const Text('당첨 여부와 당첨금은 판매점이나 동행복권에서 꼭 다시 확인하세요. 저장한 번호는 이 휴대폰에만 남아요.',
            style: TextStyle(fontSize: 10.5, color: kMute, height: 1.5)),
      ]),
    );
  }

  Widget _savedLine(MyTicket t) {
    final r = t.round == 0 ? latest : t.round;
    final d = widget.draws.byNo(r);
    var best = -1;
    if (d != null) {
      best = 0;
      for (final g in t.games) {
        final k = rankOf(g.nums, d);
        if (k > 0 && (best == 0 || k < best)) best = k;
      }
    }
    return InkWell(
      onTap: () => setState(() {
        round = r;
        games = [...t.games];
        weekly = t.round == 0;
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.round == 0 ? '고정 번호 · 매주 확인' : '${t.round}회 용지', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text('${t.games.length}게임 · ${t.games.first.nums.join(' ')}${t.games.length > 1 ? ' …' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ]),
          ),
          if (best >= 0) RankTag(best) else const Text('추첨 전', style: T.tiny),
          IconButton(
            onPressed: () async {
              setState(() => saved.remove(t));
              await saveMine(saved);
            },
            icon: const Icon(Icons.close_rounded, size: 17, color: kMute),
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ),
    );
  }

  Future<void> _edit(int i) async {
    final g = await showSheet<Game>(context, (ctx) => NumberPicker(start: i >= 0 ? games[i].nums : const []));
    if (g == null || !mounted) return;
    setState(() {
      if (i >= 0) {
        games[i] = Game(g.nums, games[i].kind == g.kind ? g.kind : '');
      } else {
        games.add(g);
      }
    });
  }

  Future<void> _save() async {
    final r = weekly ? 0 : round;
    final list = [MyTicket(r, [...games]), ...saved.where((t) => !(t.round == r && _same(t.games, games)))];
    await saveMine(list);
    if (!mounted) return;
    setState(() => saved = list);
    toast(context, weekly ? '고정 번호로 저장했어요. 매주 복권 화면에서 결과가 보여요.' : '$round회 번호를 저장했어요.');
  }

  bool _same(List<Game> a, List<Game> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i].nums.join(',') == b[i].nums.join(',')].every((x) => x);
}

// 번호 6개 고르기 (용지처럼 1~45)
class NumberPicker extends StatefulWidget {
  final List<int> start;
  const NumberPicker({super.key, this.start = const []});
  @override
  State<NumberPicker> createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  late final Set<int> sel = {...widget.start};
  bool auto = false;

  void _fill() {
    final rnd = math.Random();
    setState(() {
      auto = sel.isEmpty;
      while (sel.length < 6) {
        sel.add(rnd.nextInt(45) + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('번호 6개 고르기', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700))),
            Text('${sel.length}/6', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel.length == 6 ? kBlue : kMute)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, box) {
            const cols = 7;
            final cell = math.min(44.0, (box.maxWidth - (cols - 1) * 6) / cols);
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (var n = 1; n <= 45; n++)
                GestureDetector(
                  onTap: () => setState(() {
                    auto = false;
                    if (sel.contains(n)) {
                      sel.remove(n);
                    } else if (sel.length < 6) {
                      sel.add(n);
                    }
                  }),
                  child: sel.contains(n)
                      ? Ball(n, size: cell)
                      : Container(
                          width: cell,
                          height: cell,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kLine)),
                          child: Text('$n', style: TextStyle(fontSize: cell * 0.36, color: sel.length == 6 ? kLine : kInk, fontWeight: FontWeight.w500)),
                        ),
                ),
            ]);
          }),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Btn(sel.isEmpty ? '자동으로' : '나머지 자동', h: 44, onTap: sel.length < 6 ? _fill : null)),
            const SizedBox(width: 10),
            Expanded(child: Btn('지우기', h: 44, onTap: sel.isEmpty ? null : () => setState(sel.clear))),
            const SizedBox(width: 10),
            Expanded(
              child: Btn('완료', h: 44, primary: true, onTap: sel.length == 6 ? () => Navigator.pop(context, Game(sel.toList()..sort(), auto ? '자동' : '')) : null),
            ),
          ]),
        ]),
      );
}
