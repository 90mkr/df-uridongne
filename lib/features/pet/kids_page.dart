// 우리 아이 수첩 — 화면 (반려동물 테마 방)
// 아이마다: 이름·종류·생일(나이)·몸무게·다니는 병원 + 챙길 것(심장사상충·구충·접종…) 다음 날짜와 D-day, 「오늘 했어요」
import 'package:flutter/material.dart';

import '../../core/home_layout.dart';

import '../../core/icons.dart';
import '../../core/notify.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'kids.dart';

class PetKidsPage extends StatefulWidget {
  const PetKidsPage({super.key});
  @override
  State<PetKidsPage> createState() => _PetKidsPageState();
}

class _PetKidsPageState extends State<PetKidsPage> {
  @override
  void initState() {
    super.initState();
    loadKids().whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _edit([Kid? k]) async {
    final r = await Navigator.of(context).push<Kid?>(MaterialPageRoute(builder: (_) => _KidForm(kid: k)));
    if (r == null) return;
    final list = List.of(kids.value);
    final i = list.indexWhere((x) => x.id == r.id);
    if (r.name.isEmpty) {
      if (i >= 0) list.removeAt(i); // 지우기
    } else if (i >= 0) {
      list[i] = r;
    } else {
      list.add(r);
    }
    await askNotePermission();
    await saveKids(list);
    if (list.isNotEmpty) await setHomeCardOn('m:pet'); // 우리 아이를 등록하면 홈 첫 화면에 「오늘의 반려 생활」
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => DetailPage(
        title: '우리 아이 수첩',
        icon: 'book',
        white: false,
        actions: [TextButton(onPressed: () => _edit(), child: const Text('아이 등록', style: TextStyle(fontWeight: FontWeight.w700)))],
        body: ValueListenableBuilder<List<Kid>>(
          valueListenable: kids,
          builder: (_, list, __) => list.isEmpty
              ? _Empty(onAdd: () => _edit())
              : ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
                  for (final k in list) ...[_KidCard(kid: k, onEdit: () => _edit(k), onChanged: () => setState(() {})), const SizedBox(height: 14)],
                  const Text('휴대폰을 바꿔도 로그인하면 그대로 돌아와요. 날짜가 다가오면 사흘 전과 당일 아침 9시에 알려 드려요.', style: T.tiny),
                ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LineIcon('pet', size: 64),
            const SizedBox(height: 16),
            const MixTitle('우리 아이를', '등록해 주세요', size: 18),
            const SizedBox(height: 8),
            const Text('심장사상충·구충·접종 날짜를 기억해 두었다가\n때가 되면 알려 드려요', style: T.small, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(width: 220, child: Btn('아이 등록하기', icon: 'pet', primary: true, onTap: onAdd)),
          ]),
        ),
      );
}

String ddayText(int n) => n == 0 ? '오늘' : (n > 0 ? 'D-$n' : '${-n}일 지남');

class _KidCard extends StatelessWidget {
  final Kid kid;
  final VoidCallback onEdit, onChanged;
  const _KidCard({required this.kid, required this.onEdit, required this.onChanged});

  Future<void> _done(BuildContext context, Care c) async {
    c.last = DateTime.now();
    await saveKids(kids.value);
    onChanged();
    if (context.mounted) toast(context, '${careById(c.id).name} 기록했어요 · 다음은 ${c.next.month}월 ${c.next.day}일');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cares = List.of(kid.cares)..sort((a, b) => a.next.compareTo(b.next));
    final info = [kid.kind, if (kid.breed.isNotEmpty) kid.breed, if (kid.ageText.isNotEmpty) kid.ageText, if (kid.weight > 0) '${kid.weight}kg'].join(' · ');
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const LineIcon('pet', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kid.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              Text(info, style: T.small),
            ]),
          ),
          TextButton(onPressed: onEdit, child: const Text('고치기', style: TextStyle(fontSize: 12.5))),
        ]),
        if (kid.hosp.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Text('다니는 병원  ', style: T.small),
            Expanded(child: Text(kid.hosp, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            if (kid.hospTel.isNotEmpty) IconButton(visualDensity: VisualDensity.compact, onPressed: () => callTel(kid.hospTel), icon: const LineIcon('phone', size: 22)),
          ]),
        ],
        const SizedBox(height: 6),
        if (cares.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('챙길 것을 「고치기」에서 골라 주세요', style: T.small))
        else
          for (final c in cares)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
              child: Row(children: [
                SizedBox(
                  width: 56,
                  child: Text(ddayText(dayDiff(c.next, now)),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: dayDiff(c.next, now) <= 3 && c == cares.first ? kBlue : kInk)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(careById(c.id).name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('다음 ${c.next.month}월 ${c.next.day}일 · 마지막 ${c.last.month}월 ${c.last.day}일', style: T.tiny),
                  ]),
                ),
                TextButton(
                  onPressed: () => _done(context, c),
                  child: const Text('오늘 했어요', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
      ]),
    );
  }
}

// ---------------- 등록·고치기 ----------------
class _KidForm extends StatefulWidget {
  final Kid? kid;
  const _KidForm({this.kid});
  @override
  State<_KidForm> createState() => _KidFormState();
}

class _KidFormState extends State<_KidForm> {
  late final name = TextEditingController(text: widget.kid?.name ?? '');
  late final breed = TextEditingController(text: widget.kid?.breed ?? '');
  late final weight = TextEditingController(text: (widget.kid?.weight ?? 0) > 0 ? '${widget.kid!.weight}' : '');
  late final hosp = TextEditingController(text: widget.kid?.hosp ?? '');
  late final hospTel = TextEditingController(text: widget.kid?.hospTel ?? '');
  late String kind = widget.kid?.kind ?? '강아지';
  late DateTime? birth = widget.kid?.birth;
  late final Map<String, Care> cares = {for (final c in widget.kid?.cares ?? <Care>[]) c.id: Care(c.id, c.last, c.days)};

  String _d(DateTime d) => '${d.year}. ${d.month}. ${d.day}.';

  Future<DateTime?> _pick(DateTime? init, {DateTime? last}) => showDatePicker(
        context: context,
        initialDate: init ?? DateTime.now(),
        firstDate: DateTime(1995),
        lastDate: last ?? DateTime.now(),
      );

  void _save() {
    if (name.text.trim().isEmpty) {
      toast(context, '이름을 적어 주세요');
      return;
    }
    Navigator.of(context).pop(Kid(
      id: widget.kid?.id ?? DateTime.now().millisecondsSinceEpoch,
      name: name.text.trim(),
      kind: kind,
      breed: breed.text.trim(),
      birth: birth,
      weight: double.tryParse(weight.text.trim()) ?? 0,
      hosp: hosp.text.trim(),
      hospTel: hospTel.text.trim(),
      cares: [for (final c in kCares) if (cares[c.id] != null) cares[c.id]!],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final list = kCares.where((c) => !(c.dogOnly && kind != '강아지') && !(c.catOnly && kind != '고양이')).toList();
    return DetailPage(
      title: widget.kid == null ? '아이 등록' : '${widget.kid!.name} 고치기',
      icon: 'pet',
      actions: [
        if (widget.kid != null)
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  content: Text('${widget.kid!.name}의 수첩을 지울까요?'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('그대로 두기')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('지우기'))],
                ),
              );
              if (ok == true && context.mounted) Navigator.of(context).pop(Kid(id: widget.kid!.id, name: ''));
            },
            child: const Text('지우기', style: TextStyle(color: kSub)),
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 30), children: [
        Field('이름', name, hint: '예: 콩이', need: true, max: 20),
        const Text('종류', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          for (final k in ['강아지', '고양이', '그 밖']) ...[ChoiceChipBox(k, on: kind == k, onTap: () => setState(() => kind = k)), const SizedBox(width: 6)],
        ]),
        const SizedBox(height: 14),
        Field('품종', breed, hint: '예: 말티즈 (몰라도 괜찮아요)', max: 30),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('생일', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final d = await _pick(birth);
                  if (d != null) setState(() => birth = d);
                },
                child: InputDecorator(decoration: inputDeco(''), child: Text(birth == null ? '고르기' : _d(birth!), style: TextStyle(fontSize: 14.5, color: birth == null ? kMute : kInk))),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 0), child: Field('몸무게(kg)', weight, hint: '예: 4.2', type: const TextInputType.numberWithOptions(decimal: true), max: 6))),
        ]),
        const SizedBox(height: 14),
        Field('다니는 병원', hosp, hint: '예: 송도 ○○동물병원', max: 30),
        Field('병원 전화', hospTel, hint: '032-000-0000', type: TextInputType.phone, max: 20),
        const SizedBox(height: 6),
        const MixTitle('챙길 것', '마지막으로 한 날을 골라 주세요', size: 14.5),
        const SizedBox(height: 4),
        const Text('주기는 일반적인 기준이에요. 병원에서 다르게 말하면 바꿔 주세요.', style: T.tiny),
        const SizedBox(height: 6),
        for (final ck in list) _careRow(ck),
        const SizedBox(height: 22),
        Btn('저장', primary: true, onTap: _save),
      ]),
    );
  }

  Widget _careRow(CareKind ck) {
    final c = cares[ck.id];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        Checkbox(
          value: c != null,
          visualDensity: VisualDensity.compact,
          onChanged: (v) async {
            if (v != true) {
              setState(() => cares.remove(ck.id));
              return;
            }
            final d = await _pick(DateTime.now());
            if (d != null) setState(() => cares[ck.id] = Care(ck.id, d, ck.days));
          },
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ck.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            Text(c == null ? ck.desc : '마지막 ${_d(c.last)}', style: T.tiny),
          ]),
        ),
        if (c != null)
          DropdownButton<int>(
            value: [30, 60, 90, 180, 365].contains(c.days) ? c.days : null,
            hint: Text('${c.days}일마다', style: const TextStyle(fontSize: 12.5)),
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12.5, color: kInk),
            items: const [
              DropdownMenuItem(value: 30, child: Text('매달')),
              DropdownMenuItem(value: 60, child: Text('두 달마다')),
              DropdownMenuItem(value: 90, child: Text('석 달마다')),
              DropdownMenuItem(value: 180, child: Text('반년마다')),
              DropdownMenuItem(value: 365, child: Text('해마다')),
            ],
            onChanged: (v) => setState(() => c.days = v ?? c.days),
          ),
      ]),
    );
  }
}
