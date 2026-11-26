// 반려동물 추천 영상 (대표님 11-26) — 반려동물 테마 방
// 훈련사·수의사 채널의 영상을 장르(주제)별로 묶어, 검색어 고민 없이 주제만 누르면 바로 보게.
// 자료: web/data/pet/videos.json (collector/features/pet.py 가 채널 RSS 로 하루에 모음)
// 지킬 것: 「추천 영상 · 출처: ○○ 채널」까지만 — 특정인을 앞세우지 않음 / 제목·썸네일은 유튜브가 주는 그대로 /
//          영상은 받거나 저장하지 않음 (유튜브 공식 화면에서 재생 → 광고·조회수는 원래 채널 몫)
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'guide.dart' show stageOf;
import 'kids.dart';

class PetVideo {
  final String v, t, ch, d;
  final bool short, embed;
  final List<String> g;
  final int rk;
  PetVideo(this.v, this.t, this.ch, this.d, this.short, this.embed, this.g, this.rk);
  static PetVideo? fromJson(dynamic j) {
    if (j is! Map || j['v'] == null) return null;
    return PetVideo('${j['v']}', '${j['t'] ?? ''}', '${j['ch'] ?? ''}', '${j['d'] ?? ''}', j['s'] == true, j['e'] != false,
        [for (final x in (j['g'] as List? ?? const [])) '$x'], (j['rk'] as num?)?.toInt() ?? 50);
  }

  // 유튜브가 주는 썸네일 그대로 (16:9)
  String get thumb => 'https://i.ytimg.com/vi/$v/mqdefault.jpg';
  String get url => 'https://www.youtube.com/watch?v=$v';
}

class VideoGenre {
  final String id, name, pet; // pet: dog · cat · both
  const VideoGenre(this.id, this.name, this.pet);
}

class PetVideos {
  final List<VideoGenre> genres;
  final Map<String, String> chName; // 채널 key → 유튜브 채널 이름
  final List<PetVideo> items;
  final String note, updated;
  PetVideos(this.genres, this.chName, this.items, this.note, this.updated);

  List<PetVideo> of(String gid) {
    final l = items.where((x) => x.g.contains(gid)).toList();
    l.sort((a, b) {
      final r = a.rk.compareTo(b.rk);
      return r != 0 ? r : b.d.compareTo(a.d);
    });
    return l;
  }

  String source(PetVideo x) => chName[x.ch] ?? '';
}

Future<PetVideos?>? _videos;
DateTime? _videosAt;

Future<PetVideos?> loadVideos({bool force = false}) {
  final old = _videosAt;
  if (force || _videos == null || (old != null && DateTime.now().difference(old).inMinutes > 60)) {
    _videosAt = DateTime.now();
    _videos = () async {
      final j = await getJson('${dataBase}pet/videos.json');
      if (j is! Map) return null;
      final items = [for (final x in (j['items'] as List? ?? const [])) PetVideo.fromJson(x)].whereType<PetVideo>().toList();
      return PetVideos(
        [for (final g in (j['genres'] as List? ?? const [])) if (g is Map) VideoGenre('${g['id']}', '${g['name']}', '${g['pet'] ?? 'both'}')],
        {for (final c in (j['channels'] as List? ?? const [])) if (c is Map) '${c['key']}': '${c['name'] ?? ''}'},
        items,
        '${j['note'] ?? ''}',
        '${j['updated'] ?? ''}',
      );
    }();
    _videos!.then((v) {
      if (v == null) _videos = null; // 실패하면 다음에 다시
    });
  }
  return _videos!;
}

/// 우리 아이에게 맞는 장르를 앞으로 (노령 → 노견·노묘, 어린 시기 → 처음 키울 때, 고양이 → 고양이 장르)
List<VideoGenre> genresFor(PetVideos d, Kid? k) {
  final list = d.genres.where((g) => d.items.any((x) => x.g.contains(g.id))).toList();
  if (k == null) return list;
  final pet = k.kind == '고양이' ? 'cat' : (k.kind == '강아지' ? 'dog' : '');
  final st = stageOf(k);
  int score(VideoGenre g) {
    var s = 0;
    if (st == 'senior' && g.id == 'senior') s += 10;
    if (st == 'baby' && g.id == 'first') s += 10;
    if (pet.isNotEmpty && g.pet == pet) s += 5;
    if (pet.isNotEmpty && g.pet != 'both' && g.pet != pet) s -= 20; // 다른 종 장르는 맨 뒤로
    return s;
  }

  final idx = {for (var i = 0; i < list.length; i++) list[i].id: i};
  list.sort((a, b) {
    final r = score(b).compareTo(score(a));
    return r != 0 ? r : idx[a.id]!.compareTo(idx[b.id]!);
  });
  return list;
}

/// 재생: 유튜브 공식 화면에서 (퍼가기 막힌 영상은 유튜브 앱·사이트로)
Future<void> playVideo(PetVideo x) => openUrl(x.url, inApp: x.embed);

String _date(String d) => d.length >= 10 ? '${int.tryParse(d.substring(5, 7)) ?? ''}월 ${int.tryParse(d.substring(8, 10)) ?? ''}일' : '';

// ---------------- 반려동물 첫 화면 띠: 장르 칩 + 영상 가로 카드 ----------------

class PetVideoStrip extends StatefulWidget {
  final Complex complex;
  const PetVideoStrip({super.key, required this.complex});
  @override
  State<PetVideoStrip> createState() => _PetVideoStripState();
}

class _PetVideoStripState extends State<PetVideoStrip> {
  PetVideos? d;
  String? gid;

  @override
  void initState() {
    super.initState();
    loadVideos().then((v) {
      if (mounted) setState(() => d = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dd = d;
    if (dd == null || dd.items.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<List<Kid>>(
      valueListenable: kids,
      builder: (context, ks, _) {
        final gs = genresFor(dd, ks.isEmpty ? null : ks.first);
        if (gs.isEmpty) return const SizedBox.shrink();
        final g = gs.firstWhere((x) => x.id == gid, orElse: () => gs.first);
        final list = dd.of(g.id).take(8).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: MixTitle('주제별', '추천 영상', size: 15)),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetVideoPage(complex: widget.complex, start: g.id))),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Text('전체 보기', style: TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w600))),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final x in gs) ...[
                _GenreChip(x.name, on: x.id == g.id, onTap: () => setState(() => gid = x.id)),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _VideoCard(x: list[i], source: dd.source(list[i]), width: 212),
            ),
          ),
        ]);
      },
    );
  }
}

// 장르 칩 — 작고 촘촘하게 (반복 칩은 회색, 고른 것만 파랑)
class _GenreChip extends StatelessWidget {
  final String text;
  final bool on;
  final VoidCallback onTap;
  const _GenreChip(this.text, {required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: on ? kInk : Colors.white,
            border: Border.all(color: on ? kInk : kLine),
          ),
          child: Text(text, style: TextStyle(fontSize: 12.5, color: on ? Colors.white : kInk, fontWeight: on ? FontWeight.w700 : FontWeight.w500, letterSpacing: -0.3)),
        ),
      );
}

// 썸네일 (유튜브 그대로) + 재생 표시 + 쇼츠 표시
class _Thumb extends StatelessWidget {
  final PetVideo x;
  final double r;
  final bool big;
  const _Thumb({required this.x, this.r = 10, this.big = false});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: const Color(0xFFEFF1F5)),
            Image.network(x.thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Center(
              child: Container(
                width: big ? 52 : 38,
                height: big ? 36 : 26,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(big ? 10 : 8)),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: big ? 26 : 20),
              ),
            ),
            if (x.short)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(5)),
                  child: const Text('쇼츠', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      );
}

class _VideoCard extends StatelessWidget {
  final PetVideo x;
  final String source;
  final double width;
  const _VideoCard({required this.x, required this.source, required this.width});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => playVideo(x),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Thumb(x: x),
            const SizedBox(height: 7),
            Text(x.t, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.35, height: 1.35)),
            const SizedBox(height: 3),
            Text(source.isEmpty ? '추천 영상' : '출처: $source 채널', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
          ]),
        ),
      );
}

// ---------------- 전체 화면 ----------------

class PetVideoPage extends StatefulWidget {
  final Complex complex;
  final String? start;
  const PetVideoPage({super.key, required this.complex, this.start});
  @override
  State<PetVideoPage> createState() => _PetVideoPageState();
}

class _PetVideoPageState extends State<PetVideoPage> {
  PetVideos? d;
  bool loading = true;
  String? gid;
  int kidIdx = 0;

  @override
  void initState() {
    super.initState();
    gid = widget.start;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    await loadKids();
    final v = await loadVideos(force: force);
    if (!mounted) return;
    setState(() {
      d = v;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dd = d;
    return DetailPage(
      title: '추천 영상',
      icon: 'pet',
      white: false,
      body: loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : (dd == null || dd.items.isEmpty)
              ? Padding(padding: const EdgeInsets.all(kPad), child: Text('영상을 모으고 있어요. 잠시 뒤 다시 열어 주세요.', style: T.body))
              : RefreshIndicator(onRefresh: () => _load(force: true), child: _body(dd)),
    );
  }

  Widget _body(PetVideos dd) {
    final ks = kids.value;
    final kid = ks.isEmpty ? null : ks[kidIdx.clamp(0, ks.length - 1)];
    final gs = genresFor(dd, kid);
    final g = gs.firstWhere((x) => x.id == gid, orElse: () => gs.first);
    final list = dd.of(g.id);
    final top = list.first;
    final rest = list.skip(1).toList();
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > 640;
      return ListView(padding: const EdgeInsets.fromLTRB(0, 16, 0, 30), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                kid == null ? const MixTitle('궁금한 주제를', '눌러 보세요', size: 16) : MixTitle(kid.name, '에게 맞는 주제부터', size: 16),
                const SizedBox(height: 3),
                Text(kid == null ? '훈련사·수의사 채널의 볼 만한 영상을 주제별로 모았어요' : '훈련사·수의사 채널 영상 · ${kid.kind}${stageOf(kid) == 'senior' ? ' · 노령' : stageOf(kid) == 'baby' ? ' · 어린 시기' : ''}', style: T.small),
              ]),
            ),
            if (ks.length > 1)
              InkWell(
                onTap: () => setState(() {
                  kidIdx = (kidIdx + 1) % ks.length;
                  gid = null;
                }),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text('다른 아이', style: TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w600))),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: kPad), children: [
            for (final x in gs) ...[
              _GenreChip(x.name, on: x.id == g.id, onTap: () => setState(() => gid = x.id)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        // 맨 앞 영상은 크게
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: () => playVideo(top),
            child: Container(
              decoration: cardBox(),
              padding: const EdgeInsets.all(10),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: box.maxWidth * 0.48, child: _Thumb(x: top, big: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _TopText(x: top, source: dd.source(top), genre: g.name)),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Thumb(x: top, big: true),
                      const SizedBox(height: 10),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _TopText(x: top, source: dd.source(top), genre: g.name)),
                    ]),
            ),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPad),
            child: Container(
              decoration: cardBox(),
              child: Column(children: [
                for (var i = 0; i < rest.length; i++) _Row(x: rest[i], source: dd.source(rest[i]), last: i == rest.length - 1),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPad),
          child: Text('추천 영상 · ${dd.note}', style: T.tiny),
        ),
      ]);
    });
  }
}

class _TopText extends StatelessWidget {
  final PetVideo x;
  final String source, genre;
  const _TopText({required this.x, required this.source, required this.genre});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$genre 추천 영상', style: const TextStyle(fontSize: 11.5, color: kBlue, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(x.t, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.35)),
        const SizedBox(height: 5),
        Text([if (source.isNotEmpty) '출처: $source 채널', _date(x.d)].where((s) => s.isNotEmpty).join(' · '), style: T.small),
        if (!x.embed) ...[const SizedBox(height: 4), const Text('유튜브에서 보기', style: TextStyle(fontSize: 11.5, color: kSub))],
      ]);
}

class _Row extends StatelessWidget {
  final PetVideo x;
  final String source;
  final bool last;
  const _Row({required this.x, required this.source, required this.last});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => playVideo(x),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: kLine))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 128, child: _Thumb(x: x, r: 8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.t, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.35, height: 1.35)),
                const SizedBox(height: 4),
                Text([if (source.isNotEmpty) '출처: $source 채널', _date(x.d)].where((s) => s.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                if (!x.embed) ...[const SizedBox(height: 2), const Text('유튜브에서 보기', style: TextStyle(fontSize: 11, color: kSub))],
              ]),
            ),
          ]),
        ),
      );
}
