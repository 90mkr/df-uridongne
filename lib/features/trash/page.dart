// 쓰레기·분리수거 상세 화면
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/me.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'feature.dart' show TrashHero;
import 'guide.dart';
import 'trash_icons.dart';

const _week = '월화수목금토일';

class TrashPage extends StatefulWidget {
  final Complex complex;
  const TrashPage({super.key, required this.complex});
  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  TrashInfo? info;
  bool loading = true;

  Complex get c => widget.complex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fresh = false}) async {
    if (fresh) forgetTrash(c);
    final i = await trashOf(c);
    if (!mounted) return;
    setState(() {
      info = i;
      loading = false;
    });
  }

  Future<void> _pickZone() async {
    final g = info?.gov;
    if (g == null) return;
    final z = await showSheet<Zone>(context, (ctx) => _ZoneList(gov: g, now: info?.zone, picks: info?.picks ?? const []));
    if (z == null) return;
    await pickZone(c, z);
    await _load(fresh: true);
  }

  Future<void> _edit() async {
    if (me == null) {
      toast(context, '로그인하면 우리 단지 요일을 알려 주실 수 있어요');
      await openLogin(context);
      if (me == null) return;
    }
    if (!mounted) return;
    final ok = await showSheet<bool>(context, (ctx) => _EditDays(complex: c, info: info));
    if (ok == true) await _load(fresh: true);
  }

  @override
  Widget build(BuildContext context) => DetailPage(
        title: '쓰레기·분리수거',
        icon: 'trash',
        body: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: () => _load(fresh: true),
                child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 34), children: [TrashHero(c: widget.complex), const SizedBox(height: 16), ..._body(info!)]),
              ),
      );

  List<Widget> _body(TrashInfo i) {
    final z = i.zone;
    final g = i.gov;
    return [
      // ── 어디 기준인지
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g == null ? c.name : '${g.sido} ${g.gu}${i.dong.isNotEmpty ? ' · ${i.dong}' : ''}', style: T.tiny),
            const SizedBox(height: 3),
            MixTitle(c.name, '배출 안내', size: 17),
          ]),
        ),
        if ((g?.zones.length ?? 0) > 1) TextButton(onPressed: _pickZone, child: const Text('구역 바꾸기', style: TextStyle(fontSize: 12.5))),
      ]),
      const SizedBox(height: 10),
      if (z != null)
        Text('지자체 기준 구역: ${z.label}', style: T.small)
      else if (i.needPick)
        _notice('이 지역은 구역마다 배출 요일이 달라요. 단지가 속한 구역을 골라 주세요.', '구역 고르기', _pickZone)
      else if (g == null)
        _notice('이 지역 지자체 배출 정보가 아직 없어요. 관리사무소가 정한 요일을 알려 주시면 이웃 모두가 함께 봐요.', '요일 알려 주기', _edit),
      if (i.fromApt) ...[
        const SizedBox(height: 8),
        _aptNote(i.apt!),
      ],
      if (!i.empty) ...[
        const SizedBox(height: 16),
        _table(i),
      ],
      const SizedBox(height: 12),
      _aptButton(i),
      if (z != null) ...[
        _head('배출', '방법'),
        if (z.placeType.isNotEmpty || z.place.isNotEmpty) _line('pin', '배출 장소', [z.placeType, z.place].where((s) => s.isNotEmpty).join(' · ')),
        for (final k in kKinds)
          if ((z.method[k] ?? '').isNotEmpty) _line(k, kKindName[k]!, z.method[k]!),
        if (z.off.isNotEmpty) _line('off', '수거하지 않는 날', z.off.replaceAll('+', ', ')),
        _head('대형', '폐기물'),
        _line('b', '내는 방법', z.method['b']?.isNotEmpty == true ? z.method['b']! : '구청·주민센터나 지자체 신청 사이트에 신고하고 수수료를 낸 뒤 내요.'),
        if (z.bulkPlace.isNotEmpty) _line('pin', '내는 곳', z.bulkPlace),
        if (rangeText(z.hours['b'] ?? const []).isNotEmpty) _line('time', '내는 시간', rangeText(z.hours['b']!)),
        _line('s', '수수료', '품목과 크기마다 달라요. 신고할 때 안내받거나 담당 부서에 물어보세요. 냉장고·세탁기 같은 가전은 폐가전 무상 방문수거(1599-0903)로 무료예요.'),
        if (z.tel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Btn('${z.dept.isNotEmpty ? z.dept : '담당 부서'} ${z.tel}', icon: 'phone', onTap: () => callTel(z.tel)),
        ],
      ],
      _head('이건', '어떻게 버려요?'),
      const GuideBox(),
      const SizedBox(height: 22),
      Text(
        [
          if (z != null) '자료: 행정안전부 생활쓰레기배출정보 (${g?.gu ?? ''} 기준일 ${z.date})',
          '지자체 사정에 따라 실제와 다를 수 있어요. 아파트는 관리사무소 안내를 먼저 따라 주세요.',
        ].join('\n'),
        style: T.tiny,
      ),
    ];
  }

  Widget _notice(String text, String btn, VoidCallback onTap) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: cardBox(),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.4))),
          const SizedBox(width: 8),
          TextButton(onPressed: onTap, child: Text(btn, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _aptNote(AptDays a) {
    final at = a.at;
    final who = [if (a.by.isNotEmpty) a.by, if (at != null) '${at.month}월 ${at.day}일'].join(' · ');
    return Text(
      '우리 단지 주민이 알려 준 요일이에요${who.isEmpty ? '' : ' ($who)'}${a.note.isNotEmpty ? '\n${a.note}' : ''}',
      style: const TextStyle(fontSize: 12, color: kSub, height: 1.4),
    );
  }

  // 이번 주 배출표: 종류 × 요일
  Widget _table(TrashInfo i) {
    final today = dayChar(DateTime.now());
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 92),
          for (final d in _week.split(''))
            Expanded(
              child: Text(d,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, fontWeight: d == today ? FontWeight.w800 : FontWeight.w500, color: d == today ? kBlue : kSub)),
            ),
        ]),
        const SizedBox(height: 4),
        for (final k in kKinds) ...[
          const Divider(height: 1, color: kLine),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(
                width: 92,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kKindName[k]!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  if (rangeText(i.hoursOf(k)).isNotEmpty) Text(rangeText(i.hoursOf(k)), style: const TextStyle(fontSize: 10, color: kSub)),
                ]),
              ),
              for (final d in _week.split(''))
                Expanded(
                  child: Center(
                    child: i.daysOf(k).contains(d)
                        ? TrashIcon(k, size: 18, line: d == today ? kBlue : kInk, fill: d == today ? kSoft : const Color(0xFFF1F3F6))
                        : const Text('·', style: TextStyle(color: kLine, fontSize: 14)),
                  ),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _aptButton(TrashInfo i) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _edit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            const TrashIcon('edit', size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                i.fromApt ? '우리 단지 요일이 바뀌었나요? 고쳐 주세요' : '관리사무소가 정한 요일이 다른가요? 우리 단지 요일 알려 주기',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: kMute),
          ]),
        ),
      );

  Widget _head(String b, String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 26, 0, 8), child: MixTitle(b, t, size: 15));

  Widget _line(String icon, String title, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TrashIcon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
            ]),
          ),
        ]),
      );
}

// ---------------- 구역 고르기 ----------------
class _ZoneList extends StatelessWidget {
  final Gov gov;
  final Zone? now;
  final List<String> picks;
  const _ZoneList({required this.gov, this.now, this.picks = const []});

  @override
  Widget build(BuildContext context) {
    final zs = [...gov.zones]..sort((a, b) => (picks.contains(b.id) ? 1 : 0).compareTo(picks.contains(a.id) ? 1 : 0));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 4),
        child: MixTitle(gov.gu, '배출 구역 고르기', size: 16),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(kPad, 0, kPad, 8), child: Text('단지가 있는 동이 적힌 구역을 골라 주세요.', style: T.small)),
      Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 16),
          itemCount: zs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: kLine),
          itemBuilder: (ctx, i) {
            final z = zs[i];
            final on = z.id == now?.id;
            return InkWell(
              onTap: () => Navigator.pop(ctx, z),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(z.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? kBlue : kInk))),
                        if (picks.contains(z.id)) ...[const SizedBox(width: 6), const Pill('우리 단지 쪽')],
                      ]),
                      if (z.name.isNotEmpty && z.name != z.label && z.name != gov.gu) Text(z.name, style: T.small),
                      const SizedBox(height: 2),
                      Text('일반 ${daysText(z.days['g'] ?? '')} · 음식물 ${daysText(z.days['f'] ?? '')} · 재활용 ${daysText(z.days['r'] ?? '')}', style: T.tiny),
                    ]),
                  ),
                  if (on) const Icon(Icons.check, size: 18, color: kBlue),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------- 우리 단지 요일 알려 주기 ----------------
class _EditDays extends StatefulWidget {
  final Complex complex;
  final TrashInfo? info;
  const _EditDays({required this.complex, this.info});
  @override
  State<_EditDays> createState() => _EditDaysState();
}

class _EditDaysState extends State<_EditDays> {
  late final Map<String, Set<String>> on;
  String s = '', e = '';
  final note = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    final i = widget.info;
    on = {for (final k in kKinds) k: (i?.daysOf(k) ?? '').split('').where((x) => x.isNotEmpty).toSet()};
    final a = i?.apt;
    s = a?.start ?? '';
    e = a?.end ?? '';
    note.text = a?.note ?? '';
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (on.values.every((v) => v.isEmpty)) {
      toast(context, '배출 요일을 하나 넘게 골라 주세요');
      return;
    }
    setState(() => sending = true);
    String ds(Set<String> v) => kDays.split('').where(v.contains).join();
    final ok = await saveAptDays(
      widget.complex,
      AptDays(days: {for (final k in kKinds) k: ds(on[k]!)}, start: s, end: e, note: note.text.trim()),
    );
    if (!mounted) return;
    setState(() => sending = false);
    if (ok) {
      toast(context, '고마워요. 이웃 모두에게 보여요');
      Navigator.pop(context, true);
    } else {
      toast(context, '지금은 저장하지 못했어요. 잠시 뒤 다시 해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = [for (var h = 0; h < 24; h++) '${h.toString().padLeft(2, '0')}:00'];
    Widget pick(String v, String hint, ValueChanged<String> f) => Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: v.isEmpty ? null : v,
            isDense: true,
            decoration: inputDeco(hint),
            style: const TextStyle(fontSize: 13.5, color: kInk, fontFamily: 'Pretendard'),
            items: [for (final h in hours) DropdownMenuItem(value: h, child: Text(timeWord(h)))],
            onChanged: (x) => setState(() => f(x ?? '')),
          ),
        );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(kPad, 14, kPad, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MixTitle(widget.complex.name, '배출 요일', size: 16),
        const SizedBox(height: 4),
        const Text('관리사무소가 정한 요일을 넣어 주세요. 같은 단지 이웃 모두에게 보여요.', style: T.small),
        const SizedBox(height: 14),
        for (final k in kKinds) ...[
          Row(children: [
            TrashIcon(k, size: 18),
            const SizedBox(width: 6),
            Text(kKindName[k]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final d in _week.split('')) ...[
                ChoiceChipBox(d, on: on[k]!.contains(d), onTap: () => setState(() => on[k]!.contains(d) ? on[k]!.remove(d) : on[k]!.add(d))),
                const SizedBox(width: 5),
              ],
            ]),
          ),
          const SizedBox(height: 12),
        ],
        const Text('내는 시간 (모르면 비워 두세요)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          pick(s, '부터', (x) => s = x),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
          pick(e, '까지', (x) => e = x),
        ]),
        const SizedBox(height: 14),
        Field('알려 줄 말', note, hint: '예: 재활용은 지하 1층 분리수거장', max: 80),
        Btn(sending ? '저장하는 중…' : '저장하기', primary: true, onTap: sending ? null : _save),
        const SizedBox(height: 8),
        Text('${myName.isEmpty ? '' : '$myName 님 이름으로 '}저장돼요. 틀린 요일은 다른 이웃이 고칠 수 있어요.', style: T.tiny),
      ]),
    );
  }
}
