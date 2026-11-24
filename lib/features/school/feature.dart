// 학교 급식·학사일정 (학교 담당: 본부, 대표님 요청 11-24)
// 「우리 아이 학교」를 등록한 집만 홈에 한 줄 카드 (처음엔 꺼져 있음, 등록하면 저절로 켜짐)
// 「지금 우리 단지」 맨 위 카드: 오늘·내일 쉬는 날(재량휴업일 등), 오전엔 오늘 급식
// 상세: 우리 아이 학교 이번 주 급식 · 다가오는 쉬는 날·행사 / 주변 초·중·고 고르기
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/home_layout.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _wd = ['월', '화', '수', '목', '금', '토', '일'];
String _dayLabel(DateTime d, DateTime now) {
  final n = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (n == 0) return '오늘';
  if (n == 1) return '내일';
  return '${d.month}/${d.day}(${_wd[d.weekday - 1]})';
}

class SchoolFeature extends Feature {
  @override
  String get id => 'school';
  @override
  String get name => '학교 급식';
  @override
  String get icon => 'school';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 62;
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;
  @override
  int get mainOrder => 3;

  @override
  Widget? mainCard(BuildContext context, Complex c) => _Card(f: this, c: c);

  @override
  Widget page(BuildContext context, Complex c) => _Page(c: c);

  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    final mine = await mySchoolList(c);
    if (mine.isEmpty) return null;
    for (final s in mine) {
      for (final (d, ev) in s.eventsWithin(now, 1)) {
        if (!isOff(ev)) continue;
        final when = _dayLabel(d, now);
        return Brief(icon: 'school', kicker: '우리 아이 학교 · ${s.name}', bold: '$when ', hot: ev, sub: when == '내일' ? '아이 맡길 곳·도시락 미리 챙기세요' : '오늘은 학교에 안 가요', score: when == '내일' ? 80 : 70);
      }
    }
    if (now.weekday <= 5 && now.hour < 13) {
      final s = mine.first;
      final m = s.meals[ymd(now)];
      if (m != null && m.dishes.isNotEmpty) {
        return Brief(icon: 'school', kicker: '오늘 급식 · ${s.name}', bold: m.dishes.first, rest: m.dishes.length > 1 ? ' · ${m.dishes.skip(1).take(2).join(' · ')}' : '', sub: m.cal, score: 35);
      }
    }
    return null;
  }
}

class _Card extends StatefulWidget {
  final Feature f;
  final Complex c;
  const _Card({required this.f, required this.c});
  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  @override
  void initState() {
    super.initState();
    loadMySchools().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<String>>(
        valueListenable: mySchools,
        builder: (_, ids, __) {
          if (ids.isEmpty) {
            return MainRowCard(
              icon: 'school',
              bold: '우리 아이',
              thin: '학교 급식',
              sub: '학교를 등록하면 급식·쉬는 날을 알려 드려요',
              subLines: 1,
              trailing: SizedBox(width: 72, child: Btn('등록', primary: true, h: 38, onTap: () => openFeature(context, widget.f))),
              onTap: () => openFeature(context, widget.f),
            );
          }
          return FutureBuilder<List<School>>(
            future: mySchoolList(widget.c),
            builder: (_, snap) {
              final now = DateTime.now();
              final l = snap.data ?? const <School>[];
              final s = l.isEmpty ? null : l.first;
              final m = s?.mealOn(now);
              final off = s == null ? null : s.eventsWithin(now, 3).where((e) => isOff(e.$2)).firstOrNull;
              return MainRowCard(
                icon: 'school',
                bold: s?.name ?? '우리 아이 학교',
                thin: m == null ? '' : '${_dayLabel(m.$1, now)} 급식',
                sub: m == null ? '급식 정보가 아직 없어요' : m.$2.dishes.take(4).join(' · '),
                trailing: off != null ? MainValue(_dayLabel(off.$1, now), off.$2.length > 6 ? '${off.$2.substring(0, 6)}…' : off.$2) : const Icon(Icons.chevron_right_rounded, color: kSub),
                onTap: () => openFeature(context, widget.f),
              );
            },
          );
        },
      );
}

class _Page extends StatefulWidget {
  final Complex c;
  const _Page({required this.c});
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  late final Future<List<School>> near = nearSchools(widget.c);

  @override
  void initState() {
    super.initState();
    loadMySchools().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggle(School s) async {
    final ids = [...mySchools.value];
    if (ids.contains(s.id)) {
      ids.remove(s.id);
    } else {
      ids.add(s.id);
      await setHomeCardOn('m:school'); // 등록하면 홈에 학교 카드가 보이게
    }
    await setMySchools(ids);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('학교 급식', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: FutureBuilder<List<School>>(
        future: near,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: kBlue));
          final all = snap.data ?? const <School>[];
          final mine = [for (final id in mySchools.value) ...all.where((s) => s.id == id)];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 28), children: [
                const Text('학교가 나이스에 미리 올린 식단·일정이에요. 학교 사정으로 바뀔 수 있어요.', style: T.small),
                const SizedBox(height: 12),
                for (final s in mine) ...[_Mine(s: s, now: now, onRemove: () => _toggle(s)), const SizedBox(height: 12)],
                const SizedBox(height: 4),
                MixTitle(mine.isEmpty ? '우리 아이 학교를' : '다른 학교', mine.isEmpty ? '골라 주세요' : '더 고르기', size: 15),
                const SizedBox(height: 8),
                if (all.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('단지 3km 안 학교 자료를 모으고 있어요', style: T.small, textAlign: TextAlign.center)),
                for (final kind in ['초', '중', '고']) ...[
                  if (all.any((s) => s.kind == kind && !mine.contains(s))) ...[
                    Padding(padding: const EdgeInsets.only(left: 2, top: 6, bottom: 6), child: Text(const {'초': '초등학교', '중': '중학교', '고': '고등학교'}[kind]!, style: T.tiny)),
                    Container(
                      decoration: cardBox(),
                      child: Column(children: [
                        for (final (i, s) in all.where((s) => s.kind == kind && !mine.contains(s)).indexed) ...[
                          if (i > 0) const Divider(height: 1, color: kLine, indent: 14, endIndent: 14),
                          InkWell(
                            onTap: () => _toggle(s),
                            child: SizedBox(
                              height: 50,
                              child: Row(children: [
                                const SizedBox(width: 14),
                                Expanded(child: Text(s.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                                Text(distText(meters(widget.c.pos, s.pos)), style: T.tiny),
                                const SizedBox(width: 10),
                                const Icon(Icons.add_circle_outline_rounded, color: kBlue, size: 22),
                                const SizedBox(width: 12),
                              ]),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// 우리 아이 학교: 다가오는 쉬는 날 + 이번 주 급식
class _Mine extends StatelessWidget {
  final School s;
  final DateTime now;
  final VoidCallback onRemove;
  const _Mine({required this.s, required this.now, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final ev = s.eventsWithin(now, 30);
    final days = <(DateTime, Meal)>[];
    for (var i = 0; i < 10 && days.length < 5; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final m = s.meals[ymd(d)];
      if (m != null) days.add((d, m));
    }
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const LineIcon('school', size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
          TextButton(onPressed: onRemove, child: const Text('빼기', style: TextStyle(color: kSub, fontSize: 13))),
        ]),
        if (ev.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (d, n) in ev.take(6))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: isOff(n) ? const Color(0x14E5484D) : kBg, borderRadius: BorderRadius.circular(20)),
                child: Text('${_dayLabel(d, now)} $n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isOff(n) ? const Color(0xFFD13B40) : kSub)),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        if (days.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('앞으로 열흘 안 급식 정보가 없어요', style: T.small)),
        for (final (d, m) in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 64,
                child: Text(_dayLabel(d, now), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ymd(d) == ymd(now) ? kBlue : kInk)),
              ),
              Expanded(child: Text(m.dishes.join(' · '), style: const TextStyle(fontSize: 13.5, height: 1.4))),
            ]),
          ),
      ]),
    );
  }
}
