// 기념일 (기념일 담당: 본부, 대표님 요청 11-24)
// 생일·결혼기념일·제사 등 양력/음력 등록 → 당일·하루 전·사흘 전·일주일 전 아침 9시 알림
// 단지 홈 한 줄 카드: 「다가오는 기념일 D-3」 · 상세: 목록(다가오는 순) · 등록·고치기·지우기
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/notify.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

class AnnivFeature extends Feature {
  @override
  String get id => 'anniv';
  @override
  String get name => '기념일';
  @override
  String get icon => 'anniv';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 60;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  int get mainOrder => 3;

  @override
  Widget? mainCard(BuildContext context, Complex c) => _Upcoming(f: this);

  @override
  Widget page(BuildContext context, Complex c) => const AnnivPage();

  // 「지금 우리 단지」 맨 위 카드: 일주일 안 기념일 (가까울수록 위로)
  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    await loadAnnivs();
    final up = upcoming(now);
    if (up.isEmpty) return null;
    final (a, d) = up.first;
    final n = dday(d, now);
    if (n > 7) return null;
    return Brief(
      icon: 'anniv',
      kicker: '다가오는 기념일',
      bold: n == 0 ? '오늘은 ' : (n == 1 ? '내일은 ' : '$n일 뒤 '),
      hot: a.title,
      sub: '${d.month}월 ${d.day}일${a.lunar ? ' · 음력 ${a.month}월 ${a.day}일' : ''}',
      score: n <= 1 ? 85 : (n <= 3 ? 65 : 40),
    );
  }
}

class _Upcoming extends StatefulWidget {
  final Feature f;
  const _Upcoming({required this.f});
  @override
  State<_Upcoming> createState() => _UpcomingState();
}

class _UpcomingState extends State<_Upcoming> {
  @override
  void initState() {
    super.initState();
    loadAnnivs().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Anniv>>(
        valueListenable: annivs,
        builder: (_, __, ___) {
          final now = DateTime.now();
          final up = upcoming(now);
          if (up.isEmpty) {
            return MainRowCard(
              icon: 'anniv',
              bold: '기념일',
              thin: '챙기기',
              sub: '생일·제사 등록하면 미리 알려 드려요',
              subLines: 1,
              trailing: SizedBox(width: 72, child: Btn('등록', primary: true, h: 38, onTap: () => openFeature(context, widget.f))),
              onTap: () => openFeature(context, widget.f),
            );
          }
          final (a, d) = up.first;
          final n = dday(d, now);
          return MainRowCard(
            icon: 'anniv',
            bold: '다가오는',
            thin: '기념일',
            sub: '${a.title} · ${d.month}월 ${d.day}일${a.lunar ? ' (음력 ${a.month}.${a.day})' : ''}',
            subLines: 1,
            trailing: MainValue(ddayText(n), up.length > 1 ? '외 ${up.length - 1}개' : ''),
            onTap: () => openFeature(context, widget.f),
          );
        },
      );
}

class AnnivPage extends StatefulWidget {
  const AnnivPage({super.key});
  @override
  State<AnnivPage> createState() => _AnnivPageState();
}

class _AnnivPageState extends State<AnnivPage> {
  @override
  void initState() {
    super.initState();
    loadAnnivs().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _edit([Anniv? a]) async {
    final r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _Form(a: a),
    );
    if (r == null) return;
    final l = [...annivs.value];
    if (r == 'del' && a != null) {
      l.removeWhere((x) => x.id == a.id);
    } else if (r is Anniv) {
      final i = l.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        l[i] = r;
      } else {
        l.add(r);
      }
      if (canNotify && r.remind.isNotEmpty) await askNotePermission();
    }
    await saveAnnivs(l);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final up = upcoming(now);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('기념일', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('기념일 등록', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: up.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    LineIcon('anniv', size: 56),
                    SizedBox(height: 12),
                    MixTitle('챙길 날을', '등록해 보세요', size: 17),
                    SizedBox(height: 6),
                    Text('음력도 해마다 양력 날짜로 바꿔서 알려 드려요', style: T.small),
                  ]),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 96), children: [
                  if (!canNotify) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('알림은 휴대폰 앱에서만 울려요', style: T.small)),
                  for (var i = 0; i < up.length; i++) ...[
                    _Item(a: up[i].$1, d: up[i].$2, now: now, first: i == 0, onTap: () => _edit(up[i].$1)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  const Text('알림은 이 휴대폰에만 저장돼요. 휴대폰을 바꾸면 다시 등록해 주세요.', style: T.tiny),
                ]),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final Anniv a;
  final DateTime d, now;
  final bool first;
  final VoidCallback onTap;
  const _Item({required this.a, required this.d, required this.now, required this.first, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final n = dday(d, now);
    final nth = a.nth(d);
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(7)),
              child: Text(a.kind, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSub)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${a.title}${nth != null && nth > 0 ? ' · ${a.kind == '생일' ? '$nth번째' : '$nth주년'}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text('${d.year}.${d.month}.${d.day} (${wd[d.weekday - 1]})${a.lunar ? ' · 음력 ${a.month}월 ${a.day}일' : ''}', style: T.tiny),
              ]),
            ),
            Text(ddayText(n), style: TextStyle(fontSize: first ? 19 : 16, fontWeight: FontWeight.w800, color: first ? kBlue : kInk, letterSpacing: -0.4)),
          ]),
        ),
      ),
    );
  }
}

// 등록·고치기 시트
class _Form extends StatefulWidget {
  final Anniv? a;
  const _Form({this.a});
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final title = TextEditingController(text: widget.a?.title ?? '');
  late final year = TextEditingController(text: widget.a?.year?.toString() ?? '');
  late String kind = widget.a?.kind ?? '생일';
  late bool lunar = widget.a?.lunar ?? false;
  late int month = widget.a?.month ?? DateTime.now().month;
  late int day = widget.a?.day ?? DateTime.now().day;
  late Set<int> remind = {...(widget.a?.remind ?? const [0, 1])};

  @override
  Widget build(BuildContext context) {
    final maxDay = lunar ? 30 : DateTime(2024, month + 1, 0).day;
    if (day > maxDay) day = maxDay;
    final preview = (lunar ? lunarToSolar(DateTime.now().year, month, day) : null);
    return Padding(
      padding: EdgeInsets.fromLTRB(kPad, 18, kPad, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          MixTitle(widget.a == null ? '기념일' : '기념일', widget.a == null ? '등록' : '고치기', size: 17),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in ['생일', '결혼기념일', '제사', '기념일', '기타']) ChoiceChipBox(k, on: kind == k, onTap: () => setState(() => kind = k)),
          ]),
          const SizedBox(height: 12),
          Field('이름', title, hint: kind == '생일' ? '예: 엄마 생신' : (kind == '제사' ? '예: 할아버지 제사' : '예: 결혼기념일'), max: 20),
          Row(children: [
            ChoiceChipBox('양력', on: !lunar, onTap: () => setState(() => lunar = false)),
            const SizedBox(width: 6),
            ChoiceChipBox('음력', on: lunar, onTap: () => setState(() => lunar = true)),
            const SizedBox(width: 12),
            Expanded(
              child: Row(children: [
                _Drop(value: month, max: 12, unit: '월', onChanged: (v) => setState(() => month = v)),
                const SizedBox(width: 8),
                _Drop(value: day, max: maxDay, unit: '일', onChanged: (v) => setState(() => day = v)),
              ]),
            ),
          ]),
          if (lunar) ...[
            const SizedBox(height: 6),
            Text(preview == null ? '올해 양력 날짜를 계산할 수 없어요' : '올해는 양력 ${preview.month}월 ${preview.day}일이에요', style: T.tiny),
          ],
          const SizedBox(height: 12),
          Field('처음 해 (선택 · 몇 번째인지 세어 드려요)', year, hint: '예: 1960', max: 4, type: TextInputType.number),
          const Text('알림 (아침 9시)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (v, t) in [(0, '당일'), (1, '하루 전'), (3, '사흘 전'), (7, '일주일 전')])
              ChoiceChipBox(t, on: remind.contains(v), onTap: () => setState(() => remind.contains(v) ? remind.remove(v) : remind.add(v))),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            if (widget.a != null) ...[
              SizedBox(width: 90, child: Btn('지우기', onTap: () => Navigator.pop(context, 'del'))),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Btn('저장', primary: true, onTap: () {
                final t = title.text.trim();
                if (t.isEmpty) return toast(context, '이름을 적어 주세요');
                Navigator.pop(
                  context,
                  Anniv(
                    id: widget.a?.id ?? DateTime.now().millisecondsSinceEpoch % 1000000000,
                    title: t,
                    kind: kind,
                    month: month,
                    day: day,
                    lunar: lunar,
                    year: int.tryParse(year.text.trim()),
                    remind: (remind.toList()..sort()),
                  ),
                );
              }),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Drop extends StatelessWidget {
  final int value, max;
  final String unit;
  final ValueChanged<int> onChanged;
  const _Drop({required this.value, required this.max, required this.unit, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(10), color: Colors.white),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            menuMaxHeight: 320,
            items: [for (var i = 1; i <= max; i++) DropdownMenuItem(value: i, child: Text('$i$unit', style: const TextStyle(fontSize: 14)))],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}
