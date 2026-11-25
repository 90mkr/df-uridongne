// 택배·우편 첫 화면 + 택배 조회 (이 폴더는 택배·우편 담당 방만 고침)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'address.dart';
import 'data.dart';
import 'office.dart';

class PostHome extends StatefulWidget {
  final Complex c;
  const PostHome(this.c, {super.key});
  @override
  State<PostHome> createState() => _PostHomeState();
}

class _PostHomeState extends State<PostHome> {
  final no = TextEditingController();
  List<Parcel> parcels = [];
  List<String>? zip;
  int saved = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await loadParcels();
    final z = await complexZip(widget.c);
    final a = await loadAddrs();
    if (!mounted) return;
    setState(() {
      parcels = p;
      zip = z;
      saved = a.length;
    });
  }

  @override
  void dispose() {
    no.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = cleanNo(d?.text ?? '');
    if (t.isEmpty) {
      if (mounted) toast(context, '복사해 둔 운송장 번호가 없어요');
      return;
    }
    no.text = t;
    _add();
  }

  Future<void> _add() async {
    final n = cleanNo(no.text);
    if (n.length < 8) {
      toast(context, '운송장 번호를 넣어 주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    final have = parcels.where((p) => p.no == n).firstOrNull;
    if (have != null) {
      no.clear();
      openUrl(have.c.trackUrl(have.no), inApp: true);
      return;
    }
    final r = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CarrierSheet(no: n),
    );
    if (r == null || !mounted) return;
    final p = Parcel(no: n, carrier: r.$1, memo: r.$2, at: DateTime.now().millisecondsSinceEpoch);
    setState(() {
      parcels.insert(0, p);
      no.clear();
    });
    await saveParcels(parcels);
    openUrl(p.c.trackUrl(p.no), inApp: true);
  }

  Future<void> _toggleDone(Parcel p) async {
    setState(() {
      if (p.done) {
        p.stage = -1;
        p.doneAt = 0;
      } else {
        p.stage = 3;
        p.doneAt = DateTime.now().millisecondsSinceEpoch;
      }
    });
    await saveParcels(parcels);
  }

  Future<void> _remove(Parcel p) async {
    setState(() => parcels.remove(p));
    await saveParcels(parcels);
    if (mounted) toast(context, '목록에서 뺐어요');
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => _load());

  // ---- 화면 (대표님 시안 11-25) ----
  // 위: 택배 사진(오른쪽 트럭·상자) — 아래 끝은 바탕색으로 서서히 녹여 경계선이 절대 안 생기게
  // 가운데: 파란 「택배 조회」 판 / 아래: 입체 아이콘 2×2 칸(칸마다 옅은 다른 빛)
  static const _bgTop = Color(0xFFF3F7FE), _bgBottom = Color(0xFFE2EDFC);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final w = MediaQuery.of(context).size.width;
    // 폰: 사진을 화면 너비에 맞춰(3:1) 트럭·상자가 제목 오른쪽에 다 보이게 / 넓은 화면: 높이 260 고정
    final artH = w < 600 ? w / 3 + top * 0.4 : 260.0 + top; // 상태 표시줄 밑까지 사진(하늘)이 깔림 — 띠를 따로 칠하지 않음
    final narrow = w < 380;
    return Scaffold(
      backgroundColor: _bgTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])),
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: artH,
            child: ShaderMask(
              // 사진 아래 45%를 투명으로 서서히 → 바탕 그라데이션과 이어짐 (끝 줄에 색이 남지 않게 마지막은 완전 투명)
              shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Color(0x00FFFFFF), Color(0x00FFFFFF)], stops: [0, 0.72, 0.98, 1]).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/art/parcel_bg.jpg', fit: BoxFit.cover, alignment: w < 600 ? Alignment.bottomCenter : const Alignment(1, 0.3), filterQuality: FilterQuality.medium),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: EdgeInsets.fromLTRB(kPad, top + 6, kPad, 32), children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 26, color: kInk)),
                  const SizedBox(width: 2),
                  Image.asset('assets/icons/envelope.png', width: 36, height: 36),
                  const SizedBox(width: 10),
                  const Text('택배·우편', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk)),
                ]),
                SizedBox(height: w < 600 ? (artH * 0.84 - top - 54).clamp(24.0, 120.0) : 150),
                _track(),
                if (parcels.isNotEmpty) ...[const SizedBox(height: 12), _list()],
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _tile('우편번호 찾기', zip == null ? '주소로 찾고 바로 복사' : '우리 단지 ${zip![0]}', 'envelope', const [Color(0xFFFFF7EC), Color(0xFFFDEBD6)], narrow, () => _go(ZipPage(widget.c)))),
                  const SizedBox(width: 12),
                  Expanded(child: _tile('영문 주소', '해외직구 간편 복사', 'globe', const [Color(0xFFF1F6FF), Color(0xFFDDE9FD)], narrow, () => _go(EngPage(widget.c)))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _tile('우체국·택배 접수', '가까운 우체국 · 편의점', 'postbox', const [Color(0xFFF6F3FF), Color(0xFFE8E3FB)], narrow, () => _go(OfficePage(widget.c)))),
                  const SizedBox(width: 12),
                  Expanded(child: _tile('저장 주소', saved > 0 ? '$saved곳 저장해 둠' : '「부모님 댁」처럼 이름 붙여', 'housestar', const [Color(0xFFF0FBF8), Color(0xFFDDF3EE)], narrow, () => _go(SavedPage(widget.c)))),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ---- 택배 조회: 파란 판 ----
  Widget _track() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2C7BEF), Color(0xFF0B52CF)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x2E0B52CF), blurRadius: 18)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // 오른쪽 위 옅은 돋보기 (장식)
          const Positioned(right: 14, top: 8, child: Icon(Icons.search_rounded, size: 58, color: Color(0x2EFFFFFF))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Image.asset('assets/icons/parcel.png', width: 36, height: 36),
                const SizedBox(width: 10),
                const Text('택배 조회', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                const Spacer(),
                if (parcels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('${parcels.where((p) => !p.done).length}건 오는 중', style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.local_shipping_outlined, size: 22, color: Color(0xFF9AA7BB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: no,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _add(),
                          style: const TextStyle(fontSize: 15, letterSpacing: 0.3),
                          decoration: const InputDecoration(
                            hintText: '운송장 번호',
                            hintStyle: TextStyle(fontSize: 15, color: Color(0xFF8A95A8)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFE3E8F0)),
                      InkWell(
                        onTap: _paste,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(10, 8, 12, 8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.content_paste_rounded, size: 17, color: Color(0xFF5A6475)),
                            SizedBox(width: 4),
                            Text('붙여넣기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF3F4756))),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _add,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFDB4D), Color(0xFFFFC21A)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_rounded, size: 20, color: kInk),
                        SizedBox(width: 4),
                        Text('조회', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kInk)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 11),
              const Text('조회한 택배는 여기에 모이고, 배송 완료 7일 뒤 저절로 정리돼요.', style: TextStyle(fontSize: 12, color: Color(0xE6FFFFFF), height: 1.35)),
            ]),
          ),
        ]),
      );

  // 조회한 택배 목록 (흰 칸)
  Widget _list() => Container(
        decoration: cardBox(r: 18),
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
        child: Column(children: [
          for (final (i, p) in parcels.indexed) _ParcelRow(p: p, first: i == 0, onDone: () => _toggleDone(p), onRemove: () => _remove(p)),
        ]),
      );

  // 2×2 칸: 옅은 빛 그라데이션 + 흰 테두리 + 입체 아이콘 · 제목 · 설명 · 오른쪽 아래 흰 동그라미 화살표
  Widget _tile(String t, String sub, String icon, List<Color> tint, bool narrow, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x140B2A5B), blurRadius: 14)],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              height: narrow ? 122 : 132,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Stack(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Image.asset('assets/icons/$icon.png', width: narrow ? 44 : 50, height: narrow ? 44 : 50),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 30),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(t, maxLines: 1, style: TextStyle(fontSize: narrow ? 15.5 : 17, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(right: 30),
                    child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: narrow ? 11.5 : 12.5, color: const Color(0xFF5A6475))),
                  ),
                ]),
                Positioned(
                  right: 0,
                  bottom: 6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A0B2A5B), blurRadius: 6)]),
                    child: const Icon(Icons.chevron_right_rounded, size: 20, color: kInk),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ---- 조회한 택배 한 줄 ----
class _ParcelRow extends StatelessWidget {
  final Parcel p;
  final bool first;
  final VoidCallback onDone, onRemove;
  const _ParcelRow({required this.p, required this.onDone, required this.onRemove, this.first = false});

  @override
  Widget build(BuildContext context) {
    final grey = p.done;
    return InkWell(
      onTap: () => openUrl(p.c.trackUrl(p.no), inApp: true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: kLine))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(p.memo.isNotEmpty ? p.memo : p.c.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(color: grey ? kMute : kInk)),
            ),
            const SizedBox(width: 6),
            if (grey) const Pill('완료'),
            const Spacer(),
            _link('완료', onDone, on: grey),
            _link('삭제', onRemove),
          ]),
          const SizedBox(height: 3),
          Text('${p.memo.isNotEmpty ? '${p.c.name} · ' : ''}${p.no}', style: T.small.copyWith(letterSpacing: 0.2)),
          if (p.stage >= 0) ...[
            const SizedBox(height: 10),
            StageCircles(stage: p.stage),
            if (p.where.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(p.where, style: T.tiny)),
          ],
        ]),
      ),
    );
  }

  Widget _link(String t, VoidCallback f, {bool on = false}) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 2, 3),
          child: Text(on ? '완료 취소' : t, style: const TextStyle(fontSize: 11.5, color: kSub, fontWeight: FontWeight.w600)),
        ),
      );
}

// 배송 단계: 살짝 겹친 흰 동그라미, 지금 단계만 파랑 (디자인필 공용 단계 모양)
class StageCircles extends StatelessWidget {
  final int stage;
  const StageCircles({super.key, required this.stage});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: Stack(children: [
          for (var i = kStages.length - 1; i >= 0; i--)
            Positioned(
              left: i * 40.0,
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == stage ? kBlue : Colors.white,
                  border: Border.all(color: i == stage ? kBlue : kLine),
                ),
                child: Text(kStages[i].replaceAll(' ', '\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, height: 1.1, fontWeight: FontWeight.w600, color: i == stage ? Colors.white : (i < stage ? kInk : kMute))),
              ),
            ),
        ]),
      );
}

// ---- 택배사 고르기 ----
class _CarrierSheet extends StatefulWidget {
  final String no;
  const _CarrierSheet({required this.no});
  @override
  State<_CarrierSheet> createState() => _CarrierSheetState();
}

class _CarrierSheetState extends State<_CarrierSheet> {
  late final List<String> guess = guessCarriers(widget.no);
  late String pick = guess.first;
  final memo = TextEditingController();
  bool all = false;

  @override
  void dispose() {
    memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = all ? [for (final c in kCarriers) c.id] : guess;
    return Padding(
      padding: EdgeInsets.fromLTRB(kPad, 18, kPad, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MixTitle('택배사', '고르기', size: 16),
        const SizedBox(height: 3),
        Text('${widget.no} · 번호 모양으로 짐작한 순서예요', style: T.small),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final id in ids) _chip(carrierById(id).name, pick == id, () => setState(() => pick = id)),
          if (!all) _chip('다른 택배사', false, () => setState(() => all = true)),
        ]),
        const SizedBox(height: 14),
        TextField(controller: memo, maxLength: 20, style: const TextStyle(fontSize: 14), decoration: inputDeco('무슨 물건인지 메모 (선택) · 예: 겨울 이불')),
        const SizedBox(height: 12),
        Btn('저장하고 조회', primary: true, onTap: () => Navigator.pop(context, (pick, memo.text.trim()))),
      ]),
    );
  }

  Widget _chip(String t, bool on, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: on ? kInk : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? kInk : kLine),
          ),
          child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : kInk)),
        ),
      );
}
