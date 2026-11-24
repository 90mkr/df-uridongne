// 주변 행사·축제 화면 (행사 담당: 본부, 대표님 요청 11-24)
// 첫 화면은 지도: 행사 위치에 작은 표시, 겹치면 숫자 묶음(누르면 확대). 위쪽 거르기(언제·종류·거리) · 「목록」 단추
// 행사를 누르면 바텀시트: 사진 · 기간 · 시간 · 장소 · 요금 · 설명 · 길안내 · 공유 · 일정에 담기 · 행사장 근처 콕플 맛집 3곳
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/dnmap.dart';
import '../../core/fb.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../phonebook/data.dart' as pb;
import 'data.dart';
import 'post.dart';

const kEvColor = {'축제': Color(0xFFFF7A59), '공연': Color(0xFF7B6CF0), '전시': Color(0xFF2EA36B), '동네 소식': Color(0xFF2F6BFF)};

class EventsPage extends StatefulWidget {
  final Complex c;
  const EventsPage({super.key, required this.c});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final ctl = DnMapCtl();
  List<Ev> all = [];
  bool loading = true, listView = false;
  EvWhen? when; // null = 전체 기간
  String? kind; // null = 전체
  double km = 30;
  double zoom = 11;
  int pending = 0;
  final Map<String, ui.Image> pics = {}; // 지도 상자용 작은 사진 (미리 풀어 둠 — 네이버 지도는 상자를 그림으로 한 번 찍기 때문)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await autoEvents(widget.c.areaId);
    final l = await localEvents(widget.c);
    final p = isAdmin ? (await pendingPosts()).length : 0;
    if (!mounted) return;
    setState(() {
      all = [...l, ...a]..sort((x, y) => x.start.compareTo(y.start));
      pending = p;
      loading = false;
    });
    _loadPics();
    final pts = [widget.c.pos, for (final e in all) e.pos];
    if (pts.length > 1) Future.delayed(const Duration(milliseconds: 700), () => ctl.fit(pts, const EdgeInsets.fromLTRB(50, 60, 50, 110), maxZoom: 15));
  }

  Future<void> _loadPics() async {
    for (final e in all.take(60)) {
      if (!mounted) return;
      if (pics.containsKey(e.id)) continue;
      try {
        Uint8List? b;
        if (e.thumbs.isNotEmpty) {
          b = base64Decode(e.thumbs.first);
        } else if (e.img.isNotEmpty && !kIsWeb) {
          final r = await http.get(Uri.parse(e.img)).timeout(const Duration(seconds: 12));
          if (r.statusCode == 200) b = r.bodyBytes;
        }
        if (b == null) continue;
        final codec = await ui.instantiateImageCodec(b, targetWidth: 120);
        final f = await codec.getNextFrame();
        if (mounted) setState(() => pics[e.id] = f.image);
      } catch (_) {}
    }
  }

  List<Ev> get shown {
    final now = DateTime.now();
    final r = when == null ? null : whenRange(when!, now);
    return all.where((e) {
      if (kind != null && e.kind != kind) return false;
      if (meters(widget.c.pos, e.pos) > km * 1000) return false;
      if (r != null && !e.overlaps(r.$1, r.$2)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = shown;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('주변 행사·축제', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          if (isAdmin && pending > 0)
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovePage()));
                _load();
              },
              child: Text('승인 대기 $pending', style: const TextStyle(color: Color(0xFFE5484D), fontWeight: FontWeight.w800)),
            ),
          TextButton.icon(
            onPressed: () async {
              final ok = await openPost(context, widget.c);
              if (ok == true && mounted) toast(context, '보냈어요. 확인 뒤 공개돼요');
            },
            icon: const Icon(Icons.campaign_outlined, size: 19, color: kBlue),
            label: const Text('행사 알리기', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Column(children: [
        _filters(),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: listView ? _list(l) : _map(l)),
            if (loading) const Center(child: CircularProgressIndicator(color: kBlue)),
            if (!loading && l.isEmpty)
              Positioned(
                left: kPad,
                right: kPad,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: cardBox(),
                  child: Text(km < 30 || when != null || kind != null ? '조건에 맞는 행사가 없어요. 거리를 넓혀 보세요.' : '지금 근처에 알려진 행사가 없어요. 「행사 알리기」로 동네 소식을 올려 주세요.',
                      style: T.small, textAlign: TextAlign.center),
                ),
              ),
            // 지도 ↔ 목록
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: kInk,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => listView = !listView),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(listView ? Icons.map_outlined : Icons.view_agenda_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(listView ? '지도로 보기' : '목록 ${l.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String t, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChipBox(t, on: on, onTap: tap),
      );

  Widget _filters() => Container(
        color: kBg,
        padding: const EdgeInsets.fromLTRB(kPad, 2, 0, 8),
        child: Column(children: [
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chip('전체 기간', when == null, () => setState(() => when = null)),
              _chip('이번 주', when == EvWhen.week, () => setState(() => when = EvWhen.week)),
              _chip('이번 주말', when == EvWhen.weekend, () => setState(() => when = EvWhen.weekend)),
              _chip('이번 달', when == EvWhen.month, () => setState(() => when = EvWhen.month)),
              const SizedBox(width: 8),
              for (final k in [3.0, 10.0, 30.0]) _chip('${k.toInt()}km', km == k, () => setState(() => km = k)),
              const SizedBox(width: kPad),
            ]),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chip('모든 종류', kind == null, () => setState(() => kind = null)),
              for (final k in kEvKinds) _chip(k, kind == k, () => setState(() => kind = k)),
              const SizedBox(width: kPad),
            ]),
          ),
        ]),
      );

  // ---- 지도: 가까운 것끼리 숫자 묶음 ----
  Widget _map(List<Ev> l) {
    final cell = 0.0024 * math.pow(2, 16 - zoom); // 화면에서 약 160px (상자 크기)
    final groups = <String, List<Ev>>{};
    for (final e in l) {
      groups.putIfAbsent('${(e.pos.latitude / cell).floor()}_${(e.pos.longitude / cell).floor()}', () => []).add(e);
    }
    final marks = <DnMark>[];
    for (final g in groups.entries) {
      final es = g.value;
      if (es.length == 1) {
        final e = es.first;
        marks.add(DnMark(
          id: e.id,
          pos: e.pos,
          key: 'e|${e.id}|${pics[e.id] != null}',
          size: const Size(_Mark.w, _Mark.h + 7),
          child: _Mark(e, pics[e.id]),
          onTap: () => showEvent(context, e, widget.c),
        ));
      } else {
        final lat = es.map((e) => e.pos.latitude).reduce((a, b) => a + b) / es.length;
        final lng = es.map((e) => e.pos.longitude).reduce((a, b) => a + b) / es.length;
        marks.add(DnMark(
          id: 'g${g.key}',
          pos: LatLng(lat, lng),
          key: 'g|${es.first.id}|${es.length}|${pics[es.first.id] != null}',
          size: const Size(74, 74),
          child: _Bunch(es.first, es.length, pics[es.first.id]),
          onTap: () => ctl.fit([for (final e in es) e.pos], const EdgeInsets.all(70), maxZoom: 16),
        ));
      }
    }
    return DnMap(
      center: widget.c.pos,
      zoom: 11,
      ctl: ctl,
      marks: marks,
      onIdle: (center, z, bounds, gesture) {
        if ((z - zoom).abs() >= 0.5) setState(() => zoom = z);
      },
    );
  }

  // ---- 목록: 사진이 돋보이게 (큰 사진 카드 · 사진 없는 동네 소식은 색 띠) ----
  Widget _list(List<Ev> l) => ListView(
        padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 80),
        children: [
          for (final e in l) ...[_EvCard(e: e, c: widget.c, onTap: () => showEvent(context, e, widget.c)), const SizedBox(height: 14)],
        ],
      );
}

// 지도 표시: 사진 + 이름이 든 작은 상자 (누르기 전부터 무슨 행사인지 보이게)
class _Mark extends StatelessWidget {
  final Ev e;
  final ui.Image? pic;
  const _Mark(this.e, this.pic);
  static const w = 150.0, h = 58.0;
  @override
  Widget build(BuildContext context) {
    final col = kEvColor[e.kind] ?? kBlue;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDE1E8)),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: ClipRRect(borderRadius: BorderRadius.circular(7), child: SizedBox(width: 48, height: 48, child: _markPic(e, pic))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 7, 0),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.liveAt(DateTime.now()) ? '${e.kind} · 진행 중' : '${e.kind} · ${e.start.month}.${e.start.day}~',
                    maxLines: 1, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: col, height: 1.2)),
                const SizedBox(height: 1),
                Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kInk, height: 1.2, letterSpacing: -0.3)),
              ]),
            ),
          ),
        ]),
      ),
      CustomPaint(size: const Size(12, 7), painter: _Tail()),
    ]);
  }
}

Widget _markPic(Ev e, ui.Image? pic) {
  if (pic != null) return RawImage(image: pic, fit: BoxFit.cover);
  if (kIsWeb && e.img.isNotEmpty) return Image.network(e.img, fit: BoxFit.cover, webHtmlElementStrategy: WebHtmlElementStrategy.prefer);
  final col = kEvColor[e.kind] ?? kBlue;
  return ColoredBox(color: col.withValues(alpha: 0.14), child: const Center(child: LineIcon('event', size: 28)));
}

class _Tail extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawPath(p, Paint()..color = Colors.white);
    c.drawPath(ui.Path()..moveTo(0, 0)..lineTo(s.width / 2, s.height)..lineTo(s.width, 0), Paint()..color = const Color(0xFFDDE1E8)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_) => false;
}

// 겹친 행사 묶음: 첫 행사 사진 + 개수
class _Bunch extends StatelessWidget {
  final Ev first;
  final int n;
  final ui.Image? pic;
  const _Bunch(this.first, this.n, this.pic);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 74,
        height: 74,
        child: Stack(children: [
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)]),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(borderRadius: BorderRadius.circular(9), child: _markPic(first, pic)),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 26),
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(color: const Color(0xFFFF7A59), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white, width: 2)),
              alignment: Alignment.center,
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5, height: 1)),
            ),
          ),
        ]),
      );
}

Widget evPhoto(Ev e, {double? h, BoxFit fit = BoxFit.cover, int i = 0, bool full = false}) {
  Widget ph() => Container(
        height: h,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [(kEvColor[e.kind] ?? kBlue).withValues(alpha: 0.85), (kEvColor[e.kind] ?? kBlue).withValues(alpha: 0.55)])),
        alignment: Alignment.center,
        child: Text(e.kind, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      );
  if (e.img.isNotEmpty && i == 0) return Image.network(e.img, height: h, width: double.infinity, fit: fit, webHtmlElementStrategy: WebHtmlElementStrategy.prefer, errorBuilder: (_, __, ___) => ph());
  final list = full && e.photos.isNotEmpty ? e.photos : e.thumbs;
  if (list.length > i) {
    try {
      return Image.memory(base64Decode(list[i]), height: h, width: double.infinity, fit: fit);
    } catch (_) {}
  }
  return ph();
}

class _EvCard extends StatelessWidget {
  final Ev e;
  final Complex c;
  final VoidCallback onTap;
  const _EvCard({required this.e, required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Ink(
          decoration: cardBox(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Stack(children: [
                AspectRatio(aspectRatio: 16 / 9, child: evPhoto(e)),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Row(children: [
                    _Tag(e.kind, kEvColor[e.kind] ?? kBlue),
                    if (e.liveAt(now)) ...[const SizedBox(width: 5), const _Tag('진행 중', Color(0xFF17181C))],
                  ]),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.3)),
                  const SizedBox(height: 4),
                  Text('${e.period}  ·  ${distText(meters(c.pos, e.pos))}${e.free ? '  ·  무료' : ''}', style: const TextStyle(fontSize: 12.5, color: kSub)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String t;
  final Color col;
  const _Tag(this.t, this.col);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
}

// ---------------- 행사 바텀시트 ----------------
Future<void> showEvent(BuildContext context, Ev e, Complex c) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      clipBehavior: Clip.antiAlias,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, sc) => _EvSheet(e: e, c: c, scroll: sc),
      ),
    );

class _EvSheet extends StatefulWidget {
  final Ev e;
  final Complex c;
  final ScrollController scroll;
  const _EvSheet({required this.e, required this.c, required this.scroll});
  @override
  State<_EvSheet> createState() => _EvSheetState();
}

class _EvSheetState extends State<_EvSheet> {
  List<pb.Shop> food = [];
  int photo = 0;

  @override
  void initState() {
    super.initState();
    pb.shopsOf(widget.c.areaId).then((all) {
      final e = widget.e;
      final l = all.where((s) => s.kok != null && meters(e.pos, s.pos) <= 2000).toList()
        ..sort((a, b) => (b.kok!.grate).compareTo(a.kok!.grate));
      if (mounted) setState(() => food = l.take(3).toList());
    });
  }

  String _cal(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final nPhotos = e.img.isNotEmpty ? 1 : math.max(1, e.photos.isNotEmpty ? e.photos.length : e.thumbs.length);
    return ListView(controller: widget.scroll, padding: EdgeInsets.zero, children: [
      Stack(children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            itemCount: nPhotos,
            onPageChanged: (i) => setState(() => photo = i),
            itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
              ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: evPhoto(e, h: 250, i: i, full: true)),
              const ColoredBox(color: Color(0x33000000)),
              evPhoto(e, h: 250, i: i, full: true, fit: BoxFit.contain),
            ]),
          ),
        ),
        Positioned(top: 8, left: 0, right: 0, child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(2))))),
        if (nPhotos > 1)
          Positioned(
            bottom: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(12)),
              child: Text('${photo + 1}/$nPhotos', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ),
        if (e.src.isNotEmpty)
          Positioned(
            bottom: 10,
            left: 12,
            child: Text('사진·자료 ${e.src}', style: const TextStyle(color: Colors.white, fontSize: 10.5, shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)])),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Tag(e.kind, kEvColor[e.kind] ?? kBlue),
          const SizedBox(height: 8),
          Text(e.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.3)),
          const SizedBox(height: 14),
          _Info(Icons.event_rounded, e.period + (e.time.isNotEmpty ? '  ·  ${e.time}' : '')),
          _Info(Icons.place_outlined, '${e.place}  ·  ${distText(meters(widget.c.pos, e.pos))}'),
          if (e.fee.isNotEmpty || e.local) _Info(Icons.confirmation_number_outlined, e.fee.isEmpty ? '무료' : e.fee),
          if (e.tel.isNotEmpty) _Info(Icons.call_outlined, e.tel.replaceAll(RegExp('<[^>]*>'), ' ')),
          if (e.desc.isNotEmpty) ...[const SizedBox(height: 10), Text(e.desc, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF3A3F4B)))],
          if (!e.local)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(10)),
              child: Text('${e.src.isEmpty ? '공공' : e.src} 자료예요. 시간·요금은 바뀔 수 있으니 가기 전에 문의처로 확인해 주세요.', style: T.small),
            ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Btn('길안내', primary: true, h: 46, onTap: () => startNav(context, name: e.title, lat: e.pos.latitude, lng: e.pos.longitude))),
            const SizedBox(width: 8),
            Expanded(
              child: Btn('공유', h: 46, onTap: () {
                Clipboard.setData(ClipboardData(text: '${e.title}\n${e.period}${e.time.isNotEmpty ? ' ${e.time}' : ''}\n${e.place}\n— 우리동네 앱'));
                toast(context, '행사 정보를 복사했어요. 붙여 넣어 보내세요');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Btn('일정에 담기', h: 46, onTap: () {
                final q = Uri(queryParameters: {
                  'action': 'TEMPLATE',
                  'text': e.title,
                  'dates': '${_cal(e.start)}/${_cal(e.end.add(const Duration(days: 1)))}',
                  'location': e.place,
                  'details': '우리동네 앱 · ${e.src}',
                }).query;
                openUrl('https://calendar.google.com/calendar/render?$q');
              }),
            ),
          ]),
          if (food.isNotEmpty) ...[
            const SizedBox(height: 26),
            const MixTitle('행사장 근처', '콕플 맛집', size: 16),
            const SizedBox(height: 10),
            for (final s in food)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: cardBox(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: s.kok!.thumb.isNotEmpty
                          ? Image.network(s.kok!.thumb, width: 64, height: 42, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 42))
                          : const SizedBox(width: 64, height: 42, child: Center(child: LineIcon('food', size: 26))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                        Text('${s.sub} · 행사장에서 ${distText(meters(e.pos, s.pos))}${s.kok!.grate > 0 ? ' · ★${s.kok!.grate}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
                      ]),
                    ),
                    IconButton(onPressed: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng), icon: const Icon(Icons.directions_rounded, color: kSub)),
                  ]),
                ),
              ),
          ],
          if (e.local && e.name.isNotEmpty) ...[const SizedBox(height: 14), Text('알려 준 이웃: ${e.name}', style: T.tiny)],
        ]),
      ),
    ]);
  }
}

class _Info extends StatelessWidget {
  final IconData i;
  final String t;
  const _Info(this.i, this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: kSub),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 14, height: 1.35))),
        ]),
      );
}

// ---------------- 관리자 승인 ----------------
class ApprovePage extends StatefulWidget {
  const ApprovePage({super.key});
  @override
  State<ApprovePage> createState() => _ApprovePageState();
}

class _ApprovePageState extends State<ApprovePage> {
  List<Ev>? l;
  @override
  void initState() {
    super.initState();
    pendingPosts().then((v) {
      if (mounted) setState(() => l = v);
    });
  }

  Future<void> _set(Ev e, String st) async {
    final ok = await setPostState(e.id, st);
    if (!mounted) return;
    if (!ok) return toast(context, '처리하지 못했어요');
    setState(() => l = l!.where((x) => x.id != e.id).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kBg, elevation: 0, surfaceTintColor: Colors.transparent, title: const Text('행사 승인', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
        body: l == null
            ? const Center(child: CircularProgressIndicator(color: kBlue))
            : l!.isEmpty
                ? const Center(child: Text('기다리는 글이 없어요', style: T.small))
                : ListView(padding: const EdgeInsets.all(kPad), children: [
                    for (final e in l!)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: cardBox(),
                        clipBehavior: Clip.antiAlias,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SizedBox(height: 160, child: evPhoto(e, h: 160, full: true)),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                              Text('${e.period} ${e.time} · ${e.place}', style: T.small),
                              Text('${e.scope == 'apt' ? '우리 단지만' : '근처 단지 모두'} · ${e.name}', style: T.tiny),
                              if (e.desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e.desc, style: T.small)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: Btn('반려', h: 40, onTap: () => _set(e, 'no'))),
                                const SizedBox(width: 10),
                                Expanded(child: Btn('승인', primary: true, h: 40, onTap: () => _set(e, 'ok'))),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
      );
}
