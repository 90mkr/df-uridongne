// 우리 동네 지원금·혜택 화면 (이 폴더는 지원금·혜택 방만 고침)
// 위: 우리 구 이름 + 혜택 수 · 「나에게 맞는 것만」 → 칸(우리 구 · 시·도 · 전국 · 청년) → 분야 칩 → 게시판처럼 제목 줄
// 줄을 누르면 아래에서 올라오는 창: 지원 대상 · 지원 내용 · 신청 방법·기한 · 문의 · 원문 바로가기
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

class BenefitPage extends StatefulWidget {
  final Complex c;
  const BenefitPage({super.key, required this.c});
  @override
  State<BenefitPage> createState() => _BenefitPageState();
}

class _BenefitPageState extends State<BenefitPage> {
  BenefitSet? set;
  Me me = const Me('', {});
  bool onlyMe = true;
  String tab = 'gu';
  String field = '';
  String q = '';
  int more = 40;
  final qc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    qc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await loadMe();
    final s = await loadBenefits(widget.c);
    if (!mounted) return;
    setState(() {
      me = m;
      set = s;
      if (s.gu.isEmpty && s.sido.isNotEmpty) tab = 'sido';
      if (s.gu.isEmpty && s.sido.isEmpty) tab = 'nat';
    });
  }

  List<Benefit> _of(String t) => switch (t) { 'gu' => set!.gu, 'sido' => set!.sido, 'nat' => set!.nat, _ => set!.youth };

  Me get _me => onlyMe ? me : const Me('', {});

  List<Benefit> get shown {
    var l = filterFor(_of(tab), _me, field);
    if (q.isNotEmpty) {
      final k = q.replaceAll(' ', '');
      l = l.where((b) => '${b.title}${b.sum}${b.org}'.replaceAll(' ', '').contains(k)).toList();
    }
    return l;
  }

  int _count(String t) => filterFor(_of(t), _me, '').length;

  @override
  Widget build(BuildContext context) {
    final gu = guName(widget.c);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('우리 동네 지원금·혜택', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: set == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : set!.empty
                  ? _emptyAll()
                  : _body(gu),
        ),
      ),
    );
  }

  Widget _emptyAll() => const Padding(
        padding: EdgeInsets.all(kPad),
        child: Center(
          child: Text('혜택 자료를 준비하고 있어요.\n정부24 혜택 정보를 매일 받아 우리 구 혜택을 모아 드릴게요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: kSub, height: 1.5)),
        ),
      );

  Widget _body(String gu) {
    final l = shown;
    final sido = sidoName(widget.c);
    final tabs = [
      ('gu', gu),
      ('sido', sido.isEmpty ? '시·도' : sido),
      ('nat', '전국'),
      ('youth', '청년정책'),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 34), children: [
      // ── 머리: 우리 구 혜택 수
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$sido $gu에서 받을 수 있는', style: T.small),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              const TextSpan(text: '혜택 ', style: TextStyle(fontWeight: FontWeight.w300)),
              TextSpan(text: '${_count('gu') + _count('sido') + _count('nat')}', style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
              const TextSpan(text: '가지', style: TextStyle(fontWeight: FontWeight.w800)),
            ]), style: const TextStyle(fontSize: 22, letterSpacing: -0.6, height: 1.2)),
          ]),
        ),
        const LineIcon('public', size: 44),
      ]),
      const SizedBox(height: 14),
      _meBar(),
      const SizedBox(height: 14),
      // ── 칸
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final t in tabs) ...[
            _Tab(label: t.$2, n: _count(t.$1), on: tab == t.$1, onTap: () => setState(() {
                  tab = t.$1;
                  field = '';
                  more = 40;
                })),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      // ── 분야 칩 + 찾기
      if (tab != 'youth' || set!.youth.isNotEmpty) _fieldRow(),
      const SizedBox(height: 10),
      // ── 목록 (게시판처럼 제목 줄)
      if (tab == 'youth' && set!.youth.isEmpty)
        _note('청년정책은 온통청년 자료를 연결하는 중이에요.\n연결되면 월세·면접수당·자산형성처럼 몰라서 못 받는 청년 혜택이 여기에 모여요.')
      else if (l.isEmpty)
        _note(q.isNotEmpty ? '「$q」 혜택을 찾지 못했어요.' : '고른 조건에 맞는 혜택이 이 칸에는 없어요.\n다른 칸이나 「나에게 맞는 것만」을 꺼서 보세요.')
      else
        Container(
          decoration: cardBox(),
          child: Column(children: [
            for (var i = 0; i < l.length && i < more; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: kLine, indent: 14, endIndent: 14),
              _Row(b: l[i], onTap: () => openBenefit(context, l[i])),
            ],
          ]),
        ),
      if (l.length > more) ...[
        const SizedBox(height: 10),
        Btn('더 보기 (${l.length - more}개 더)', h: 42, onTap: () => setState(() => more += 60)),
      ],
      const SizedBox(height: 16),
      Text(
          '본인인증 없이 직접 고른 조건으로 「해당될 수 있는 혜택」을 보여 드려요. 정부24처럼 딱 집어 드리지는 못하니, 받을 수 있는지는 원문에서 꼭 확인하세요.'
          '${set!.updated.isNotEmpty ? ' · ${set!.updated.substring(5, 10).replaceAll('-', '.')} 받은 자료' : ''}',
          style: T.tiny),
      const SizedBox(height: 4),
      const Text('자료: 행정안전부 대한민국 공공서비스(혜택) 정보 · 온통청년(한국고용정보원)', style: T.tiny),
    ]);
  }

  Widget _note(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: cardBox(),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.5)),
      );

  // 「나에게 맞는 것만」 줄
  Widget _meBar() {
    if (!me.isSet) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: _pickMe,
          child: Ink(
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              const LineIcon('me', size: 30),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MixTitle('나에게 맞는', '혜택만 보기', size: 14),
                  SizedBox(height: 2),
                  Text('나이대·자녀·어르신을 고르면 해당될 수 있는 것만 추려 드려요', style: T.tiny),
                ]),
              ),
              Text('고르기 ›', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kBlue.withValues(alpha: 0.95))),
            ]),
          ),
        ),
      );
    }
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('나에게 맞는 것만', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(me.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
          ]),
        ),
        TextButton(onPressed: _pickMe, child: const Text('바꾸기', style: TextStyle(fontSize: 12, color: kSub))),
        Switch(
          value: onlyMe,
          activeTrackColor: kBlue,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) => setState(() {
            onlyMe = v;
            more = 40;
          }),
        ),
      ]),
    );
  }

  Widget _fieldRow() {
    final fs = fieldsOf(_of(tab));
    return SizedBox(
      height: 34,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        _SearchChip(
          ctl: qc,
          onChanged: (v) => setState(() {
            q = v.trim();
            more = 40;
          }),
        ),
        const SizedBox(width: 6),
        for (final f in ['', ...fs]) ...[
          _Chip(f.isEmpty ? '전체' : f, on: field == f, onTap: () => setState(() {
                field = f;
                more = 40;
              })),
          const SizedBox(width: 6),
        ],
      ]),
    );
  }

  Future<void> _pickMe() async {
    final m = await showSheet<Me>(context, (ctx) => _MeSheet(me: me));
    if (m == null || !mounted) return;
    await saveMe(m);
    setState(() {
      me = m;
      onlyMe = true;
      more = 40;
      if (m.age == '청년' && set!.gu.isEmpty && set!.youth.isNotEmpty) tab = 'youth';
    });
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int n;
  final bool on;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.n, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 6, 14, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: label, style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? kInk : kSub)),
              TextSpan(text: ' $n', style: TextStyle(fontWeight: FontWeight.w600, color: on ? kBlue : kMute, fontSize: 12)),
            ]), style: const TextStyle(fontSize: 14.5, letterSpacing: -0.3)),
            const SizedBox(height: 5),
            Container(height: 2, width: 22, color: on ? kInk : Colors.transparent),
          ]),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final bool on;
  final VoidCallback onTap;
  const _Chip(this.text, {required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? kInk : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: on ? kInk : kLine),
          ),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : kInk)),
        ),
      );
}

class _SearchChip extends StatelessWidget {
  final TextEditingController ctl;
  final ValueChanged<String> onChanged;
  const _SearchChip({required this.ctl, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        width: 118,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: kLine)),
        child: Row(children: [
          const Icon(Icons.search, size: 16, color: kMute),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: ctl,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '혜택 찾기', hintStyle: TextStyle(fontSize: 12, color: kMute)),
            ),
          ),
        ]),
      );
}

// 게시판처럼 한 줄 (사진 없음)
class _Row extends StatelessWidget {
  final Benefit b;
  final VoidCallback onTap;
  const _Row({required this.b, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dd = b.dday;
    final sub = [
      if (b.org.isNotEmpty) b.org,
      if (b.kind.isNotEmpty) b.kind,
      if (b.deadline.isNotEmpty && dd == null) b.deadline,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.3)),
                ),
                if (b.isNew) ...[
                  const SizedBox(width: 5),
                  const Text('N', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBlue)),
                ],
              ]),
              const SizedBox(height: 3),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ]),
          ),
          if (dd != null) ...[
            const SizedBox(width: 8),
            Pill(dd <= 0 ? '오늘 마감' : 'D-$dd',
                color: dd <= 7 ? kBlue : kSub, bg: dd <= 7 ? const Color(0xFFEEF3FF) : const Color(0xFFF1F3F6)),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: kMute),
        ]),
      ),
    );
  }
}

// ── 「나에게 맞는 것만」 고르기 창
class _MeSheet extends StatefulWidget {
  final Me me;
  const _MeSheet({required this.me});
  @override
  State<_MeSheet> createState() => _MeSheetState();
}

class _MeSheetState extends State<_MeSheet> {
  late String age = widget.me.age;
  late final Set<String> picks = {...widget.me.picks};

  Widget _group(String title, List<String> keys, {bool single = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in keys)
            ChoiceChipBox(kTagName[k]!, on: single ? age == k : picks.contains(k), onTap: () => setState(() {
                  if (single) {
                    age = age == k ? '' : k;
                  } else if (!picks.remove(k)) {
                    picks.add(k);
                  }
                })),
        ]),
        const SizedBox(height: 18),
      ]);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const MixTitle('나에게 맞는', '혜택만 보기', size: 16),
          const SizedBox(height: 4),
          const Text('해당하는 것만 고르세요. 이 휴대폰에만 저장되고 다른 곳에 보내지 않아요.', style: T.small),
          const SizedBox(height: 18),
          _group('나이대 (하나만)', kAges, single: true),
          _group('우리 집 (여럿 고를 수 있어요)', kFamily),
          _group('그 밖에', kEtc),
          Row(children: [
            Expanded(child: Btn('모두 지우기', h: 44, onTap: () => Navigator.pop(context, const Me('', {})))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: Btn('이 조건으로 보기', h: 44, primary: true, onTap: () => Navigator.pop(context, Me(age, picks)))),
          ]),
        ]),
      );
}

// ── 혜택 자세히 (아래에서 올라오는 창)
void openBenefit(BuildContext context, Benefit b) {
  showSheet(context, (ctx) => _Detail(b: b));
}

class _Detail extends StatelessWidget {
  final Benefit b;
  const _Detail({required this.b});

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: loadDetail(b),
        builder: (ctx, snap) {
          final d = snap.data ?? const {};
          final wait = snap.connectionState != ConnectionState.done;
          final url = '${d['url'] ?? ''}';
          final tel = RegExp(r'0\d{1,2}-?\d{3,4}-?\d{4}|1\d{3}-?\d{4}').firstMatch('${d['문의'] ?? ''}')?.group(0) ?? '';
          String v(String k) => '${d[k] ?? ''}'.trim();
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    if (b.field.isNotEmpty) Pill(b.field),
                    if (b.kind.isNotEmpty) Pill(b.kind),
                    if (b.dday != null) Pill(b.dday! <= 0 ? '오늘 마감' : '마감 D-${b.dday}', color: kBlue, bg: const Color(0xFFEEF3FF)),
                  ]),
                  const SizedBox(height: 10),
                  Text(b.title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.3)),
                  if (b.org.isNotEmpty) ...[const SizedBox(height: 4), Text([b.org, v('부서')].where((x) => x.isNotEmpty).join(' '), style: T.small)],
                  if (b.sum.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(b.sum, style: const TextStyle(fontSize: 13, color: kInk, height: 1.45)),
                  ],
                  const SizedBox(height: 6),
                  if (wait)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (d.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 12), child: Text('자세한 내용을 받지 못했어요. 아래 원문에서 확인해 주세요.', style: T.small))
                  else ...[
                    _Sec('지원 대상', v('대상')),
                    _Sec('선정 기준', v('기준')),
                    _Sec('지원 내용', v('내용')),
                    _Sec('신청 방법', v('방법')),
                    _Sec('신청 기한', v('기한')),
                    _Sec('제출 서류', v('서류')),
                    _Sec('접수 기관', v('접수')),
                    _Sec('문의', v('문의')),
                  ],
                  const SizedBox(height: 10),
                  const Text('공공 자료라 늦게 바뀔 수 있어요. 신청 전 원문이나 문의처에서 꼭 확인하세요.', style: T.tiny),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 12),
              child: Row(children: [
                if (tel.isNotEmpty) ...[
                  Expanded(child: Btn('전화 문의', icon: 'phone', h: 46, onTap: () => callTel(tel))),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: Btn(b.isYouth ? '온통청년에서 보기' : '정부24에서 보기',
                      h: 46,
                      primary: true,
                      onTap: () => openUrl(url.isNotEmpty ? url : 'https://www.gov.kr/portal/rcvfvrSvc/dtlEx/${b.id}', inApp: true)),
                ),
              ]),
            ),
          ]);
        },
      );
}

class _Sec extends StatelessWidget {
  final String title, text;
  const _Sec(this.title, this.text);
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kSub)),
        const SizedBox(height: 4),
        SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.45)),
      ]),
    );
  }
}
