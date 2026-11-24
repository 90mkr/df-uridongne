// 단지 앞 버스 (이 폴더는 단지 앞 버스 담당 방만 고침)
// 단지 홈 반쪽 카드: 단지에서 가장 가까운(또는 고정한) 정류장에 먼저 오는 버스 2대 — 몇 분 · 몇 정거장
// 즐겨찾기 버스를 고정하면 홈 카드엔 그 버스만 (11-25)
// 상세 화면(11-25): 지도 + 아래 창(가까운 정류장 2곳 양방향) · 정류장 누르면 그 정류장 · 목록 보기는 단추로
// (예전) 상세 화면: 둘레 정류장 고르기 · 실시간 도착(30초마다) · 자주 타는 정류장 고정 · 노선 보기(정류장 순서·지금 버스 위치·첫차 막차) · 지도
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'page.dart';

class BusFeature extends Feature {
  @override
  String get id => 'bus';
  @override
  String get name => '단지 앞 버스';
  @override
  String get icon => 'bus';
  @override
  Slot get slot => Slot.tail; // 대표님 11-24: 실시간이라 늦게 떠서 홈 맨 아래 가로 한 줄 크게
  @override
  int get order => 10;
  @override
  String get version => '0.4.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoft;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HomeCard(feature: this, complex: c);

  @override
  Widget page(BuildContext context, Complex c) => BusPage(complex: c);

  // 「지금 우리 단지」 카드: 출퇴근 시간에 높게, 곧 오는 버스 두 대
  @override
  Future<Brief?> brief(Complex c, DateTime now) async {
    final stops = await stopsFor(c);
    if (stops.isEmpty) return null;
    final arr = await arrivals(stops.first);
    if (arr == null || arr.isEmpty) return null;
    final a = [...arr]..sort((x, y) => x.secs.compareTo(y.secs));
    final f = a.first;
    final rush = (now.hour >= 6 && now.hour < 10) || (now.hour >= 17 && now.hour < 20);
    return Brief(
      icon: 'bus',
      kicker: '${rush ? (now.hour < 12 ? '출근길' : '퇴근길') : '지금'} · ${stops.first.name}',
      bold: '${f.routeNo}번 ',
      hot: f.soon ? '곧 도착' : '${f.mins}분 뒤',
      rest: f.soon ? '' : ' 도착',
      sub: a.length > 1 ? '다음 ${a[1].routeNo}번 ${a[1].mins}분 · ${a[1].left}정거장 전' : '${f.left}정거장 전',
      score: rush ? 80 : 45,
    );
  }

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final list = await stopsNear(c);
    return [
      for (final s in list)
        MapPoint(
          id: 'bus.${s.id}',
          name: s.name,
          sub: '${distText(meters(c.pos, s.pos))}${s.no.isEmpty ? '' : ' · ${s.no}'}',
          pos: s.pos,
          onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => BusPage(complex: c, startStop: s.id))),
        ),
    ];
  }
}

class _HomeCard extends StatefulWidget {
  final BusFeature feature;
  final Complex complex;
  const _HomeCard({required this.feature, required this.complex});
  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  Stop? stop;
  List<Arrival>? arr;
  var loading = true;
  // 즐겨찾기 버스 (대표님 11-25): 고정한 버스가 있으면 홈 카드엔 그 버스만 — (노선, 타는 정류장, 지금 도착)
  List<(Map, Stop, Arrival?)> favRows = [];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _HomeCard old) {
    super.didUpdateWidget(old);
    if (old.complex.id != widget.complex.id) {
      stop = null;
      arr = null;
      loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await stopsFor(widget.complex);
    if (!mounted) return;
    stop = list.isEmpty ? null : list.first;
    await _refresh();
  }

  Future<void> _refresh() async {
    final s = stop;
    final c = widget.complex;
    final favs = <(Map, Stop)>[];
    for (final m in await favRoutes()) {
      final fs = Stop.fromJson(m['s']) ?? s;
      if (fs == null || meters(c.pos, fs.pos) > 1500) continue;
      favs.add((m, fs));
    }
    if (favs.isNotEmpty) {
      final byStop = <String, List<Arrival>?>{};
      for (final f in favs) {
        if (!byStop.containsKey(f.$2.id)) byStop[f.$2.id] = await arrivals(f.$2);
      }
      favRows = [
        for (final f in favs.take(4))
          (f.$1, f.$2, (byStop[f.$2.id] ?? const <Arrival>[]).where((a) => a.routeId == f.$1['r']).firstOrNull),
      ];
    } else {
      favRows = [];
      if (s != null) arr = await arrivals(s);
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature, c = widget.complex, s = stop;
    // 가로 한 줄 큰 카드: 파란 머리띠(정류장) + 노선별 줄 (최대 4개). 불러오는 동안도 높이를 잡아 둬 화면이 안 튐
    Widget body;
    if (loading) {
      body = Column(children: [for (var i = 0; i < 3; i++) const _Ghost()]);
    } else if (favRows.isNotEmpty) {
      body = Column(children: [
        for (var i = 0; i < favRows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F5), indent: 76),
          _FavRow(m: favRows[i].$1, stop: favRows[i].$2, a: favRows[i].$3, hot: i == 0),
        ],
      ]);
    } else if (s == null) {
      body = _msg(lastErr == BusErr.none ? '가까운 정류장이 없어요' : '정류장 자료를 모으고 있어요');
    } else if (arr == null) {
      body = _msg(errText(lastErr));
    } else if (arr!.isEmpty) {
      body = _msg('지금 오는 버스가 없어요');
    } else {
      final rows = byRoute(arr!).take(4).toList();
      body = Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F5), indent: 76),
          _Row(r: rows[i], hot: i == 0),
        ],
      ]);
    }
    // 대표님 시안(11-24): 진한 파랑 머리띠 + 오른쪽 정류장·버스 그림 + 흰 「실시간」 단추, 흰 판이 둥글게 겹쳐 올라옴
    // 모서리까지 깔끔하게 잘리도록: 그림자 상자 > 둥글게 자르기 > 흰 바탕 > 누르기
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF0A74F4).withValues(alpha: 0.16), blurRadius: 16)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => openFeature(context, f),
            child: Stack(children: [
              Container(
                height: 104,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A6CF0), Color(0xFF2A8CFB)])),
                child: Stack(children: [
                  // 대표님 사진(11-24) 깔고, 글자 쪽(왼쪽)만 색 필터
                  Positioned.fill(child: Image.asset('assets/art/bus_bg.jpg', fit: BoxFit.cover, alignment: const Alignment(0.7, 0.1), filterQuality: FilterQuality.medium)),
                  const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xF20A5FE0), Color(0xCC1570EA), Color(0x2E1570EA)], stops: [0, 0.45, 0.8])))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 12, 16),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                        child: const LineIcon('bus', size: 32),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('단지 앞 버스', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(favRows.isNotEmpty ? Icons.star_rounded : Icons.place_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                favRows.isNotEmpty
                                    ? '즐겨찾기 버스 ${favRows.length}개'
                                    : s == null
                                        ? '정류장을 찾고 있어요'
                                        : '${s.name} · ${distText(meters(c.pos, s.pos))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xF2FFFFFF), height: 1.3),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('실시간', style: TextStyle(fontSize: 12, color: Color(0xFF0A6CF0), fontWeight: FontWeight.w800)),
                          Icon(Icons.chevron_right_rounded, color: Color(0xFF0A6CF0), size: 18),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 90),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: body,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _msg(String t) => SizedBox(height: 120, child: Center(child: Text(t, style: T.small)));
}

// 노선 종류 색 (광역 빨강 · 간선 파랑 · 지선 초록 · 그 밖 파랑)
Color _typeColor(String t) {
  if (t.contains('광역') || t.contains('급행') || t.contains('좌석')) return const Color(0xFFE5484D);
  if (t.contains('지선') || t.contains('마을')) return const Color(0xFF2EA36B);
  return kBlue;
}

class _Row extends StatelessWidget {
  final RouteArrivals r;
  final bool hot;
  const _Row({required this.r, required this.hot});
  @override
  Widget build(BuildContext context) {
    final a = r.first, n = r.next;
    final col = _typeColor(a.type);
    return SizedBox(
      height: 52,
      child: Row(children: [
        // 노선 번호: 종류 색으로 꽉 찬 알약 + 흰 글자
        Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col.withValues(alpha: 0.85), col]), borderRadius: BorderRadius.circular(14)),
          child: Text(a.routeNo, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(n == null ? a.leftText : '${a.leftText} · 다음 ${n.minsText}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5468))),
        ),
        // 도착 시간: 옅은 파랑 알약 + 버스 아이콘
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
          decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_bus_rounded, size: 15, color: Color(0xFF5B78B0)),
            const SizedBox(width: 6),
            Text(a.minsText, style: TextStyle(fontSize: hot ? 17 : 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: hot ? kBlue : kInk)),
          ]),
        ),
      ]),
    );
  }
}

// 즐겨찾기 버스 한 줄: 노선 알약 · 타는 정류장 · 도착 (없으면 「정보 없음」)
class _FavRow extends StatelessWidget {
  final Map m;
  final Stop stop;
  final Arrival? a;
  final bool hot;
  const _FavRow({required this.m, required this.stop, required this.a, required this.hot});
  @override
  Widget build(BuildContext context) {
    final col = _typeColor('${a?.type ?? m['t'] ?? ''}');
    final no = a?.routeNo ?? '${m['no'] ?? ''}';
    return SizedBox(
      height: 52,
      child: Row(children: [
        Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col.withValues(alpha: 0.85), col]), borderRadius: BorderRadius.circular(14)),
          child: Text(no, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(a == null ? '${stop.name} · 지금 오는 버스 정보가 없어요' : '${stop.name} · ${a!.leftText}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5468))),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
          decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_bus_rounded, size: 15, color: Color(0xFF5B78B0)),
            const SizedBox(width: 6),
            Text(a == null ? '–' : a!.minsText, style: TextStyle(fontSize: hot ? 17 : 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: hot && a != null ? kBlue : kInk)),
          ]),
        ),
      ]),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: Row(children: [
          Container(width: 58, height: 26, decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 10, margin: const EdgeInsets.only(right: 60), decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(5)))),
          Container(width: 40, height: 16, decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(5))),
        ]),
      );
}
