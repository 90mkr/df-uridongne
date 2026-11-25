// 복권 상세 화면 — 이번 주 당첨번호 · 내 번호 확인 · 단지 근처 1등 나온 집 · 가까운 판매점 (이 폴더는 복권 담당 방만 고침)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'check_page.dart';
import 'data.dart';
import 'widgets.dart';

const kNear = 3000.0; // 「단지 근처」 = 3km 안
const kLottoBg = Color(0xFFF4F7FB); // 그림 머리 아래 끝과 같은 바탕색 (경계선 없게)

class LottoPage extends StatefulWidget {
  final Complex complex;
  const LottoPage({super.key, required this.complex});
  @override
  State<LottoPage> createState() => _LottoPageState();
}

class _LottoPageState extends State<LottoPage> {
  Draws? draws;
  AreaLotto? area;
  List<MyTicket> mine = [];
  int? shown; // 보고 있는 회차
  bool loading = true;
  bool byCount = true; // 1등 나온 집: 많이 나온 순 / 가까운 순
  bool showAllWins = false;
  bool showAllShops = false;

  Complex get c => widget.complex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Future.wait([loadDraws(), loadArea(c.areaId), loadMine()]);
    if (!mounted) return;
    setState(() {
      draws = r[0] as Draws?;
      area = r[1] as AreaLotto?;
      mine = r[2] as List<MyTicket>;
      shown = draws?.latest?.no;
      loading = false;
    });
  }

  Draw? get draw => shown == null ? null : draws?.byNo(shown!);

  List<(Store, double)> _near(List<Store> list) => [
        for (final s in list)
          if (meters(c.pos, s.pos) <= kNear) (s, meters(c.pos, s.pos))
      ];

  Future<void> _openCheck({Ticket? ticket}) async {
    final d = draws;
    if (d == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckPage(draws: d, ticket: ticket)));
    final m = await loadMine();
    if (mounted) setState(() => mine = m);
  }

  @override
  Widget build(BuildContext context) {
    Widget inner(Widget w) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: w));
    return Scaffold(
      backgroundColor: kLottoBg,
      body: RefreshIndicator(
        onRefresh: () async {
          final d = await loadDraws(fresh: true);
          if (mounted && d != null) setState(() => draws = d);
        },
        child: ListView(padding: EdgeInsets.zero, children: [
          _head(inner),
          inner(Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 34),
            child: loading
                ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _checkButtons(),
                    if (mine.isNotEmpty && draws?.latest != null) ...[const SizedBox(height: 22), _mine()],
                    const SizedBox(height: 16),
                    _wins(),
                    const SizedBox(height: 26),
                    _shops(),
                    const SizedBox(height: 26),
                    _foot(),
                  ]),
          )),
        ]),
      ),
    );
  }

  // ── 맨 위: 대표님 로또 그림(아래는 바탕에 녹아 경계선 없음) + ← 아이콘 복권 + 당첨번호 카드가 그림 위에 걸침
  Widget _head(Widget Function(Widget) inner) {
    final top = MediaQuery.of(context).padding.top;
    final full = MediaQuery.of(context).size.width;
    final narrow = full < 380;
    final artH = top + (full < 600 ? 210.0 : 260.0);
    return Stack(children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: artH,
        child: IgnorePointer(
          child: ShaderMask(
            // 아래 40%부터 서서히 투명 → 맨 아래는 화면 바탕색과 똑같아 경계선이 없다
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Color(0x55FFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.45, 0.78, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/art/lotto_head.png', fit: BoxFit.cover, alignment: Alignment.topRight, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
      Column(children: [
        SizedBox(height: top + 6),
        inner(Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, kPad, 0),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 24, color: kInk)),
            Image.asset('assets/icons/lotto.png', width: narrow ? 30 : 34, height: narrow ? 30 : 34),
            const SizedBox(width: 8),
            Text('복권', style: TextStyle(fontSize: narrow ? 20 : 22, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kInk)),
          ]),
        )),
        SizedBox(height: full < 600 ? 26 : 44),
        inner(Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: _result())),
      ]),
    ]);
  }

  // ---------------- 이번 회차 당첨번호 ----------------
  Widget _result() {
    final d = draw;
    if (d == null) {
      return Container(
        decoration: _card(),
        padding: const EdgeInsets.all(18),
        child: Text(loading ? '당첨번호를 불러오고 있어요.' : '당첨번호를 불러오지 못했어요. 잠시 뒤 아래로 당겨 새로고침해 주세요.', style: T.small),
      );
    }
    final first = draws!.list.first.no, last = draws!.latest!.no;
    final isLatest = d.no == last;
    final w = MediaQuery.of(context).size.width;
    final ball = w < 360 ? 34.0 : (w < 420 ? 38.0 : 42.0);
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SoftArrow(Icons.chevron_left_rounded, onTap: d.no > first ? () => setState(() => shown = d.no - 1) : null),
          Expanded(
            child: InkWell(
              onTap: _pickRound,
              borderRadius: BorderRadius.circular(8),
              child: Column(children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${d.no}회', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' 당첨번호', style: TextStyle(fontWeight: FontWeight.w400)),
                ]), style: const TextStyle(fontSize: 19, letterSpacing: -0.6, color: kInk)),
                const SizedBox(height: 3),
                Text('${d.dayText} 추첨${isLatest ? ' · 이번 주' : ''}', style: const TextStyle(fontSize: 11.5, color: kSub)),
              ]),
            ),
          ),
          SoftArrow(Icons.chevron_right_rounded, onTap: d.no < last ? () => setState(() => shown = d.no + 1) : null),
        ]),
        const SizedBox(height: 16),
        Center(child: FittedBox(fit: BoxFit.scaleDown, child: BallRow(nums: d.nums, bonus: d.bonus, size: ball))),
        const SizedBox(height: 16),
        Container(height: 1, color: const Color(0xFFEEF1F5)),
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 4),
          const Trophy(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.winners(1) > 0)
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 2, children: [
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: '1등  ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kSub)),
                    TextSpan(text: won(d.prize(1)), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.8)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEEF3FA), borderRadius: BorderRadius.circular(20)),
                    child: Text(people(d.winners(1)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B4A66))),
                  ),
                ])
              else
                const Text('1등 당첨자 없음 · 다음 회차로 이월', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (d.how.isNotEmpty && d.how.any((v) => v > 0)) ...[
                const SizedBox(height: 2),
                Text(
                    [if (d.how[0] > 0) '자동 ${d.how[0]}', if (d.how.length > 1 && d.how[1] > 0) '수동 ${d.how[1]}', if (d.how.length > 2 && d.how[2] > 0) '반자동 ${d.how[2]}'].join(' · '),
                    style: const TextStyle(fontSize: 11.5, color: kSub)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        PrizeTable(draw: d),
        if (isLatest && draws!.nextDraw != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.event_note_outlined, size: 16, color: kBlue),
            const SizedBox(width: 6),
            Text('다음 추첨 ${draws!.nextDraw!.month}월 ${draws!.nextDraw!.day}일(토) 저녁 8시 35분 · ${last + 1}회',
                style: const TextStyle(fontSize: 11.5, color: kSub)),
          ]),
        ],
      ]),
    );
  }

  Future<void> _pickRound() async {
    final d = draws;
    if (d == null) return;
    final no = await showSheet<int>(context, (ctx) => RoundPicker(draws: d, current: shown ?? d.latest!.no));
    if (no != null && mounted) setState(() => shown = no);
  }

  // ---------------- 내 번호 확인 ----------------
  Widget _checkButtons() => Row(children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _scan,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3D8BFF), Color(0xFF1F66EE)]),
                  boxShadow: [BoxShadow(color: kBlue.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 21, color: Colors.white),
                  SizedBox(width: 8),
                  Text('QR로 확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openCheck(),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 52,
                decoration: _card(r: 14),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.format_list_bulleted_rounded, size: 21, color: kBlue),
                  SizedBox(width: 8),
                  Text('번호로 확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -0.3)),
                ]),
              ),
            ),
          ),
        ),
      ]);

  Future<void> _scan() async {
    final t = await scanTicket(context);
    if (t != null && mounted) _openCheck(ticket: t);
  }

  Widget _mine() {
    final last = draws!.latest!;
    // 이번 회차 용지 + 매주 확인하는 고정 번호
    final games = <Game>[
      for (final t in mine)
        if (t.round == last.no || t.round == 0) ...t.games
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: MixTitle('내 번호', '이번 주 결과')),
        InkWell(
          onTap: () => _openCheck(),
          child: const Padding(padding: EdgeInsets.all(4), child: Text('관리', style: TextStyle(fontSize: 12, color: kSub))),
        ),
      ]),
      const SizedBox(height: 10),
      Container(
        decoration: _card(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: games.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('${last.no}회에 저장한 번호가 없어요. 지난 용지는 「관리」에서 볼 수 있어요.', style: T.small),
              )
            : Column(children: [
                for (var i = 0; i < games.length; i++) ...[
                  if (i > 0) Container(height: 1, color: const Color(0xFFF0F1F4)),
                  GameLine(label: String.fromCharCode(65 + i % 26), game: games[i], draw: last),
                ],
              ]),
      ),
    ]);
  }

  // ---------------- 1등 나온 집 ----------------
  Widget _wins() {
    final a = area;
    final near = _near(a?.wins ?? const []);
    near.sort((x, y) => byCount ? (y.$1.wins != x.$1.wins ? y.$1.wins.compareTo(x.$1.wins) : x.$2.compareTo(y.$2)) : x.$2.compareTo(y.$2));
    final show = showAllWins ? near : near.take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: _card(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 22, color: kBlue),
            const SizedBox(width: 6),
            const Expanded(child: MixTitle('1등 나온 집', '단지 근처 3km')),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(a == null || a.upto == 0 ? '로또 1등이 나온 판매점' : '262회~${a.upto}회 로또 1등이 나온 판매점', style: const TextStyle(fontSize: 11.5, color: kSub)),
          ),
          const SizedBox(height: 12),
          if (near.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(a == null ? '자료를 불러오지 못했어요.' : '단지 3km 안에 1등이 나온 판매점이 아직 없어요.', style: T.small),
            )
          else ...[
            // 목록 안 지도는 미리보기 (손가락 스크롤이 지도에 걸리지 않게), 누르면 크게
            GestureDetector(
              onTap: () => _bigMap(near),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 190,
                  child: Stack(children: [
                    IgnorePointer(
                      child: DongneMap(center: c.pos, zoom: 13, pinFill: kSoftYellow, icon: 'lotto', points: [for (final s in near.take(80)) _point(s.$1)]),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: _card(r: 20),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.map_outlined, size: 16, color: kBlue),
                          SizedBox(width: 5),
                          Text('지도 크게', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _sortPill('많이 나온 순', byCount, () => setState(() => byCount = true)),
              const SizedBox(width: 8),
              _sortPill('가까운 순', !byCount, () => setState(() => byCount = false)),
              const Spacer(),
              Text('${near.length}곳', style: const TextStyle(fontSize: 12, color: kSub)),
            ]),
          ],
        ]),
      ),
      if (near.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          decoration: _card(),
          child: Column(children: [
            for (var i = 0; i < show.length; i++) ...[
              if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0xFFF0F2F6)),
              StoreLine(store: show[i].$1, dist: show[i].$2, rank: i + 1, onTap: () => showStore(context, show[i].$1, c)),
            ],
            if (near.length > show.length) _more('${near.length - show.length}곳 더 보기', () => setState(() => showAllWins = true)),
          ]),
        ),
      ],
    ]);
  }

  Widget _sortPill(String t, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: on ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? kBlue : kLine),
          ),
          child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : kInk)),
        ),
      );

  void _bigMap(List<(Store, double)> near) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailPage(
          title: '1등 나온 집 지도',
          icon: 'lotto',
          body: DongneMap(center: c.pos, zoom: 14, pinFill: kSoftYellow, icon: 'lotto', points: [for (final s in near) _point(s.$1)]),
        ),
      ));

  MapPoint _point(Store s) => MapPoint(
        id: s.id,
        name: '${s.name} · 1등 ${s.wins}회',
        pos: s.pos,
        onTap: (ctx) => showStore(ctx, s, c),
      );

  // ---------------- 가까운 판매점 ----------------
  Widget _shops() {
    final near = _near(area?.shops ?? const [])..sort((x, y) => x.$2.compareTo(y.$2));
    final show = showAllShops ? near : near.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const MixTitle('복권 판매점', '가까운 순'),
      const SizedBox(height: 10),
      Container(
        decoration: _card(),
        child: near.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(area?.shops.isEmpty ?? true ? '판매점 목록을 모으고 있어요. 위의 「1등 나온 집」은 바로 볼 수 있어요.' : '단지 3km 안에 찾은 판매점이 없어요.', style: T.small),
              )
            : Column(children: [
                for (var i = 0; i < show.length; i++) ...[
                  if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0xFFF0F2F6)),
                  StoreLine(store: show[i].$1, dist: show[i].$2, onTap: () => showStore(context, show[i].$1, c)),
                ],
                if (near.length > show.length) _more('${near.length - show.length}곳 더 보기', () => setState(() => showAllShops = true)),
              ]),
      ),
    ]);
  }

  Widget _more(String t, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F2F6)))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(t, style: const TextStyle(fontSize: 13, color: kInk, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: kInk),
          ]),
        ),
      );

  // 시안 카드: 흰 바탕 · 둥근 16 · 아주 옅은 선 · 고르게 퍼진 옅은 그림자
  static BoxDecoration _card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        boxShadow: const [BoxShadow(color: Color(0x0F1E3A6E), blurRadius: 18)],
      );

  Widget _foot() => Text(
        '당첨 여부와 당첨금은 판매점이나 동행복권에서 꼭 다시 확인하세요. '
        '1등 판매점은 공개된 1등 배출점 자료를 모은 것이라 문을 닫았거나 주소가 바뀐 곳이 있을 수 있어요. '
        '복권은 만 19세 이상만 살 수 있어요.${draws?.updated.isNotEmpty == true ? '\n자료 갱신 ${draws!.updated}' : ''}',
        style: const TextStyle(fontSize: 10.5, color: kMute, height: 1.5),
      );
}

// ---------------- 판매점 창 ----------------
Future<void> showStore(BuildContext context, Store s, Complex c) => showSheet(
      context,
      (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.25)),
                const SizedBox(height: 4),
                Text('${c.name}에서 ${distText(meters(c.pos, s.pos))}', style: T.small),
              ]),
            ),
            Image.asset('assets/icons/lotto.png', width: 44, height: 44),
          ]),
          if (s.wins > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(color: const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF6E7B8))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  const TextSpan(text: '로또 1등 ', style: TextStyle(fontWeight: FontWeight.w300)),
                  TextSpan(text: '${s.wins}회', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]), style: const TextStyle(fontSize: 16, letterSpacing: -0.4)),
                if (s.howText.isNotEmpty || s.rounds.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text([if (s.howText.isNotEmpty) s.howText, if (s.rounds.isNotEmpty) '최근 ${s.rounds.reversed.take(5).map((r) => '$r회').join(', ')}'].join('  ·  '),
                      style: T.small),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 14),
          _infoRow('주소', s.addr.isEmpty ? '-' : s.addr),
          if (s.tel.isNotEmpty) _infoRow('전화', s.tel),
          const SizedBox(height: 14),
          Row(children: [
            if (s.tel.isNotEmpty) ...[Expanded(child: Btn('전화하기', icon: 'phone', onTap: () => callTel(s.tel))), const SizedBox(width: 10)],
            Expanded(child: Btn('길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: s.name, lat: s.lat, lng: s.lng))),
            const SizedBox(width: 10),
            Expanded(
              child: Btn('카카오맵', icon: 'map', onTap: () {
                final isKakao = RegExp(r'^\d+$').hasMatch(s.id);
                openUrl(isKakao ? 'https://place.map.kakao.com/${s.id}' : 'https://map.kakao.com/link/map/${Uri.encodeComponent(s.name)},${s.lat},${s.lng}');
              }),
            ),
          ]),
        ]),
      ),
    );

Widget _infoRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 40, child: Text(k, style: const TextStyle(fontSize: 12.5, color: kMute))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );

// 회차 고르기
class RoundPicker extends StatelessWidget {
  final Draws draws;
  final int current;
  const RoundPicker({super.key, required this.draws, required this.current});

  @override
  Widget build(BuildContext context) {
    final list = draws.list.reversed.toList();
    final at = math.max(0, list.indexWhere((d) => d.no == current));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(kPad, 14, kPad, 8),
        child: Text('회차 고르기', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      ),
      Flexible(
        child: ListView.builder(
          controller: ScrollController(initialScrollOffset: math.max(0, at - 3) * 52.0),
          itemExtent: 52,
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final d = list[i];
            final on = d.no == current;
            return InkWell(
              onTap: () => Navigator.pop(ctx, d.no),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kPad),
                child: Row(children: [
                  SizedBox(
                    width: 58,
                    child: Text('${d.no}회', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? kBlue : kInk)),
                  ),
                  Expanded(child: Text(d.date.replaceAll('-', '.'), maxLines: 1, style: T.tiny)),
                  BallRow(nums: d.nums, bonus: d.bonus, size: 22),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
