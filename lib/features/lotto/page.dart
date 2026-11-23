// 복권 상세 화면 — 이번 주 당첨번호 · 내 번호 확인 · 단지 근처 1등 나온 집 · 가까운 판매점 (이 폴더는 복권 담당 방만 고침)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'check_page.dart';
import 'data.dart';
import 'widgets.dart';

const kNear = 3000.0; // 「단지 근처」 = 3km 안

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
  Widget build(BuildContext context) => DetailPage(
        title: '복권',
        icon: 'lotto',
        white: false,
        body: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: () async {
                  final d = await loadDraws(fresh: true);
                  if (mounted && d != null) setState(() => draws = d);
                },
                child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 34), children: [
                  _result(),
                  const SizedBox(height: 10),
                  _checkButtons(),
                  if (mine.isNotEmpty && draws?.latest != null) ...[const SizedBox(height: 22), _mine()],
                  const SizedBox(height: 26),
                  _wins(),
                  const SizedBox(height: 26),
                  _shops(),
                  const SizedBox(height: 26),
                  _foot(),
                ]),
              ),
      );

  // ---------------- 이번 회차 당첨번호 ----------------
  Widget _result() {
    final d = draw;
    if (d == null) {
      return Container(
        decoration: cardBox(),
        padding: const EdgeInsets.all(18),
        child: const Text('당첨번호를 불러오지 못했어요. 잠시 뒤 아래로 당겨 새로고침해 주세요.', style: T.small),
      );
    }
    final first = draws!.list.first.no, last = draws!.latest!.no;
    final isLatest = d.no == last;
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _arrow(Icons.chevron_left_rounded, d.no > first ? () => setState(() => shown = d.no - 1) : null),
          Expanded(
            child: InkWell(
              onTap: _pickRound,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${d.no}회', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const TextSpan(text: ' 당첨번호', style: TextStyle(fontWeight: FontWeight.w300)),
                  ]), style: const TextStyle(fontSize: 17, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('${d.dayText} 추첨${isLatest ? ' · 이번 주' : ''}', style: T.tiny),
                ]),
              ),
            ),
          ),
          _arrow(Icons.chevron_right_rounded, d.no < last ? () => setState(() => shown = d.no + 1) : null),
        ]),
        const SizedBox(height: 14),
        Center(child: BallRow(nums: d.nums, bonus: d.bonus, size: 36)),
        const SizedBox(height: 16),
        Container(height: 1, color: const Color(0xFFF0F1F4)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('1등', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSub)),
          const SizedBox(width: 8),
          Expanded(
            child: d.winners(1) > 0
                ? Text.rich(TextSpan(children: [
                    TextSpan(text: won(d.prize(1)), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.4)),
                    TextSpan(text: '  ${people(d.winners(1))}', style: const TextStyle(fontSize: 12, color: kSub)),
                  ]))
                : const Text('당첨자 없음 (다음 회차로 이월)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (d.how.isNotEmpty && d.how.any((v) => v > 0)) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 27),
            child: Text(
                [if (d.how[0] > 0) '자동 ${d.how[0]}', if (d.how.length > 1 && d.how[1] > 0) '수동 ${d.how[1]}', if (d.how.length > 2 && d.how[2] > 0) '반자동 ${d.how[2]}'].join(' · '),
                style: T.tiny),
          ),
        ],
        const SizedBox(height: 12),
        PrizeTable(draw: d),
        if (isLatest && draws!.nextDraw != null) ...[
          const SizedBox(height: 12),
          Text('다음 추첨 ${draws!.nextDraw!.month}월 ${draws!.nextDraw!.day}일(토) 저녁 8시 35분 · ${last + 1}회', style: T.tiny),
        ],
      ]),
    );
  }

  Widget _arrow(IconData i, VoidCallback? onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(i, size: 26),
        color: kInk,
        disabledColor: kLine,
        visualDensity: VisualDensity.compact,
      );

  Future<void> _pickRound() async {
    final d = draws;
    if (d == null) return;
    final no = await showSheet<int>(context, (ctx) => RoundPicker(draws: d, current: shown ?? d.latest!.no));
    if (no != null && mounted) setState(() => shown = no);
  }

  // ---------------- 내 번호 확인 ----------------
  Widget _checkButtons() => Row(children: [
        Expanded(child: Btn('QR로 확인', icon: 'search', primary: true, h: 44, onTap: () => _scan())),
        const SizedBox(width: 10),
        Expanded(child: Btn('번호로 확인', icon: 'list', h: 44, onTap: () => _openCheck())),
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
        decoration: cardBox(),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const MixTitle('1등 나온 집', '단지 근처 3km'),
      const SizedBox(height: 3),
      Text(a == null || a.upto == 0 ? '로또 1등이 나온 판매점' : '262회~${a.upto}회 로또 1등이 나온 판매점', style: T.tiny),
      const SizedBox(height: 10),
      if (near.isEmpty)
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.all(16),
          child: Text(a == null ? '자료를 불러오지 못했어요.' : '단지 3km 안에 1등이 나온 판매점이 아직 없어요.', style: T.small),
        )
      else ...[
        // 목록 안 지도는 미리보기 (손가락 스크롤이 지도에 걸리지 않게), 누르면 크게
        GestureDetector(
          onTap: () => _bigMap(near),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Container(
              height: 200,
              decoration: cardBox(),
              child: Stack(children: [
                IgnorePointer(
                  child: DongneMap(
                    center: c.pos,
                    zoom: 13,
                    pinFill: kSoftYellow,
                    points: [for (final s in near.take(80)) _point(s.$1)],
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: cardBox(r: 20),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      LineIcon('map', size: 16),
                      SizedBox(width: 4),
                      Text('지도 크게', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          ChoiceChipBox('많이 나온 순', on: byCount, onTap: () => setState(() => byCount = true)),
          const SizedBox(width: 6),
          ChoiceChipBox('가까운 순', on: !byCount, onTap: () => setState(() => byCount = false)),
          const Spacer(),
          Text('${near.length}곳', style: T.tiny),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: cardBox(),
          child: Column(children: [
            for (var i = 0; i < show.length; i++) ...[
              if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: const Color(0xFFF0F1F4)),
              StoreLine(store: show[i].$1, dist: show[i].$2, rank: byCount ? i + 1 : 0, onTap: () => showStore(context, show[i].$1, c)),
            ],
            if (near.length > show.length) _more('${near.length - show.length}곳 더 보기', () => setState(() => showAllWins = true)),
          ]),
        ),
      ],
    ]);
  }

  void _bigMap(List<(Store, double)> near) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailPage(
          title: '1등 나온 집 지도',
          icon: 'lotto',
          body: DongneMap(center: c.pos, zoom: 14, pinFill: kSoftYellow, points: [for (final s in near) _point(s.$1)]),
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
        decoration: cardBox(),
        child: near.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(area?.shops.isEmpty ?? true ? '판매점 목록을 모으고 있어요. 위의 「1등 나온 집」은 바로 볼 수 있어요.' : '단지 3km 안에 찾은 판매점이 없어요.', style: T.small),
              )
            : Column(children: [
                for (var i = 0; i < show.length; i++) ...[
                  if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: const Color(0xFFF0F1F4)),
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
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F1F4)))),
          child: Text(t, style: const TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w500)),
        ),
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
            const LineIcon('lotto', size: 40, fill: kSoftYellow),
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
