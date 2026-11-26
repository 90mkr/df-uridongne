// 우리 동네 반려동물 — 테마 첫 화면 (대표님 11-25: 위에 탭을 늘어놓지 말고, 안에 앱 목록처럼 칸을 한 번 더)
// 맨 위: 「오늘의 반려 생활」 카드 (산책·체감·미세먼지·우리 아이 할 일, 대표님 11-26) · 응급 병원은 칸 목록 아래 한 줄
// 그 아래: 칸 목록 (칸마다 독립 전문 화면) · 우리 아이 줄 · 서버 배너 (web/data/pet/promo.json, 앱 업데이트 없이 바꿈)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/home_layout.dart';
import '../../core/icons.dart';
import '../../core/remote.dart';
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
  Map<PetKind, int> count = {}; // 3km 안
  Map<PetKind, int> wide = {}; // 3km 안이 5곳 미만인 칸은 8km 안 (안쪽 화면과 같은 기준)
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
    // 8km까지 한 번에 받고, 칸 숫자는 안쪽 화면과 똑같이 셈 (3km 안 5곳 미만이면 8km까지 넓혀서)
    final r = await Future.wait([petNear(widget.complex.pos, km: 8), getJson('${dataBase}pet/promo.json')]);
    final v8 = r[0] as List<(PetPlace, double)>;
    final v = v8.where((x) => x.$2 <= 3000).toList();
    final p = r[1];
    if (!mounted) return;
    setState(() {
      count = {for (final k in PetKind.values) k: v.where((x) => x.$1.kind == k).length};
      wide = {
        for (final k in PetKind.values)
          if ((count[k] ?? 0) < 5) k: v8.where((x) => x.$1.kind == k).length,
      };
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
    String cnt(PetKind k) => !loaded ? '' : (wide.containsKey(k) ? '8km ${wide[k]}곳' : '${count[k] ?? 0}곳');
    final wl = walk?.nowJudge?.level;
    final tiles = <(String, String, String, Widget Function())>[
      ('pet_walk', '오늘의 산책', wl == null ? '산책 지수' : kWalkShort[wl], () => PetWalkPage(complex: c)),
      ('pet_guide', '생활 가이드', '건강·먹이·훈련', () => PetGuidePage(complex: c)),
      ('pet_hosp', '동물병원', cnt(PetKind.hosp), () => PetPlacesPage(complex: c, kind: PetKind.hosp)),
      ('pet_groom', '미용', cnt(PetKind.groom), () => PetPlacesPage(complex: c, kind: PetKind.groom)),
      ('pet_hotel', '호텔·돌봄', cnt(PetKind.hotel), () => PetPlacesPage(complex: c, kind: PetKind.hotel)),
      ('pet_shop', '용품', cnt(PetKind.shop), () => PetPlacesPage(complex: c, kind: PetKind.shop)),
      ('pet_pharm', '동물약국', cnt(PetKind.pharm), () => PetPlacesPage(complex: c, kind: PetKind.pharm)),
      ('pet_trip', '같이 갈 곳', '여행·카페', () => PetTripPage(complex: c)),
      ('pet_kids', '우리 아이 수첩', kids.value.isEmpty ? '접종 알림' : '${kids.value.length}마리', () => const PetKidsPage()),
    ];
    return DetailPage(
      title: '우리 동네 반려동물',
      icon: 'pet',
      white: false,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
          PetTodayCard(
              walk: walk,
              onWalk: () => _go(PetWalkPage(complex: c)),
              onKids: () => _go(const PetKidsPage()),
              onGuide: () => _go(PetGuidePage(complex: c))),
          const SizedBox(height: 8),
          const _HomeToggle(),
          const SizedBox(height: 14),
          const MixTitle('반려동물', '생활', size: 15),
          const SizedBox(height: 10),
          Container(
            decoration: cardBox(),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: LayoutBuilder(builder: (ctx, box) {
              final per = box.maxWidth > 520 ? 9 : 5; // 대표님 시안: 휴대폰 5칸씩 (5+4)
              final w = box.maxWidth / per;
              return Wrap(children: [
                for (final t in tiles)
                  SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _go(t.$4()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        child: Column(children: [
                          Image.asset('assets/art/${t.$1}.png', width: 46, height: 46, filterQuality: FilterQuality.medium),
                          const SizedBox(height: 6),
                          // 작은 휴대폰에서도 잘리지 않게 줄여서 맞춤
                          FittedBox(fit: BoxFit.scaleDown, child: Text(t.$2, maxLines: 1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: -0.4))),
                          FittedBox(fit: BoxFit.scaleDown, child: Text(t.$3, maxLines: 1, style: T.tiny)),
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
          Text('${c.name} 둘레 3km 기준 (드문 칸은 8km) · 소상공인 상가정보·인허가 자료', style: T.tiny),
        ]),
      ),
    );
  }
}

// 맨 위 「오늘의 반려 생활」 — 단지 홈 맨 위 카드처럼 몇 가지 정보를 한눈에 (대표님 11-26)
// 큰 줄: 지금 산책 단계 + 추천 시간 · 작은 칸 넷: 산책 / 체감 / 미세먼지 / 우리 아이 수첩 다음 할 일
class PetTodayCard extends StatelessWidget {
  final WalkDay? walk;
  final VoidCallback onWalk, onKids, onGuide;
  final String? head; // 맨 위 작은 글 앞머리 (홈 배너: 「우리 동네 반려동물」)
  final bool light; // 홈 배너: 흰 카드 (맨 위 파랑 카드와 겹쳐 무겁지 않게)
  const PetTodayCard({super.key, required this.walk, required this.onWalk, required this.onKids, required this.onGuide, this.head, this.light = false});

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

    if (!light) return _hero(context, now, j, best, cats, f, t, dust, kidVal, kidSub);
    return Container(
      decoration: light
          ? cardBox(r: 20)
          : BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1570EA), Color(0xFF0B4DBA)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF0B4DBA).withValues(alpha: 0.16), blurRadius: 18)],
            ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: -14, top: -10, child: light ? const Opacity(opacity: 0.12, child: LineIcon('pet', size: 120)) : LineIcon('pet', size: 120, line: Colors.white.withValues(alpha: 0.16), fill: Colors.white.withValues(alpha: 0.06))),
        Material(
          color: Colors.transparent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: cats ? onGuide : onWalk,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${head ?? '오늘의 반려 생활'} · ${now.month}월 ${now.day}일 ${_wd[now.weekday - 1]}요일', style: TextStyle(fontSize: 12, color: light ? kSub : const Color(0xD9FFFFFF), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: light ? kInk : Colors.white, letterSpacing: -0.7, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: light ? kBlue : const Color(0xE6FFFFFF), fontWeight: light ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _Stat(label: stats[i].$1, value: stats[i].$2, sub: stats[i].$3, onTap: stats[i].$4, light: light)),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }


  // 테마 첫 화면 맨 위 — 대표님 시안 (11-26): 강아지·고양이 배경 그림 + 큰 한 줄 + 추천 시간 알약 + 색 칸 넷
  static const _say = ['좋아요!', '괜찮아요', '짧게만 해요', '쉬어 가요'];
  Widget _hero(BuildContext context, DateTime now, WalkJudge? j, (DateTime, DateTime, int)? best, bool cats, double? f, double? t, String dust, String kidVal, String kidSub) {
    final String lead, hot, pill;
    if (cats) {
      lead = '오늘도 사냥 놀이 ';
      hot = '10분!';
      pill = '짧은 놀이를 하루 여러 번';
    } else if (j == null) {
      lead = '산책하기 좋은 시간을 ';
      hot = '찾는 중';
      pill = '날씨를 살피고 있어요';
    } else {
      lead = '지금 산책하기 ';
      hot = _say[j.level];
      pill = best == null ? '오늘 낮 산책 시간은 지났어요' : '추천 시간  ${runText(best)}';
    }
    final dustLv = walk?.dust ?? 0;
    final cards = <_HeroStat>[
      _HeroStat(Icons.directions_walk_rounded, '산책', j == null ? '-' : kWalkShort[j.level], best == null ? '' : _bestShort(best), const Color(0xFFE8F8EE), j == null || j.level == 0 ? const Color(0xFF16A34A) : (j.level >= 2 ? const Color(0xFFE5484D) : const Color(0xFFD97706)), onWalk),
      _HeroStat(Icons.thermostat_rounded, '체감', f == null ? '-' : '${f.round()}℃', t == null ? '' : '기온 ${t.round()}℃', const Color(0xFFFDEEF0), const Color(0xFFE5484D), onWalk),
      _HeroStat(Icons.air_rounded, '미세먼지', dust.isEmpty ? '-' : dust, '', const Color(0xFFE9F2FF), dustLv >= 3 ? const Color(0xFFE5484D) : kBlue, onWalk),
      _HeroStat(Icons.medical_services_outlined, '우리 아이', kidVal, kidSub, const Color(0xFFF1EEFD), const Color(0xFF6D4AE0), onKids),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0187FD), Color(0xFF1A9DFE)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF0B4DBA).withValues(alpha: 0.14), blurRadius: 18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // 강아지·고양이 (대표님 그림, 왼쪽·아래 가장자리는 파랑에 녹아들게 흐리게 잘라 둠)
        Positioned(
          right: 0,
          top: 0,
          child: LayoutBuilder(builder: (ctx, _) {
            final w = (MediaQuery.of(ctx).size.width - kPad * 2) * 0.47;
            return SizedBox(width: w.clamp(150.0, 300.0), child: artImage('assets/art/pet_hero.png', fit: BoxFit.fitWidth, alignment: Alignment.topRight));
          }),
        ),
        Material(
          color: Colors.transparent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: cats ? onGuide : onWalk,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: FractionallySizedBox(
                  widthFactor: 0.6, // 오른쪽은 강아지·고양이 자리
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${head ?? '오늘의 반려 생활'} · ${now.month}월 ${now.day}일 ${_wd[now.weekday - 1]}요일',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(lead, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.8, height: 1.2)),
                        CustomPaint(
                          foregroundPainter: _Squiggle(),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(hot, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFFFD84D), letterSpacing: -0.8, height: 1.2)),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xCCFFFFFF)), borderRadius: BorderRadius.circular(20), color: const Color(0x1AFFFFFF)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Flexible(child: Text(pill, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: cards[i]),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  static String _bestShort((DateTime, DateTime, int) b) => '${b.$1.hour}~${b.$2.hour}시';
  static String _dustShort(WalkDay d) => d.dust <= 0 ? '' : const ['', '좋음', '보통', '나쁨', '매우나쁨'][d.dust.clamp(0, 4)];
}

class _Stat extends StatelessWidget {
  final String label, value, sub;
  final VoidCallback onTap;
  final bool light;
  const _Stat({required this.label, required this.value, required this.sub, required this.onTap, this.light = false});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(color: light ? const Color(0xFFF3F6FC) : Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, style: TextStyle(fontSize: 10.5, color: light ? kSub : const Color(0xCCFFFFFF), fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: light ? kInk : Colors.white, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 1),
            Text(sub.isEmpty ? ' ' : sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: light ? kSub : const Color(0xB3FFFFFF))),
          ]),
        ),
      );
}


// 맨 위 카드의 색 칸 하나 (아이콘 + 이름 + 값 + 작은 글)
class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color bg, color;
  final VoidCallback onTap;
  const _HeroStat(this.icon, this.label, this.value, this.sub, this.bg, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 6, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 3),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: kInk, fontWeight: FontWeight.w600, letterSpacing: -0.3))),
              ]),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.6, height: 1.1)),
              ),
              const SizedBox(height: 2),
              Text(sub.isEmpty ? ' ' : sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: kSub, letterSpacing: -0.2)),
            ]),
          ),
        ),
      );
}

// 강조 낱말 밑 노란 물결 밑줄
class _Squiggle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 2;
    final p = Path()..moveTo(2, y);
    final n = (size.width / 14).ceil().clamp(2, 12);
    final step = (size.width - 4) / n;
    for (var i = 0; i < n; i++) {
      final x = 2 + step * i;
      p.quadraticBezierTo(x + step / 2, y + (i.isEven ? -3 : 3), x + step, y);
    }
    canvas.drawPath(p, Paint()
      ..color = const Color(0xFFFFD84D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Squiggle o) => false;
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
            Image.asset('assets/art/pet_call.png', width: 40, height: 40, filterQuality: FilterQuality.medium),
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

// 「홈 첫 화면에 띄우기」 — 켜면 단지 홈 맨 위 카드 바로 아래에 「오늘의 반려 생활」 배너 (대표님 11-26)
class _HomeToggle extends StatefulWidget {
  const _HomeToggle();
  @override
  State<_HomeToggle> createState() => _HomeToggleState();
}

class _HomeToggleState extends State<_HomeToggle> {
  @override
  Widget build(BuildContext context) {
    final on = !isHidden('m:pet');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _set(!on),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 0, 2),
        child: Row(children: [
          Expanded(
            child: Text(on ? '홈 첫 화면에 이 카드가 보여요' : '이 카드를 홈 첫 화면에 띄우기',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? kInk : kSub, letterSpacing: -0.3)),
          ),
          Switch.adaptive(value: on, onChanged: _set),
        ]),
      ),
    );
  }

  Future<void> _set(bool v) async {
    if (v) {
      await setHomeCardOn('m:pet');
    } else {
      await setHomeCardOff('m:pet');
    }
    if (!mounted) return;
    setState(() {});
    toast(context, v ? '홈 첫 화면에 띄웠어요' : '홈에서 뺐어요');
  }
}
