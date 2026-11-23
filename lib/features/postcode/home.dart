// 택배·우편 첫 화면 + 택배 조회 (이 폴더는 택배·우편 담당 방만 고침)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
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

  @override
  Widget build(BuildContext context) => DetailPage(
        title: '택배·우편',
        icon: 'post',
        white: false,
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
          _track(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _tile('우편번호 찾기', zip == null ? '주소로 찾고 바로 복사' : '우리 단지 ${zip![0]}', const LineIcon('post', size: 30, fill: kSoftYellow), () => _go(ZipPage(widget.c)))),
            const SizedBox(width: 10),
            Expanded(child: _tile('영문 주소', '해외직구 칸별 복사', const PostIcon('globe', size: 30), () => _go(EngPage(widget.c)))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _tile('우체국·택배 접수', '가까운 우체국 · 편의점', const PostIcon('postbox', size: 30, fill: kSoftOrange), () => _go(OfficePage(widget.c)))),
            const SizedBox(width: 10),
            Expanded(child: _tile('저장 주소', saved > 0 ? '$saved곳 저장해 둠' : '「부모님 댁」처럼 이름 붙여', const PostIcon('saved', size: 30, fill: kSoftGreen), () => _go(SavedPage(widget.c)))),
          ]),
        ]),
      );

  // ---- 택배 조회 ----
  Widget _track() => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const MixTitle('택배', '조회', size: 16),
            const Spacer(),
            if (parcels.isNotEmpty) Text('${parcels.where((p) => !p.done).length}건 오는 중', style: T.tiny),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: no,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _add(),
                style: const TextStyle(fontSize: 14.5, letterSpacing: 0.3),
                decoration: inputDeco('운송장 번호').copyWith(
                  suffixIcon: TextButton(
                    onPressed: _paste,
                    style: TextButton.styleFrom(foregroundColor: kSub, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 36)),
                    child: const Text('붙여넣기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Btn('조회', primary: true, h: 44, onTap: _add)),
          ]),
          if (parcels.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 10, 2, 8),
              child: Text('조회한 택배는 여기에 모이고, 배송 완료 7일 뒤 저절로 정리돼요', style: T.tiny),
            )
          else ...[
            const SizedBox(height: 6),
            for (final p in parcels) _ParcelRow(p: p, onDone: () => _toggleDone(p), onRemove: () => _remove(p)),
          ],
        ]),
      );

  Widget _tile(String t, String sub, Widget icon, VoidCallback onTap) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Ink(
            height: 112,
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              icon,
              const Spacer(),
              Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ]),
          ),
        ),
      );
}

// ---- 조회한 택배 한 줄 ----
class _ParcelRow extends StatelessWidget {
  final Parcel p;
  final VoidCallback onDone, onRemove;
  const _ParcelRow({required this.p, required this.onDone, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final grey = p.done;
    return InkWell(
      onTap: () => openUrl(p.c.trackUrl(p.no), inApp: true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
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
