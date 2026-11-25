// 우리 동네 반려동물 — 테마 첫 화면 (대표님 11-25: 위에 탭을 늘어놓지 말고, 안에 앱 목록처럼 칸을 한 번 더)
// 맨 위: 「오늘의 반려 생활」 카드 (산책·체감·미세먼지·우리 아이 할 일, 대표님 11-26) · 응급 병원은 칸 목록 아래 한 줄
// 그 아래: 칸 목록 (칸마다 독립 전문 화면) · 우리 아이 줄 · 서버 배너 (web/data/pet/promo.json, 앱 업데이트 없이 바꿈)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'guide.dart';
import 'kids.dart';
import 'kids_page.dart';
import 'places.dart';
import 'trip.dart';
import 'walk.dart';

class PetHub extends StatefulWidget {
  final Complex complex;
  const PetHub({super.key, required this.complex});
  @override
  State<PetHub> createState() => _PetHubState();
}

class _PetHubState extends State<PetHub> {
  Map<PetKind, int> count = {};
  (PetPlace, double)? nearHosp, nearNight;
  List<Map> promos = const [];
  bool loaded = false;
  WalkDay? walk; // 오늘의 산책 (11-26)

  @override
  void initState() {
    super.initState();
    loadKids().whenComplete(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    final r = await Future.wait([petNear(widget.complex.pos, km: 3), getJson('${dataBase}pet/promo.json')]);
    final v = r[0] as List<(PetPlace, double)>;
    final p = r[1];
    if (!mounted) return;
    setState(() {
      count = {for (final k in PetKind.values) k: v.where((x) => x.$1.kind == k).length};
      nearHosp = v.where((x) => x.$1.kind == PetKind.hosp).firstOrNull;
      nearNight = v.where((x) => x.$1.night).firstOrNull;
      promos = [for (final x in (p is Map ? (p['items'] as List? ?? const []) : const [])) if (x is Map && x['on'] != false) x];
      loaded = true;
    });
    // 산책 지수는 날씨 자료라 따로 (늦어도 칸 목록은 먼저 뜨게)
    final w = await Future.wait([walkProfile(), walkData(widget.complex)]);
    final wd = w[1] as WalkData?;
    if (!mounted || wd == null) return;
    setState(() => walk = walkDay(wd, w[0] as WalkProfile));
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) {
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.complex;
    String cnt(PetKind k) => !loaded ? '' : '${count[k] ?? 0}곳';
    final wl = walk?.nowJudge?.level;
    final tiles = <(String, String, String, Widget Function())>[
      ('weather', '오늘의 산책', wl == null ? '산책 지수' : kWalkShort[wl], () => PetWalkPage(complex: c)),
      ('board', '생활 가이드', '건강·먹이·훈련', () => PetGuidePage(complex: c)),
      ('hosp', '동물병원', cnt(PetKind.hosp), () => PetPlacesPage(complex: c, kind: PetKind.hosp)),
      ('hair', '미용', cnt(PetKind.groom), () => PetPlacesPage(complex: c, kind: PetKind.groom)),
      ('home', '호텔·돌봄', cnt(PetKind.hotel), () => PetPlacesPage(complex: c, kind: PetKind.hotel)),
      ('mart', '용품', cnt(PetKind.shop), () => PetPlacesPage(complex: c, kind: PetKind.shop)),
      ('pharm', '동물약국', cnt(PetKind.pharm), () => PetPlacesPage(complex: c, kind: PetKind.pharm)),
      ('event', '같이 갈 곳', '여행·카페', () => PetTripPage(complex: c)),
      ('book', '우리 아이 수첩', kids.value.isEmpty ? '접종 알림' : '${kids.value.length}마리', () => const PetKidsPage()),
    ];
    return DetailPage(
      title: '우리 동네 반려동물',
      icon: 'pet',
      white: false,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
          _Today(
              walk: walk,
              onWalk: () => _go(PetWalkPage(complex: c)),
              onKids: () => _go(const PetKidsPage()),
              onGuide: () => _go(PetGuidePage(complex: c))),
          const SizedBox(height: 22),
          const MixTitle('반려동물', '생활', size: 15),
          const SizedBox(height: 10),
          Container(
            decoration: cardBox(),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: LayoutBuilder(builder: (ctx, box) {
              final per = box.maxWidth > 520 ? 5 : 3; // 9칸: 휴대폰 3×3
              final w = box.maxWidth / per;
              return Wrap(children: [
                for (final t in tiles)
                  SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _go(t.$4()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(children: [
                          LineIcon(t.$1, size: 38),
                          const SizedBox(height: 6),
                          Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                          Text(t.$3, maxLines: 1, style: T.tiny),
                        ]),
                      ),
                    ),
                  ),
              ]);
            }),
          ),
          const SizedBox(height: 14),
          // 밤·휴일 응급 병원 — 맨 위 대신 아래 한 줄로 (대표님 11-26)
          _EmergencyRow(night: petNightNow(DateTime.now()), nearNight: nearNight, nearHosp: nearHosp, loaded: loaded, onTap: () => _go(PetEmergencyPage(complex: c))),
          for (final p in promos) ...[const SizedBox(height: 14), _Promo(p: p)],
          const SizedBox(height: 18),
          Text('${c.name} 둘레 3km 기준 · 소상공인 상가정보·인허가 자료', style: T.tiny),
        ]),
      ),
    );
  }
}

// 맨 위 「오늘의 반려 생활」 — 단지 홈 맨 위 카드처럼 몇 가지 정보를 한눈에 (대표님 11-26)
// 큰 줄: 지금 산책 단계 + 추천 시간 · 작은 칸 넷: 산책 / 체감 / 미세먼지 / 우리 아이 수첩 다음 할 일
class _Today extends StatelessWidget {
  final WalkDay? walk;
  final VoidCallback onWalk, onKids, onGuide;
  const _Today({required this.walk, required this.onWalk, required this.onKids, required this.onGuide});

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final w = walk;
    final j = w?.nowJudge;
    final h = w?.now;
    final best = w?.best;
    final cats = onlyCats;

    // 큰 줄
    final String big, sub;
    if (cats) {
      big = '오늘도 집 안 사냥 놀이 10분';
      sub = '고양이는 짧은 놀이를 하루 여러 번이 좋아요';
    } else if (j == null) {
      big = '오늘 날씨를 살피고 있어요';
      sub = '산책하기 좋은 시간을 골라 드려요';
    } else {
      big = '지금 산책 ${kWalkShort[j.level]}';
      sub = best == null ? '오늘 낮 산책 시간은 지났어요' : '추천 ${runText(best)}${j.why.isEmpty ? '' : ' · ${j.why.first}'}';
    }

    // 작은 칸
    final f = h?.feels, t = h?.temp;
    final dust = w == null ? '' : _dustShort(w);
    final due = dueList(now).firstOrNull;
    String kidVal = '등록', kidSub = '접종 알림';
    if (due != null) {
      final n = dayDiff(due.$2.next, now);
      kidVal = n == 0 ? '오늘' : (n > 0 ? 'D-$n' : '${-n}일 지남');
      kidSub = careById(due.$2.id).name;
    } else if (kids.value.isNotEmpty) {
      kidVal = '${kids.value.length}마리';
      kidSub = '챙길 날 없음';
    }
    final stats = <(String, String, String, VoidCallback)>[
      ('산책', j == null ? '-' : kWalkShort[j.level], best == null ? '' : _bestShort(best), onWalk),
      ('체감', f == null ? '-' : '${f.round()}℃', t == null ? '' : '기온 ${t.round()}℃', onWalk),
      ('미세먼지', dust.isEmpty ? '-' : dust, '', onWalk),
      ('우리 아이', kidVal, kidSub, onKids),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1570EA), Color(0xFF0B4DBA)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF0B4DBA).withValues(alpha: 0.16), blurRadius: 18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: -14, top: -10, child: LineIcon('pet', size: 120, line: Colors.white.withValues(alpha: 0.16), fill: Colors.white.withValues(alpha: 0.06))),
        Material(
          color: Colors.transparent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: cats ? onGuide : onWalk,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('오늘의 반려 생활 · ${now.month}월 ${now.day}일 ${_wd[now.weekday - 1]}요일', style: const TextStyle(fontSize: 12, color: Color(0xD9FFFFFF), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.7, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xE6FFFFFF))),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _Stat(label: stats[i].$1, value: stats[i].$2, sub: stats[i].$3, onTap: stats[i].$4)),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  static String _bestShort((DateTime, DateTime, int) b) => '${b.$1.hour}~${b.$2.hour}시';
  static String _dustShort(WalkData d) => d.dust <= 0 ? '' : const ['', '좋음', '보통', '나쁨', '매우나쁨'][d.dust.clamp(0, 4)];
}

class _Stat extends StatelessWidget {
  final String label, value, sub;
  final VoidCallback onTap;
  const _Stat({required this.label, required this.value, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, style: const TextStyle(fontSize: 10.5, color: Color(0xCCFFFFFF), fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 1),
            Text(sub.isEmpty ? ' ' : sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xB3FFFFFF))),
          ]),
        ),
      );
}

// 밤·휴일 응급 동물병원 — 흰 카드 한 줄 (밤·일요일엔 문구만 바뀜)
class _EmergencyRow extends StatelessWidget {
  final bool night, loaded;
  final (PetPlace, double)? nearNight, nearHosp;
  final VoidCallback onTap;
  const _EmergencyRow({required this.night, required this.nearNight, required this.nearHosp, required this.loaded, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final x = nearNight ?? nearHosp;
    final sub = !loaded
        ? '찾고 있어요'
        : x == null
            ? '24시·응급 병원을 가까운 순으로 찾아 드려요'
            : '${nearNight != null ? '24시·야간' : '가장 가까운 병원'}: ${x.$1.name} · ${distText(x.$2)}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Row(children: [
            const LineIcon('night', size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(night ? '지금 문 연 응급 동물병원' : '밤·휴일 응급 동물병원', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 20, color: kMute),
          ]),
        ),
      ),
    );
  }
}

// 서버 배너 (예: 반려동물 추모관 — 대표님 별도 서비스로 연결) · promo.json {"items":[{"title","sub","url","img","on"}]}
class _Promo extends StatelessWidget {
  final Map p;
  const _Promo({required this.p});
  @override
  Widget build(BuildContext context) {
    final img = '${p['img'] ?? ''}';
    final tag = '${p['tag'] ?? ''}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => openUrl('${p['url'] ?? ''}'),
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (tag.isNotEmpty) Text(tag, style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w600)),
                MixTitle('${p['bold'] ?? p['title'] ?? ''}', '${p['thin'] ?? ''}', size: 15),
                if ('${p['sub'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 3), Text('${p['sub']}', style: T.small, maxLines: 2)],
              ]),
            ),
            if (img.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(img, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            ],
          ]),
        ),
      ),
    );
  }
}
