// 복권 — 공 · 등수표 · 줄 · QR 읽기 창 (이 폴더는 복권 담당 방만 고침)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/qr.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

// 로또 공 하나 (윤기 나는 입체 공). dim = 안 맞은 번호 (회색 테두리만)
class Ball extends StatelessWidget {
  final int n;
  final double size;
  final bool dim;
  const Ball(this.n, {super.key, this.size = 32, this.dim = false});

  @override
  Widget build(BuildContext context) {
    if (dim) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: kLine)),
        child: Text('$n', style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: kMute, height: 1)),
      );
    }
    final c = ballColor(n);
    final hsl = HSLColor.fromColor(c);
    final light = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 0.92)).toColor();
    final dark = hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.35, -0.45), radius: 0.95, colors: [light, c, dark], stops: const [0, 0.55, 1]),
        boxShadow: size >= 28 ? [BoxShadow(color: dark.withValues(alpha: 0.28), blurRadius: size * 0.22, offset: Offset(0, size * 0.06))] : null,
      ),
      child: Text('$n',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
            letterSpacing: -0.3,
            shadows: [Shadow(color: dark.withValues(alpha: 0.5), blurRadius: 2, offset: const Offset(0, 0.5))],
          )),
    );
  }
}

// 금빛 트로피 (1등 표시)
class Trophy extends StatelessWidget {
  final double size;
  const Trophy({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE27A), Color(0xFFF5B800), Color(0xFFD98E04)],
        ).createShader(r),
        child: Icon(Icons.emoji_events_rounded, size: size),
      );
}

// 순위 동그라미: 1위는 금빛, 나머지는 옅은 파랑
class RankBadge extends StatelessWidget {
  final int n;
  const RankBadge(this.n, {super.key});
  @override
  Widget build(BuildContext context) {
    final gold = n == 1;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gold
            ? const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFF4C8), Color(0xFFFFE08A), Color(0xFFF2B935)], stops: [0, 0.6, 1])
            : null,
        color: gold ? null : const Color(0xFFEAF1FC),
        border: gold ? Border.all(color: const Color(0xFFF0C24B)) : null,
      ),
      child: Text('$n', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: gold ? const Color(0xFF7A4B00) : const Color(0xFF1E3A6E), height: 1)),
    );
  }
}

// 「1등 3회」 알약 (1위는 트로피가 붙은 금빛)
class WinPill extends StatelessWidget {
  final int wins;
  final bool gold;
  const WinPill(this.wins, {super.key, this.gold = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(gold ? 8 : 12, 4, 12, 4),
        decoration: BoxDecoration(color: gold ? const Color(0xFFFFF5D9) : const Color(0xFFEEF3FA), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (gold) ...[const Trophy(size: 15), const SizedBox(width: 3)],
          Text.rich(TextSpan(children: [
            const TextSpan(text: '1등 ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: '$wins회', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]), style: const TextStyle(fontSize: 12.5, color: Color(0xFF1B2540), height: 1.2)),
        ]),
      );
}

// 판매점 그림 (주황 줄무늬 차양 + 파란 가게)
class ShopArt extends StatelessWidget {
  final double size;
  const ShopArt({super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => Container(
        width: size + 10,
        height: size + 10,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F5FB)),
        child: CustomPaint(size: Size(size * 0.78, size * 0.72), painter: _ShopPainter()),
      );
}

class _ShopPainter extends CustomPainter {
  @override
  void paint(Canvas cv, Size sz) {
    final w = sz.width, h = sz.height;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.36, w * 0.84, h * 0.62), Radius.circular(w * 0.06));
    cv.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6FB2FF), Color(0xFF2F7FF0)]).createShader(body.outerRect));
    // 창과 문
    final win = Paint()..color = const Color(0xFFDDEEFF);
    cv.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.17, h * 0.52, w * 0.3, h * 0.24), Radius.circular(w * 0.03)), win);
    cv.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.56, h * 0.52, w * 0.26, h * 0.46), Radius.circular(w * 0.03)), Paint()..color = const Color(0xFF1F5FC4));
    // 차양: 주황·흰 줄무늬, 아래는 물결
    const stripes = 5;
    final sw = w / stripes;
    for (var i = 0; i < stripes; i++) {
      final path = Path()
        ..moveTo(i * sw + sw * 0.1, 0)
        ..lineTo((i + 1) * sw - sw * 0.1, 0)
        ..lineTo((i + 1) * sw, h * 0.3)
        ..arcToPoint(Offset(i * sw, h * 0.3), radius: Radius.circular(sw * 0.5))
        ..close();
      cv.drawPath(path, Paint()..color = i.isEven ? const Color(0xFFFF8A2A) : const Color(0xFFFFE3C6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// 옅은 동그라미 화살표 단추 (회차 넘기기)
class SoftArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const SoftArrow(this.icon, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: onTap == null ? const Color(0xFFF6F8FB) : const Color(0xFFEEF3FB)),
          child: Icon(icon, size: 24, color: onTap == null ? kLine : const Color(0xFF1E3A6E)),
        ),
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

// 1~5등 당첨금 표 (넓으면 꽉 채우고, 휴대폰에서 좁으면 옆으로 밀기)
class PrizeTable extends StatelessWidget {
  final Draw draw;
  const PrizeTable({super.key, required this.draw});

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w500, height: 1.2);
    const div = Color(0xFFDDE4EE);
    Widget col(String rank, String p, String w) => Container(
          constraints: const BoxConstraints(minWidth: 88),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rank, style: head),
            const SizedBox(height: 3),
            Text(p, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kInk, height: 1.25, letterSpacing: -0.3)),
            Text(w, maxLines: 1, style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
          ]),
        );
    Widget line() => Container(width: 1, height: 38, color: div);
    final basis = Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      color: const Color(0xFFE6EFFC),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('맞히는 기준', style: head),
          SizedBox(width: 3),
          Icon(Icons.info_outline_rounded, size: 13, color: kBlue),
        ]),
        SizedBox(height: 3),
        Text('2등 5개+보너스', maxLines: 1, style: TextStyle(fontSize: 11, color: kSub, height: 1.35)),
        Text('3등 5 · 4등 4 · 5등 3', maxLines: 1, style: TextStyle(fontSize: 11, color: kSub, height: 1.35)),
      ]),
    );
    final ranks = [
      for (var r = 2; r <= 5; r++) col('$r등', draw.prize(r) > 0 ? won(draw.prize(r)) : '-', draw.winners(r) > 0 ? people(draw.winners(r)) : ''),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF3F6FA),
        child: LayoutBuilder(builder: (ctx, box) {
          if (box.maxWidth >= 4 * 88 + 128 + 4) {
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) Center(child: line()),
                  Expanded(flex: 10, child: ranks[i]),
                ],
                Expanded(flex: 14, child: basis),
              ]),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < 4; i++) ...[if (i > 0) Center(child: line()), ranks[i]],
                basis,
              ]),
            ),
          );
        }),
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
//  rank > 0 → 「1등 나온 집」 줄 (순위 배지 + 알약)   rank == 0 → 「복권 판매점」 줄 (가게 그림 + 전화 단추)
class StoreLine extends StatelessWidget {
  final Store store;
  final double dist;
  final int rank;
  final VoidCallback onTap;
  const StoreLine({super.key, required this.store, required this.dist, this.rank = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final winRow = rank > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(children: [
          if (winRow) RankBadge(rank) else const ShopArt(size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 13, color: kBlue),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    [distText(dist), if (s.addr.isNotEmpty) _shortAddr(s.addr)].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: kSub, height: 1.3),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          if (s.wins > 0)
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              WinPill(s.wins, gold: winRow && rank == 1),
              if (winRow && s.last > 0) ...[const SizedBox(height: 3), Text('최근 ${s.last}회', style: const TextStyle(fontSize: 10.5, color: kMute))],
            ])
          else if (s.tel.isNotEmpty)
            InkWell(
              onTap: () => callTel(s.tel),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                child: const Icon(Icons.call_outlined, size: 19, color: kBlue),
              ),
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
// 휴대폰: 공용 카메라(core/qr.dart scanQr)로 용지 QR 을 읽는다.  웹 미리보기: 카메라가 없어 주소 붙여 넣기 창.
Future<Ticket?> scanTicket(BuildContext context) async {
  if (kIsWeb) return showSheet<Ticket>(context, (ctx) => const _QrPaste());
  final text = await scanQr(context, title: '로또 용지 QR');
  if (text == null || !context.mounted) return null;
  final t = parseTicketQr(text);
  if (t == null) toast(context, '로또 용지 QR이 아니에요. 용지 오른쪽 아래 QR을 비춰 주세요.');
  return t;
}

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
          const Text('미리보기 화면에서는 카메라를 쓸 수 없어요. 휴대폰 앱에서는 바로 카메라가 켜져요. 여기서는 용지 QR 주소를 붙여 넣어 확인해 보세요.',
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
