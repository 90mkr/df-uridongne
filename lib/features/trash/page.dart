// 쓰레기·분리수거 상세 화면
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/me.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'art.dart';
import 'guide.dart';
import 'trash_icons.dart';
import '../../core/remote.dart';

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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF6F9FD),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: loading
                ? Column(children: [_header(null), const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))])
                : RefreshIndicator(
                    onRefresh: () => _load(fresh: true),
                    child: ListView(padding: const EdgeInsets.only(bottom: 34), children: _body(info!)),
                  ),
          ),
        ),
      );

  Widget _pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: w);

  List<Widget> _body(TrashInfo i) {
    final z = i.zone;
    return [
      _header(i),
      // 두 칸: 수거하지 않는 날 | 대형 폐기물 (머리 그림 아래에 살짝 겹침)
      Transform.translate(offset: const Offset(0, -16), child: _pad(_offBulk(z))),
      _pad(_where(i)),
      if (z == null && i.needPick)
        _pad(_notice('이 지역은 구역마다 배출 요일이 달라요. 단지가 속한 구역을 골라 주세요.', '구역 고르기', _pickZone))
      else if (i.gov == null && !i.fromApt)
        _pad(_notice('이 지역 지자체 배출 정보가 아직 없어요. 관리사무소가 정한 요일을 알려 주시면 이웃 모두가 함께 봐요.', '요일 알려 주기', _edit)),
      if (!i.empty) ...[
        const SizedBox(height: 18),
        _pad(_table(i)),
      ],
      if (i.fromApt) ...[
        const SizedBox(height: 8),
        _pad(_aptNote(i.apt!)),
      ],
      const SizedBox(height: 14),
      _pad(_aptBar(i)),
      if (z != null) ...[
        _pad(_head('배출 방법')),
        _pad(_methods(z)),
      ],
      _pad(_head('이건 어떻게 버려요?', big: true)),
      _pad(const GuideBox()),
      const SizedBox(height: 22),
      _pad(Text(
        [
          if (z != null) '자료: 행정안전부 생활쓰레기배출정보 (${i.gov?.gu ?? ''} 기준일 ${z.date})',
          '지자체 사정에 따라 실제와 다를 수 있어요. 아파트는 관리사무소 안내를 먼저 따라 주세요.',
        ].join('\n'),
        style: T.tiny,
      )),
    ];
  }

  // ── 맨 위 (대표님 시안 11-25): ← 재활용 아이콘 「쓰레기·분리수거」 + 오른쪽 그림(쓰레기통·상자·병)
  // 그림 왼쪽·아래는 바탕으로 서서히 녹여 경계선이 안 생기게
  Widget _header(TrashInfo? i) {
    final top = MediaQuery.of(context).padding.top;
    final w = MediaQuery.of(context).size.width.clamp(0, 720).toDouble();
    final artW = (w * 0.5).clamp(170.0, 330.0);
    final artH = artW * 290 / 610;
    final h = top + (artH + 6).clamp(96.0, 170.0);
    return SizedBox(
      height: h,
      child: Stack(children: [
        // 바탕: 왼쪽 위 옅은 하늘 → 아래 화면 바탕색
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomCenter, colors: [Color(0xFFE6F1FD), Color(0xFFF6F9FD)])),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          width: artW + 30,
          height: artH + 10,
          child: ClipRect(child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [Color(0x00FFFFFF), Colors.white, Colors.white], stops: [0, 0.3, 1]).createShader(r),
            blendMode: BlendMode.dstIn,
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0, 0.18, 0.86, 1]).createShader(r),
              blendMode: BlendMode.dstIn,
              child: artImage('assets/art/trash_head.png', fit: BoxFit.cover, alignment: Alignment.centerRight, filterQuality: FilterQuality.medium),
            ),
          )),
        ),
        Positioned(
          left: 4,
          top: top + 14,
          child: Row(children: [
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21, color: kInk)),
            Image.asset('assets/icons/recycle.png', width: 38, height: 38),
            const SizedBox(width: 8),
            Text('쓰레기·분리수거', style: TextStyle(fontSize: w < 380 ? 19 : 21, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk)),
          ]),
        ),
      ]),
    );
  }

  // 위치 · 구역 (두 칸 아래 한 줄)
  Widget _where(TrashInfo i) {
    final g = i.gov;
    final z = i.zone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 4),
      child: Row(children: [
        const TrashIcon('pin', size: 16, line: kBlue, fill: Color(0xFFD6E4FF)),
        const SizedBox(width: 4),
        // 구역 이름이 길면 「…」 대신 옆으로 밀어 끝까지 (대표님 11-28)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              [g == null ? c.name : '${g.sido} ${g.gu}${i.dong.isNotEmpty ? ' · ${i.dong}' : ''}', if (z != null) z.label].join('  ·  '),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 12, color: kSub),
            ),
          ),
        ),
        if ((g?.zones.length ?? 0) > 1)
          TextButton(
            onPressed: _pickZone,
            style: TextButton.styleFrom(foregroundColor: kBlue, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            child: const Text('구역 바꾸기'),
          ),
      ]),
    );
  }

  Widget _notice(String text, String btn, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(top: 12),
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

  // ── 배출 요일표: 왼쪽 위 파랑 꼬리표 + 오늘 세로줄 옅은 파랑
  static const _green = Color(0xFF1FA463);
  static const _gray = Color(0xFF7A808C);

  Widget _table(TrashInfo i) {
    final today = dayChar(DateTime.now());
    final ti = _week.indexOf(today);
    const rowH = 58.0, headH = 46.0;
    const rowIcon = {'g': 'bin', 'f': 'f', 'r': 'r'};
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine), boxShadow: kShadow),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (ctx, box) {
        // 이름 밑 시간 글(「저녁 6시 ~ 새벽 0시」)이 「…」로 잘리지 않게 왼쪽 칸을 글 길이만큼 넓힘 (대표님 11-28)
        // 요일 칸은 30 아래로 줄이지 않고, 그래도 모자라면 시간 글만 옆으로 밀어 봄
        var timeW = 0.0;
        for (final k in kKinds) {
          final t = rangeText(i.hoursOf(k));
          if (t.isEmpty) continue;
          final tp = TextPainter(
            text: TextSpan(text: t, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 10.5)),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(ctx),
            maxLines: 1,
          )..layout();
          if (tp.width > timeW) timeW = tp.width;
          tp.dispose();
        }
        final wantW = timeW == 0 ? 0.0 : 12 + 26 + 7 + timeW + 8;
        final baseW = (box.maxWidth * 0.31).clamp(104.0, 170.0);
        final maxW = math.max(baseW, box.maxWidth - 8 - 30 * 7);
        final labelW = math.max(baseW, wantW).clamp(baseW, maxW);
        final colW = (box.maxWidth - labelW - 8) / 7;
        return SizedBox(
          height: headH + rowH * 3 + 8,
          child: Stack(children: [
            // 오늘 세로줄
            Positioned(
              left: labelW + colW * ti + 2,
              width: colW - 4,
              top: 6,
              bottom: 6,
              child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(12))),
            ),
            // 꼬리표
            Positioned(
              left: 0,
              top: 0,
              width: labelW - 6,
              height: headH,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1C64F2), Color(0xFF1453D6)]),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
                ),
                padding: const EdgeInsets.only(left: 12),
                alignment: Alignment.centerLeft,
                child: const Row(children: [
                  TrashIcon('cal', size: 20, line: Colors.white, fill: Color(0x33FFFFFF)),
                  SizedBox(width: 6),
                  Flexible(child: Text('배출 요일표', maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4))),
                ]),
              ),
            ),
            Column(children: [
              SizedBox(
                height: headH,
                child: Row(children: [
                  SizedBox(width: labelW),
                  for (final d in _week.split(''))
                    SizedBox(
                      width: colW,
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: d == today ? FontWeight.w800 : FontWeight.w500, color: d == today ? kBlue : kInk)),
                    ),
                ]),
              ),
              for (var n = 0; n < kKinds.length; n++)
                Container(
                  height: rowH,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: n == 0 ? null : const Border(top: BorderSide(color: kLine))),
                  child: Row(children: [
                    SizedBox(
                      width: labelW - 12,
                      child: Row(children: [
                        TrashIcon(rowIcon[kKinds[n]]!, size: 26, line: kKinds[n] == 'r' ? _green : kInk, fill: kKinds[n] == 'r' ? const Color(0xFFDDF3E6) : const Color(0xFFF1F3F6)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(kKindName[kKinds[n]]!, maxLines: 1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                            if (rangeText(i.hoursOf(kKinds[n])).isNotEmpty)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(rangeText(i.hoursOf(kKinds[n])), maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 10.5, color: kSub)),
                              ),
                          ]),
                        ),
                      ]),
                    ),
                    for (final d in _week.split(''))
                      SizedBox(
                        width: colW,
                        child: Center(
                          child: i.daysOf(kKinds[n]).contains(d)
                              ? TrashIcon(rowIcon[kKinds[n]]!, size: 22, line: d == today ? kBlue : _gray, fill: d == today ? const Color(0xFFD6E4FF) : Colors.white)
                              : const Text('-', style: TextStyle(color: kMute, fontSize: 13)),
                        ),
                      ),
                  ]),
                ),
            ]),
          ]),
        );
      }),
    );
  }

  // ── 관리사무소 요일 알려 주기 띠
  Widget _aptBar(TrashInfo i) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _edit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          decoration: BoxDecoration(color: const Color(0xFFF0F5FF), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const TrashIcon('mega', size: 24, line: kBlue, fill: Color(0xFFD6E4FF)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                i.fromApt ? '우리 단지 요일이 바뀌었나요? 고쳐 주세요' : '관리사무소가 정한 요일이 다른가요? 우리 단지 요일 알려 주기',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.3),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: kSub),
          ]),
        ),
      );

  Widget _head(String t, {bool big = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
        child: Row(children: [
          Container(width: 3, height: big ? 20 : 17, decoration: BoxDecoration(color: big ? _green : kBlue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t, style: TextStyle(fontSize: big ? 19 : 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ]),
      );

  // ── 배출 방법 카드 3장 (일반·음식물·재활용)
  static const _cardStyle = {
    'g': ('bag', [Color(0xFFE8F1FF), Color(0xFFF5F9FF)], Color(0xFF2F80ED)),
    'f': ('food', [Color(0xFFFFF0E0), Color(0xFFFFF9F2)], Color(0xFFF08A1C)),
    'r': ('recy', [Color(0xFFE3F5EB), Color(0xFFF3FBF6)], _green),
  };

  Widget _methods(Zone z) {
    final ks = [for (final k in kKinds) if ((z.method[k] ?? '').isNotEmpty) k];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var n = 0; n < ks.length; n++) ...[
          if (n > 0) const SizedBox(width: 8),
          Expanded(child: _methodCard(z, ks[n])),
        ],
      ]),
    );
  }

  Widget _methodCard(Zone z, String k) {
    final st = _cardStyle[k]!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _methodSheet(z, k),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: st.$2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: SizedBox(height: 62, child: Image.memory(trashArt[st.$1]!, fit: BoxFit.contain, gaplessPlayback: true))),
          const SizedBox(height: 8),
          Text(kKindName[k]!, maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(keepWords(z.method[k]!), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF454A55), height: 1.4, letterSpacing: -0.3)),
          const Spacer(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: st.$3, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const TrashIcon('arrow', size: 16, line: Colors.white, weight: 4),
            ),
          ),
        ]),
      ),
    );
  }

  void _methodSheet(Zone z, String k) {
    final h = rangeText(z.hours[k] ?? const []);
    showSheet<void>(
      context,
      (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(height: 48, child: Image.memory(trashArt[_cardStyle[k]!.$1]!)),
            const SizedBox(width: 10),
            Text(kKindName[k]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ]),
          const SizedBox(height: 12),
          _line('cal', '배출 요일', daysText(z.days[k] ?? '')),
          if (h.isNotEmpty) _line('time', '배출 시간', h),
          _line(k == 'g' ? 'bin' : k, '배출 방법', z.method[k]!),
          if (z.placeType.isNotEmpty || z.place.isNotEmpty) _line('pin', '배출 장소', [z.placeType, z.place].where((s) => s.isNotEmpty).join(' · ')),
        ]),
      ),
    );
  }

  // ── 수거하지 않는 날 | 대형 폐기물: 따로 떨어진 두 칸 (왼쪽 옅은 파랑 · 오른쪽 옅은 초록), 큰 아이콘 + 제목 + 설명 + 화살표
  Widget _offBulk(Zone? z) {
    final narrow = MediaQuery.of(context).size.width < 380;
    Widget card(String title, String sub, IconData icon, Color ink, List<Color> tint, Color disk, VoidCallback? onTap) => Expanded(
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x140B2A5B), blurRadius: 14)]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Ink(
                  height: narrow ? 92 : 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white),
                  ),
                  padding: EdgeInsets.fromLTRB(narrow ? 10 : 12, 10, 6, 10),
                  child: Row(children: [
                    Container(
                      width: narrow ? 40 : 48,
                      height: narrow ? 40 : 48,
                      decoration: BoxDecoration(color: disk, shape: BoxShape.circle),
                      child: Icon(icon, size: narrow ? 22 : 26, color: ink),
                    ),
                    SizedBox(width: narrow ? 8 : 10),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, maxLines: 1, style: TextStyle(fontSize: narrow ? 13.5 : 15, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
                        ),
                        const SizedBox(height: 4),
                        Text(keepWords(sub), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: narrow ? 11 : 12, color: const Color(0xFF5A6475), height: 1.35)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: onTap == null ? Colors.transparent : kInk),
                  ]),
                ),
              ),
            ),
          ),
        );
    final off = z == null ? '구역을 고르면 보여요' : (z.off.isEmpty ? '없음' : z.off.replaceAll('+', ', '));
    final bulk = z == null ? '신고 후 배출' : ((z.method['b'] ?? '').isNotEmpty ? z.method['b']! : '신고 후 배출');
    return Row(children: [
      card('수거하지 않는 날', off, Icons.event_busy_rounded, kBlue, const [Color(0xFFF4F8FF), Color(0xFFE3EEFD)], const Color(0xFFD9E7FD), null),
      const SizedBox(width: 10),
      card('대형 폐기물', bulk, Icons.weekend_outlined, const Color(0xFF1F9D57), const [Color(0xFFF2FBF5), Color(0xFFDDF3E4)], const Color(0xFFCDEEDA), z == null ? null : () => _bulkSheet(z)),
    ]);
  }

  void _bulkSheet(Zone z) => showSheet<void>(
        context,
        (ctx) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('대형 폐기물', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            _line('b', '내는 방법', (z.method['b'] ?? '').isNotEmpty ? z.method['b']! : '구청·주민센터나 지자체 신청 사이트에 신고하고 수수료를 낸 뒤 내요.'),
            if (z.bulkPlace.isNotEmpty) _line('pin', '내는 곳', z.bulkPlace),
            if (rangeText(z.hours['b'] ?? const []).isNotEmpty) _line('time', '내는 시간', rangeText(z.hours['b']!)),
            _line('s', '수수료', '품목과 크기마다 달라요. 신고할 때 안내받거나 담당 부서에 물어보세요. 냉장고·세탁기 같은 가전은 폐가전 무상 방문수거(1599-0903)로 무료예요.'),
            if (z.tel.isNotEmpty) ...[
              const SizedBox(height: 12),
              Btn('${z.dept.isNotEmpty ? z.dept : '담당 부서'} ${z.tel}', icon: 'phone', onTap: () => callTel(z.tel)),
            ],
          ]),
        ),
      );

  Widget _line(String icon, String title, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TrashIcon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(keepWords(text), style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
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
