// 동네 전화번호부 — 명함 카드 (목록 · 지도 아래 상세 · 가게 창 모두 이 카드 하나)
// 대표님 11-23: 카드를 눌러 또 창이 뜨는 건 공간 낭비 → 추천하기·정보 수정까지 카드 안에서 끝낸다.
// 카드 몸통을 누르면 onTap (목록에서는 「지도에서 위치 보기」)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/icons.dart';
import '../../core/me.dart' show openLogin;
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'shop_sheet.dart' show FixForm, OwnerForm;

class ShopCard extends StatefulWidget {
  final Shop shop;
  final Complex complex;
  final bool selected;
  final VoidCallback? onTap; // 카드 몸통 누르기
  final String tapHint; // 몸통 오른쪽 위 작은 글 (예: 「지도」)
  final VoidCallback? onClose; // 지도 위 상세일 때 닫기
  final bool compact; // 휴대폰 목록(옆에 지도): 작게
  const ShopCard({super.key, required this.shop, required this.complex, this.selected = false, this.onTap, this.tapHint = '', this.onClose, this.compact = false});
  @override
  State<ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<ShopCard> {

  final picked = <String>{};

  Shop get s => widget.shop;
  Complex get c => widget.complex;

  @override
  void initState() {
    super.initState();
    recTick.addListener(_re);
    authTick.addListener(_re);
  }

  @override
  void didUpdateWidget(covariant ShopCard old) {
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    recTick.removeListener(_re);
    authTick.removeListener(_re);
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  // 추천: 누르면 작은 창이 떠서 바로 고르고 남김 (카드가 길어지지 않게, 대표님 11-24)
  Future<void> _startRec() async {
    if (me == null) {
      await openLogin(context);
      if (me == null) return;
      await loadRecs(c.areaId);
    }
    if (!mounted) return;
    final r = recsOf(c.areaId)[s.id];
    final mine = r?.mine == true;
    picked
      ..clear()
      ..addAll(r?.myStickers ?? const []);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.thumb_up_alt_rounded, size: 20, color: kBlue),
                const SizedBox(width: 8),
                Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
              ]),
              const SizedBox(height: 4),
              const Text('이웃에게 추천해 주세요. 어떤 점이 좋았나요? (3개까지)', style: TextStyle(fontSize: 12, color: kSub)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final st in kStickers)
                  ChoiceChipBox(st.text, on: picked.contains(st.id), onTap: () {
                    set(() {
                      if (picked.contains(st.id)) {
                        picked.remove(st.id);
                      } else if (picked.length < 3) {
                        picked.add(st.id);
                      } else {
                        toast(context, '3개까지 고를 수 있어요');
                      }
                    });
                  }),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Btn(mine ? '추천 거두기' : '닫기', h: 44, onTap: () {
                    Navigator.pop(ctx);
                    if (mine) _save(remove: true);
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Btn(mine ? '고친 추천 남기기' : '추천 남기기', primary: true, h: 44, onTap: () {
                    Navigator.pop(ctx);
                    _save();
                  }),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _save({bool remove = false}) async {
    final e = remove ? await removeRec(s, c.areaId) : await saveRec(s, c.areaId, picked.toList());
    if (!mounted) return;
    toast(context, e ?? (remove ? '추천을 거뒀어요' : '추천했어요. 고마워요!'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _small(context);
    final rec = recsOf(c.areaId)[s.id];
    final open = s.openAt(DateTime.now());
    final lot = nearestLot(s.pos);
    final cat = s.cats.isEmpty ? '' : catOf(s.cats.first).name;
    final mine = rec?.mine == true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: widget.selected ? kBlue : kLine, width: 1),
        boxShadow: kShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ---- 몸통 (누르면 지도에서 위치) ----
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Thumb(s),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.4)),
                      ),
                      if (s.owned) ...[const SizedBox(width: 6), const Pill('사장님 직접 관리', color: kBlue, bg: Color(0xFFEEF3FF))],
                    ]),
                    const SizedBox(height: 2),
                    Text([if (s.sub.isNotEmpty) s.sub, if (cat.isNotEmpty && cat != s.sub) cat].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub, height: 1.3)),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (open != Open.unknown) ...[OpenMark(open), const Text('  ·  ', style: TextStyle(fontSize: 11.5, color: kMute))],
                      Text('단지에서 ${distText(meters(c.pos, s.pos))}', style: const TextStyle(fontSize: 11.5, color: kInk, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ),
                if (widget.onClose != null)
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close_rounded, size: 20, color: kMute)),
                  )
                else if (widget.tapHint.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(7, 4, 8, 4),
                    decoration: BoxDecoration(color: const Color(0xFFF3F6FB), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.place_outlined, size: 13, color: kSub),
                      const SizedBox(width: 2),
                      Text(widget.tapHint, style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ---- 이웃 추천 (카드 안에서 바로) ----
              Row(children: [
                Text.rich(TextSpan(children: [
                  const TextSpan(text: '이웃 추천 '),
                  TextSpan(text: '${rec?.n ?? 0}', style: TextStyle(fontWeight: FontWeight.w800, color: (rec?.n ?? 0) > 0 ? kBlue : kMute)),
                ]), style: const TextStyle(fontSize: 12, color: kSub)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final st in rec?.topStickers ?? const <String>[]) ...[
                        Pill('${stickerText(st)} ${rec!.st[st]}'),
                        const SizedBox(width: 4),
                      ],
                    ]),
                  ),
                ),
                InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _startRec,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: mine ? Colors.white : const Color(0xFFEEF3FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: mine ? kLine : const Color(0xFFCADAFD)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(mine ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 14, color: kBlue),
                        const SizedBox(width: 4),
                        Text(mine ? '내 추천' : '추천', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kBlue)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              // ---- 근처 주차장 (없으면 주소) ----
              Row(children: [
                if (lot != null)
                  Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFF2F7BF5)),
                    child: const Text('P', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                  )
                else
                  const Icon(Icons.place_outlined, size: 15, color: kMute),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      lot != null ? '근처 주차장  ${lot.name} ${distText(lot.m)}${lot.fee.isEmpty ? '' : ' · ${lot.fee}'}' : (s.addr.isEmpty ? '주소 정보 없음' : s.addr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: kSub)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Btn(s.tel.isEmpty ? '번호 없음' : '전화하기', icon: 'phone', primary: s.tel.isNotEmpty, h: 38, onTap: s.tel.isEmpty ? null : () => callTel(s.tel)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Btn('길안내', icon: 'route', h: 38, onTap: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng))),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _link('정보가 달라요', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FixForm(shop: s, complex: c)))),
                Container(width: 1, height: 9, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 6)),
                _link('사장님이세요?', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OwnerForm(complex: c, shop: s)))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // 작은 카드 (휴대폰 목록 3/5 폭): 몸통 누르면 옆 지도로, 추천은 누르면 아래에 펼침
  Widget _small(BuildContext context) {
    final rec = recsOf(c.areaId)[s.id];
    final open = s.openAt(DateTime.now());
    final n = rec?.n ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.selected ? kBlue : kLine, width: 1),
        boxShadow: widget.selected ? [BoxShadow(color: kBlue.withValues(alpha: 0.18), blurRadius: 14)] : kShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 8, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 제목은 맨 위 한 줄 전체 (좁은 카드에서도 덜 잘리게, 대표님 11-24)
                Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.4)),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFF3F6FB), borderRadius: BorderRadius.circular(9)),
                    child: s.photo.startsWith('http')
                        ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(s.photo, width: 34, height: 34, fit: BoxFit.cover))
                        : LineIcon(s.cats.isEmpty ? 'pin' : s.cats.first, size: 26),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.sub.isNotEmpty ? s.sub : (s.cats.isEmpty ? '' : catOf(s.cats.first).name),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: kSub, height: 1.25)),
                      Row(children: [
                        Flexible(child: Text(distText(meters(c.pos, s.pos)), maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.3))),
                        if (n > 0) ...[const SizedBox(width: 4), Text('👍$n', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kBlue))],
                      ]),
                      if (open != Open.unknown) OpenMark(open),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
            child: Row(children: [
              Expanded(flex: 5, child: _mini(s.tel.isEmpty ? '번호없음' : '전화', Icons.call_rounded, s.tel.isEmpty ? null : () => callTel(s.tel), primary: s.tel.isNotEmpty)),
              const SizedBox(width: 4),
              Expanded(flex: 5, child: _mini('길안내', Icons.near_me_rounded, () => startNav(context, name: s.name, lat: s.lat, lng: s.lng))),
              const SizedBox(width: 4),
              // 추천: 엄지 손 (글 없이)
              Expanded(flex: 3, child: _mini('', rec?.mine == true ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, _startRec, soft: true)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _mini(String t, IconData icon, VoidCallback? f, {bool primary = false, bool soft = false}) => Material(
        color: primary ? kBlue : (soft ? const Color(0xFFEEF3FF) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: f,
          child: Container(
            height: 28,
            alignment: Alignment.center,
            decoration: primary || soft ? null : BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD5D9E0))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: primary ? Colors.white : (soft ? kBlue : kInk)),
              if (t.isNotEmpty) ...[
                const SizedBox(width: 2),
                Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: primary ? Colors.white : kInk))),
              ],
            ]),
          ),
        ),
      );

  Widget _link(String t, VoidCallback f) => InkWell(
        onTap: f,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2), child: Text(t, style: const TextStyle(fontSize: 11, color: kMute))),
      );
}

class _Thumb extends StatelessWidget {
  final Shop s;
  const _Thumb(this.s);
  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(color: const Color(0xFFF3F6FB), borderRadius: BorderRadius.circular(12));
    if (s.photo.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(s.photo, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon(box)),
      );
    }
    return _icon(box);
  }

  Widget _icon(BoxDecoration box) => Container(
        width: 64,
        height: 64,
        decoration: box,
        alignment: Alignment.center,
        child: LineIcon(s.cats.isEmpty ? 'pin' : s.cats.first, size: 44),
      );
}

// 영업 상태 표시 (점 + 글자)
class OpenMark extends StatelessWidget {
  final Open o;
  const OpenMark(this.o, {super.key});
  @override
  Widget build(BuildContext context) {
    final (t, c) = switch (o) {
      Open.open => ('영업 중', kBlue),
      Open.closing => ('곧 마감', const Color(0xFFE07A10)),
      Open.closed => ('영업 종료', kMute),
      Open.unknown => ('', kMute),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
    ]);
  }
}
