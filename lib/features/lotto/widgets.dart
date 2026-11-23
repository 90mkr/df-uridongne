// 복권 — 공 · 등수표 · 줄 · QR 읽기 창 (이 폴더는 복권 담당 방만 고침)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

// 로또 공 하나. dim = 안 맞은 번호 (회색 테두리만)
class Ball extends StatelessWidget {
  final int n;
  final double size;
  final bool dim;
  const Ball(this.n, {super.key, this.size = 32, this.dim = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dim ? Colors.white : ballColor(n),
          border: dim ? Border.all(color: kLine) : null,
        ),
        child: Text('$n',
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              color: dim ? kMute : Colors.white,
              height: 1,
              letterSpacing: -0.3,
            )),
      );
}

// 당첨번호 6개 + 보너스
class BallRow extends StatelessWidget {
  final List<int> nums;
  final int bonus;
  final double size;
  const BallRow({super.key, required this.nums, required this.bonus, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final gap = size * 0.14;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final n in nums) Padding(padding: EdgeInsets.only(right: gap), child: Ball(n, size: size)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: gap * 0.6),
        child: Text('+', style: TextStyle(fontSize: size * 0.45, color: kMute, fontWeight: FontWeight.w300)),
      ),
      Padding(padding: EdgeInsets.only(left: gap * 0.6), child: Ball(bonus, size: size)),
    ]);
  }
}

// 1~5등 당첨금 표 (휴대폰에서 좁으면 옆으로 밀기)
class PrizeTable extends StatelessWidget {
  final Draw draw;
  const PrizeTable({super.key, required this.draw});

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 10.5, color: kMute, fontWeight: FontWeight.w500);
    const cell = TextStyle(fontSize: 11.5, height: 1.3);
    Widget col(String rank, String p, String w) => Container(
          width: 86,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFF0F1F4)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rank, style: head),
            const SizedBox(height: 3),
            Text(p, maxLines: 1, style: cell.copyWith(fontWeight: FontWeight.w700)),
            Text(w, maxLines: 1, style: cell.copyWith(color: kSub, fontSize: 10.5)),
          ]),
        );
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var r = 2; r <= 5; r++)
            col('$r등', draw.prize(r) > 0 ? won(draw.prize(r)) : '-', draw.winners(r) > 0 ? people(draw.winners(r)) : ''),
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFF0F1F4)))),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('맞히는 기준', style: head),
              SizedBox(height: 3),
              Text('2등 5개+보너스', maxLines: 1, style: TextStyle(fontSize: 10.5, color: kSub, height: 1.3)),
              Text('3등 5 · 4등 4 · 5등 3', maxLines: 1, style: TextStyle(fontSize: 10.5, color: kSub, height: 1.3)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// 내 번호 한 줄: A  ● ● ○ ● ○ ○   3등
class GameLine extends StatelessWidget {
  final String label;
  final Game game;
  final Draw? draw; // null 이면 아직 추첨 전
  final VoidCallback? onTap;
  final Widget? trailing;
  const GameLine({super.key, required this.label, required this.game, this.draw, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final d = draw;
    final r = d == null ? -1 : rankOf(game.nums, d);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 18, child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kSub))),
          if (game.kind.isNotEmpty)
            SizedBox(width: 38, child: Text(game.kind, style: const TextStyle(fontSize: 10.5, color: kMute)))
          else
            const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final n in game.nums)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Ball(n, size: 27, dim: d != null && !d.nums.contains(n) && !(r == 2 && n == d.bonus)),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          if (r >= 0) RankTag(r, prize: d == null || r == 0 ? 0 : d.prize(r)) else const Text('추첨 전', style: T.tiny),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

class RankTag extends StatelessWidget {
  final int rank;
  final int prize;
  const RankTag(this.rank, {super.key, this.prize = 0});
  @override
  Widget build(BuildContext context) {
    final hit = rank > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: hit ? kBlue : const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(20)),
        child: Text(rankText(rank), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: hit ? Colors.white : kMute, height: 1.2)),
      ),
      if (hit && prize > 0) ...[const SizedBox(height: 2), Text(won(prize), style: const TextStyle(fontSize: 10, color: kSub))],
    ]);
  }
}

// 판매점 한 줄
class StoreLine extends StatelessWidget {
  final Store store;
  final double dist;
  final int rank; // 0 = 순위 표시 안 함
  final VoidCallback onTap;
  const StoreLine({super.key, required this.store, required this.dist, this.rank = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(children: [
          if (rank > 0)
            SizedBox(width: 22, child: Text('$rank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: rank <= 3 ? kInk : kMute))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 1),
              Text(
                [distText(dist), if (s.addr.isNotEmpty) _shortAddr(s.addr)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.tiny,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (s.wins > 0)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '1등 ', style: TextStyle(fontWeight: FontWeight.w400, color: kSub)),
                TextSpan(text: '${s.wins}회', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]), style: const TextStyle(fontSize: 12.5)),
              if (s.last > 0) Text('최근 ${s.last}회', style: const TextStyle(fontSize: 10, color: kMute)),
            ])
          else if (s.tel.isNotEmpty)
            InkWell(
              onTap: () => callTel(s.tel),
              child: const Padding(padding: EdgeInsets.all(4), child: LineIcon('phone', size: 22)),
            ),
        ]),
      ),
    );
  }
}

String _shortAddr(String a) {
  final p = a.split(' ');
  return p.length > 2 ? p.sublist(1).join(' ') : a;
}

// ---------------- QR 읽기 ----------------
// 카메라로 용지 QR 을 읽는 부품은 본부에 요청해 두었다 (requests/lotto-1123-QR-카메라.md).
// 그전까지는 QR 주소를 붙여 넣어 확인한다 (휴대폰 기본 카메라로 QR을 찍으면 나오는 주소를 길게 눌러 복사).
Future<Ticket?> scanTicket(BuildContext context) => showSheet<Ticket>(context, (ctx) => const _QrPaste());

class _QrPaste extends StatefulWidget {
  const _QrPaste();
  @override
  State<_QrPaste> createState() => _QrPasteState();
}

class _QrPasteState extends State<_QrPaste> {
  final ctl = TextEditingController();
  String err = '';

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) {
      ctl.text = d!.text!;
      _go();
    }
  }

  void _go() {
    final t = parseTicketQr(ctl.text);
    if (t == null) {
      setState(() => err = '로또 용지 QR 주소가 아니에요. 「v=」가 들어 있는 주소인지 확인해 주세요.');
      return;
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(kPad, 16, kPad, 14 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('QR로 확인', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('앱 안 카메라 읽기는 곧 열려요. 지금은 휴대폰 카메라로 용지 QR을 비추면 나오는 주소를 복사해 붙여 넣어 주세요.',
              style: TextStyle(fontSize: 12.5, color: kSub, height: 1.45)),
          const SizedBox(height: 14),
          TextField(
            controller: ctl,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 13.5),
            decoration: inputDeco('예) https://m.dhlottery.co.kr/?v=1251q…'),
            onSubmitted: (_) => _go(),
          ),
          if (err.isNotEmpty) ...[const SizedBox(height: 6), Text(err, style: const TextStyle(fontSize: 11.5, color: Color(0xFFD9534F)))],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Btn('붙여 넣기', onTap: _paste)),
            const SizedBox(width: 10),
            Expanded(child: Btn('확인', primary: true, onTap: _go)),
          ]),
        ]),
      );
}
