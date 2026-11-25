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
  String get version => '0.2.0';
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
        final on = await mealAlarmOn(s.id); // 급식 알림을 켠 학교는 아침에 맨 위로
        return Brief(icon: 'school', kicker: '오늘 급식 · ${s.name}', bold: m.dishes.first, rest: m.dishes.length > 1 ? ' · ${m.dishes.skip(1).take(2).join(' · ')}' : '', sub: m.cal, score: on ? 85 : 35);
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

  var q = '';
  var searching = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        // 대표님 사진(11-25): 위쪽 학교 사진, 아래로 갈수록 바탕색에 녹아듦
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + 250,
          child: ClipRect(child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.55, 1]).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/art/school_bg.jpg', fit: BoxFit.cover, alignment: const Alignment(0.2, -0.6), filterQuality: FilterQuality.medium),
          )),
        ),
        // 글자 쪽(왼쪽)만 옅게 밝혀 읽기 쉽게
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + 150,
          child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xE6FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)], stops: [0, 0.45, 0.8]))),
        ),
        FutureBuilder<List<School>>(
          future: near,
          builder: (context, snap) {
            final all = snap.data ?? const <School>[];
            final mine = [for (final id in mySchools.value) ...all.where((s) => s.id == id)];
            final others = all.where((s) => !mine.contains(s) && (q.isEmpty || s.name.contains(q))).toList();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(padding: EdgeInsets.fromLTRB(kPad, top + 6, kPad, 32), children: [
                  Row(children: [
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 26, color: kInk)),
                    const SizedBox(width: 2),
                    const Text('학교 급식', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk)),
                  ]),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 2, 0, 0),
                    child: Text('학교가 나이스에 미리 올린 식단·일정이에요.\n학교 사정으로 바뀔 수 있어요.', style: TextStyle(fontSize: 12.5, color: Color(0xFF3F4756), height: 1.4)),
                  ),
                  const SizedBox(height: 70),
                  if (snap.connectionState != ConnectionState.done)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: kBlue, strokeWidth: 2)))
                  else ...[
                    for (final s in mine) ...[_Mine(s: s, now: now, onRemove: () => _toggle(s)), const SizedBox(height: 14)],
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(width: 3, height: 18, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 9),
                      Expanded(child: MixTitle(mine.isEmpty ? '우리 아이 학교를' : '다른 학교', mine.isEmpty ? '골라 주세요' : '더 고르기', size: 16)),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          searching = !searching;
                          if (!searching) q = '';
                        }),
                        icon: Icon(searching ? Icons.close_rounded : Icons.search_rounded, size: 17),
                        label: Text(searching ? '닫기' : '학교 검색'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBlue,
                          side: const BorderSide(color: Color(0xFFBFD3FB)),
                          shape: const StadiumBorder(),
                          backgroundColor: Colors.white,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                    if (searching) ...[
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => q = v.trim()),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '학교 이름 (단지 3km 안)',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: kSub),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBlue)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (all.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('단지 3km 안 학교 자료를 모으고 있어요', style: T.small, textAlign: TextAlign.center)),
                    if (all.isNotEmpty && others.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('찾는 학교가 없어요', style: T.small, textAlign: TextAlign.center)),
                    for (final kind in ['초', '중', '고'])
                      if (others.any((s) => s.kind == kind)) ...[
                        _KindBox(
                          title: const {'초': '초등학교', '중': '중학교', '고': '고등학교'}[kind]!,
                          children: [
                            for (final (i, s) in others.where((s) => s.kind == kind).indexed) ...[
                              if (i > 0) const Divider(height: 1, color: kLine, indent: 16, endIndent: 16),
                              InkWell(
                                onTap: () => _toggle(s),
                                child: SizedBox(
                                  height: 54,
                                  child: Row(children: [
                                    const SizedBox(width: 14),
                                    const LineIcon('school', size: 26),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
                                    Text(distText(meters(widget.c.pos, s.pos)), style: const TextStyle(fontSize: 12, color: kSub)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.add_circle_outline_rounded, color: kBlue, size: 24),
                                    const SizedBox(width: 14),
                                  ]),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}

// 초·중·고 묶음: 옅은 파랑 머리 띠 + 흰 목록
class _KindBox extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _KindBox({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: const Color(0xFFEDF2FA),
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
            child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF4A5468))),
          ),
          ...children,
        ]),
      );
}

// 우리 아이 학교: 이름 · 급식 알림 · 별(빼기) / 다가오는 쉬는 날·행사 알약 / 날짜별 급식 줄 (대표님 시안 11-25)
class _Mine extends StatefulWidget {
  final School s;
  final DateTime now;
  final VoidCallback onRemove;
  const _Mine({required this.s, required this.now, required this.onRemove});
  @override
  State<_Mine> createState() => _MineState();
}

class _MineState extends State<_Mine> {
  var alarm = false;

  @override
  void initState() {
    super.initState();
    mealAlarmOn(widget.s.id).then((v) {
      if (mounted) setState(() => alarm = v);
    });
  }

  Future<void> _alarm(BuildContext context) async {
    final on = !alarm;
    await setMealAlarm(widget.s.id, on);
    if (!mounted) return;
    setState(() => alarm = on);
    toast(this.context, on ? '아침마다 「지금 우리 단지」에 오늘 급식을 먼저 보여 드려요' : '급식 알림을 껐어요');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s, now = widget.now;
    final ev = s.eventsWithin(now, 30);
    final days = <(DateTime, Meal)>[];
    for (var i = 0; i < 10 && days.length < 5; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final m = s.meals[ymd(d)];
      if (m != null) days.add((d, m));
    }
    return Container(
      decoration: cardBox(r: 18),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const SizedBox(width: 4),
          const LineIcon('school', size: 32),
          const SizedBox(width: 10),
          Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
          // 좁은 폰: 학교 이름이 잘리지 않게 종 아이콘만
          if (MediaQuery.of(context).size.width < 400)
            IconButton(
              tooltip: '급식 알림',
              visualDensity: VisualDensity.compact,
              onPressed: () => _alarm(context),
              icon: Icon(alarm ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 23, color: kBlue),
            )
          else
          OutlinedButton.icon(
            onPressed: () async {
              final on = !alarm;
              await setMealAlarm(s.id, on);
              if (!mounted) return;
              setState(() => alarm = on);
              toast(context, on ? '아침마다 「지금 우리 단지」에 오늘 급식을 먼저 보여 드려요' : '급식 알림을 껐어요');
            },
            icon: Icon(alarm ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 17),
            label: const Text('급식 알림'),
            style: OutlinedButton.styleFrom(
              foregroundColor: alarm ? Colors.white : kBlue,
              backgroundColor: alarm ? kBlue : Colors.white,
              side: BorderSide(color: alarm ? kBlue : const Color(0xFFBFD3FB)),
              shape: const StadiumBorder(),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.fromLTRB(11, 0, 14, 0),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '우리 아이 학교에서 빼기',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onRemove,
            icon: const Icon(Icons.star_rounded, size: 26, color: Color(0xFFFFB020)),
          ),
        ]),
        if (ev.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (d, n) in ev.take(4))
              Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 13, 5),
                decoration: BoxDecoration(color: isOff(n) ? const Color(0x14E5484D) : const Color(0xFFEAF1FD), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_month_rounded, size: 14, color: isOff(n) ? const Color(0xFFD13B40) : kBlue),
                  const SizedBox(width: 5),
                  Text('${_dayLabel(d, now)} $n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isOff(n) ? const Color(0xFFD13B40) : kBlue)),
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        if (days.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(4, 6, 4, 12), child: Text('앞으로 열흘 안 급식 정보가 없어요', style: T.small)),
        for (final (i, (d, m)) in days.indexed) ...[
          if (i > 0 && ymd(days[i - 1].$1) != ymd(now)) const Divider(height: 1, color: kLine, indent: 6, endIndent: 6),
          _MealRow(label: _dayLabel(d, now), today: ymd(d) == ymd(now), m: m),
        ],
      ]),
    );
  }
}

class _MealRow extends StatelessWidget {
  final String label;
  final bool today;
  final Meal m;
  const _MealRow({required this.label, required this.today, required this.m});
  @override
  Widget build(BuildContext context) {
    final near = label == '오늘' || label == '내일';
    return Container(
      margin: EdgeInsets.symmetric(vertical: today ? 4 : 0),
      padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
      decoration: today ? BoxDecoration(color: const Color(0xFFEFF4FE), borderRadius: BorderRadius.circular(14)) : null,
      child: Row(children: [
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: today ? kBlue : const Color(0xFFE6EEFB), borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: TextStyle(fontSize: near ? 13 : 12, fontWeight: FontWeight.w800, color: today ? Colors.white : const Color(0xFF1F3B6B), letterSpacing: -0.3)),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.restaurant_rounded, size: 18, color: kBlue),
        const SizedBox(width: 9),
        // 반찬 이름 가운데서 줄이 갈리지 않게 (대표님 규칙) — 글자 사이를 붙이고 「 · 」에서만 줄바꿈
        Expanded(child: Text(m.dishes.map((d) => d.split('').join('\u2060')).join('\u00A0· '), style: const TextStyle(fontSize: 13, height: 1.4, color: kInk, letterSpacing: -0.2))),
      ]),
    );
  }
}
