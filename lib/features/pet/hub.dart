// 우리 동네 반려동물 — 테마 첫 화면 (대표님 11-25: 위에 탭을 늘어놓지 말고, 안에 앱 목록처럼 칸을 한 번 더)
// 맨 위: 지금 상황 카드 (챙길 날 다가옴 > 밤·주말 응급 > 가까운 병원)
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
          _Now(
              complex: c,
              nearHosp: nearHosp,
              nearNight: nearNight,
              loaded: loaded,
              walk: walk,
              onEmergency: () => _go(PetEmergencyPage(complex: c)),
              onKids: () => _go(const PetKidsPage()),
              onWalk: () => _go(PetWalkPage(complex: c))),
          const SizedBox(height: 22),
          const MixTitle('반려동물', '생활', size: 15),
          const SizedBox(height: 10),
          Container(
            decoration: cardBox(),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: LayoutBuilder(builder: (ctx, box) {
              final per = box.maxWidth > 520 ? 6 : 4;
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
          for (final p in promos) ...[const SizedBox(height: 14), _Promo(p: p)],
          const SizedBox(height: 18),
          Text('${c.name} 둘레 3km 기준 · 소상공인 상가정보·인허가 자료', style: T.tiny),
        ]),
      ),
    );
  }
}

// 맨 위 「지금」 카드 — 한 장만
class _Now extends StatelessWidget {
  final Complex complex;
  final (PetPlace, double)? nearHosp, nearNight;
  final bool loaded;
  final WalkDay? walk;
  final VoidCallback onEmergency, onKids, onWalk;
  const _Now(
      {required this.complex,
      required this.nearHosp,
      required this.nearNight,
      required this.loaded,
      this.walk,
      required this.onEmergency,
      required this.onKids,
      required this.onWalk});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final due = dueList(now).where((x) => dayDiff(x.$2.next, now) <= 3).firstOrNull;
    final night = petNightNow(now);

    Widget card({required String kicker, required String big, required String sub, required String btn, required VoidCallback onTap, String icon = 'pet'}) => Material(
          color: kBlue,
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(kicker, style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(big, style: const TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.25)),
                    if (sub.isNotEmpty) ...[const SizedBox(height: 4), Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70))],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Text(btn, style: const TextStyle(fontSize: 12.5, color: kBlue, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                LineIcon(icon, size: 58, line: Colors.white, fill: Colors.white.withValues(alpha: 0.22)),
              ]),
            ),
          ),
        );

    if (due != null) {
      final (k, c) = due;
      final n = dayDiff(c.next, now);
      return card(
        kicker: '우리 아이 수첩',
        big: '${k.name} ${careById(c.id).name}\n${n == 0 ? '오늘이에요' : (n > 0 ? '$n일 남았어요' : '${-n}일 지났어요')}',
        sub: '${c.next.month}월 ${c.next.day}일${k.hosp.isNotEmpty ? ' · ${k.hosp}' : ''}',
        btn: '수첩 열기',
        onTap: onKids,
        icon: 'book',
      );
    }
    if (night) {
      final x = nearNight;
      return card(
        kicker: now.weekday == DateTime.sunday ? '일요일 · 응급할 때' : '밤 시간 · 응급할 때',
        big: '밤에도 여는\n동물병원 찾기',
        sub: x == null ? '24시·응급 병원을 가까운 순으로 찾아 드려요' : '가장 가까운 곳: ${x.$1.name} · ${distText(x.$2)}',
        btn: '응급·24시 병원 보기',
        onTap: onEmergency,
        icon: 'night',
      );
    }
    // 낮에는 오늘의 산책 (매일 열어 볼 까닭 — 대표님 11-26)
    final w = walk;
    final wj = w?.nowJudge;
    if (w != null && wj != null && !onlyCats) {
      final b = w.best;
      return card(
        kicker: '오늘의 산책',
        big: '지금 산책 ${kWalkShort[wj.level]}\n${b == null ? '내일을 미리 볼까요' : '추천 ${runText(b)}'}',
        sub: wj.why.isEmpty ? (w.tips.isEmpty ? '' : w.tips.first.$2) : wj.why.take(2).join(' · '),
        btn: '시간별·팁 보기',
        onTap: onWalk,
        icon: 'weather',
      );
    }
    final h = nearHosp;
    return card(
      kicker: '가까운 동물병원',
      big: h == null ? (loaded ? '응급·24시\n동물병원 찾기' : '찾고 있어요') : h.$1.name,
      sub: h == null ? '' : '${complex.name}에서 ${distText(h.$2)} · 밤·주말엔 24시 병원을 먼저 보여 드려요',
      btn: '응급·24시 병원 보기',
      onTap: onEmergency,
      icon: 'hosp',
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
