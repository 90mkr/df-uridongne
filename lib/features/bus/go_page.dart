// 「어디로 가세요?」 대중교통 길찾기 (대표님 11-26) — 이 폴더는 단지 앞 버스 담당 방만 고침
// 도착지를 찾아 고르면 카카오맵·네이버 지도의 대중교통 길찾기를 출발(우리 단지 또는 지금 내 위치)·도착이 채워진 채로 연다.
// 자주 가는 곳은 이 휴대폰에 저장 (장소 이름·좌표 몇 개 — 사용자가 직접 고른 즐겨찾기).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/kk.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class GoPlace {
  final String name, addr, pid;
  final double lat, lng;
  const GoPlace(this.name, this.addr, this.lat, this.lng, {this.pid = ''});
  Map toJson() => {'n': name, 'a': addr, 'y': lat, 'x': lng, 'p': pid};
  static GoPlace? from(dynamic m) {
    if (m is! Map) return null;
    final y = (m['y'] as num?)?.toDouble(), x = (m['x'] as num?)?.toDouble();
    if (y == null || x == null) return null;
    return GoPlace('${m['n'] ?? ''}', '${m['a'] ?? ''}', y, x, pid: '${m['p'] ?? ''}');
  }
}

const _favKey = 'bus.goPlaces';
const _appKey = 'bus.goApp';

Future<List<GoPlace>> loadGoPlaces() async {
  try {
    final j = jsonDecode(await prefGet(_favKey) ?? '[]');
    return [for (final m in (j as List)) if (GoPlace.from(m) case final p?) p];
  } catch (_) {
    return [];
  }
}

Future<void> _saveGoPlaces(List<GoPlace> l) => prefSet(_favKey, jsonEncode([for (final p in l) p.toJson()]));

double _km(double la1, double lo1, double la2, double lo2) {
  const r = 6371.0;
  final dLa = (la2 - la1) * math.pi / 180, dLo = (lo2 - lo1) * math.pi / 180;
  final a = math.pow(math.sin(dLa / 2), 2) + math.cos(la1 * math.pi / 180) * math.cos(la2 * math.pi / 180) * math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

String _dist(double km) => km < 1 ? '${(km * 1000).round()}m' : '${km < 10 ? km.toStringAsFixed(1) : km.round()}km';

// 대중교통 길찾기 열기 — fromHere: 출발을 「지금 내 위치」로 (지도 앱이 위치를 잡음)
Future<void> openTransit(BuildContext context, Complex c, GoPlace to, {bool fromHere = false, bool reverse = false}) async {
  final saved = await prefGet(_appKey) ?? '';
  if (!context.mounted) return;
  if (saved.isNotEmpty) return _launchTransit(saved, c, to, fromHere: fromHere, reverse: reverse);
  var keep = true;
  await showSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('어느 지도로 길찾기 할까요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 3),
          Text('버스·지하철 길찾기 · 도착 ${reverse ? c.name : to.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kSub)),
          const SizedBox(height: 16),
          Row(children: [
            for (final (i, a) in [('kakao', '카카오맵', const Color(0xFFFFCD00)), ('naver', '네이버 지도', const Color(0xFF03C75A))].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (keep) prefSet(_appKey, a.$1);
                    Navigator.pop(ctx);
                    _launchTransit(a.$1, c, to, fromHere: fromHere, reverse: reverse);
                  },
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: a.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(a.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => set(() => keep = !keep),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(keep ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 19, color: keep ? kBlue : kMute),
                const SizedBox(width: 6),
                const Text('다음부터 이 지도로 바로 열기', style: TextStyle(fontSize: 13, color: kSub)),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<void> _launchTransit(String app, Complex c, GoPlace to, {bool fromHere = false, bool reverse = false}) async {
  // reverse: 그곳 → 우리 단지 (집으로 돌아오기)
  final sName = reverse ? to.name : c.name, sLat = reverse ? to.lat : c.lat, sLng = reverse ? to.lng : c.lng;
  final dName = reverse ? c.name : to.name, dLat = reverse ? c.lat : to.lat, dLng = reverse ? c.lng : to.lng;
  final useStart = !fromHere;
  final sn = Uri.encodeComponent(sName), dn = Uri.encodeComponent(dName);
  final web = useStart
      ? 'https://map.kakao.com/link/by/traffic/$sn,$sLat,$sLng/$dn,$dLat,$dLng'
      : 'https://map.kakao.com/link/to/$dn,$dLat,$dLng';
  if (kIsWeb) return openUrl(web);
  final scheme = app == 'naver'
      ? 'nmap://route/public?${useStart ? 'slat=$sLat&slng=$sLng&sname=$sn&' : ''}dlat=$dLat&dlng=$dLng&dname=$dn&appname=kr.designfeel.dongne'
      : 'kakaomap://route?${useStart ? 'sp=$sLat,$sLng&' : ''}ep=$dLat,$dLng&by=PUBLICTRANSIT';
  try {
    if (await launchUrl(Uri.parse(scheme), mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  await openUrl(web);
}

// ---------------- 버스 화면 위 「어디로 가세요?」 칸 ----------------
class GoBar extends StatefulWidget {
  final Complex c;
  const GoBar({super.key, required this.c});
  @override
  State<GoBar> createState() => _GoBarState();
}

class _GoBarState extends State<GoBar> {
  List<GoPlace> favs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await loadGoPlaces();
    if (mounted) setState(() => favs = l);
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GoPage(c: widget.c)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kLine),
            boxShadow: const [BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 12)],
          ),
          child: const Row(children: [
            Icon(Icons.search_rounded, size: 20, color: kBlue),
            SizedBox(width: 8),
            Text('어디로 가세요?', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            SizedBox(width: 6),
            Expanded(child: Text('버스·지하철 길찾기', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: kMute))),
          ]),
        ),
      ),
      if (favs.isNotEmpty) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => _Chip(favs[i].name, onTap: () => openTransit(context, widget.c, favs[i])),
          ),
        ),
      ],
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String t;
  final VoidCallback onTap;
  const _Chip(this.t, {required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B400)),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ---------------- 찾기 화면 ----------------
class GoPage extends StatefulWidget {
  final Complex c;
  const GoPage({super.key, required this.c});
  @override
  State<GoPage> createState() => _GoPageState();
}

class _GoPageState extends State<GoPage> {
  final q = TextEditingController();
  Timer? _t;
  List<GoPlace> found = [];
  List<GoPlace> favs = [];
  bool busy = false, fromHere = false, searched = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    loadGoPlaces().then((l) => mounted ? setState(() => favs = l) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    q.dispose();
    super.dispose();
  }

  void _typed(String v) {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String v) async {
    final s = v.trim();
    final my = ++_seq;
    if (s.isEmpty) {
      setState(() {
        found = [];
        searched = false;
      });
      return;
    }
    setState(() => busy = true);
    final docs = await kkAll('keyword', {'query': s, 'x': '${widget.c.lng}', 'y': '${widget.c.lat}', 'sort': 'accuracy'}, pages: 1);
    if (!mounted || my != _seq) return;
    setState(() {
      busy = false;
      searched = true;
      found = [
        for (final d in docs)
          if (double.tryParse('${d['y']}') != null)
            GoPlace('${d['place_name'] ?? ''}', '${(d['road_address_name'] ?? '').toString().isNotEmpty ? d['road_address_name'] : d['address_name'] ?? ''}',
                double.parse('${d['y']}'), double.parse('${d['x']}'),
                pid: '${d['id'] ?? ''}')
      ];
    });
  }

  bool _isFav(GoPlace p) => favs.any((f) => (p.pid.isNotEmpty && f.pid == p.pid) || (f.name == p.name && (f.lat - p.lat).abs() < 1e-4));

  Future<void> _toggleFav(GoPlace p) async {
    final l = [...favs];
    if (_isFav(p)) {
      l.removeWhere((f) => (p.pid.isNotEmpty && f.pid == p.pid) || (f.name == p.name && (f.lat - p.lat).abs() < 1e-4));
    } else {
      l.insert(0, p);
      if (l.length > 12) l.removeLast();
    }
    await _saveGoPlaces(l);
    if (mounted) setState(() => favs = l);
  }

  @override
  Widget build(BuildContext context) {
    final list = q.text.trim().isEmpty ? favs : found;
    return DetailPage(
      title: '어디로 가세요?',
      white: true,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 0),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
            child: Column(children: [
              // 출발
              InkWell(
                onTap: () => setState(() => fromHere = !fromHere),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    const _Dot(color: kBlue),
                    const SizedBox(width: 10),
                    const Text('출발', style: TextStyle(fontSize: 12, color: kSub)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(fromHere ? '지금 내 위치' : widget.c.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    ),
                    Text(fromHere ? '우리 단지로 바꾸기' : '내 위치로 바꾸기', style: const TextStyle(fontSize: 11.5, color: kBlue, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              Container(height: 1, color: const Color(0xFFEDF0F4), margin: const EdgeInsets.only(left: 14)),
              // 도착 찾기
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
                child: Row(children: [
                  const _Dot(color: Color(0xFFE8505B)),
                  const SizedBox(width: 10),
                  const Text('도착', style: TextStyle(fontSize: 12, color: kSub)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: q,
                      autofocus: true,
                      onChanged: (v) {
                        setState(() {});
                        _typed(v);
                      },
                      onSubmitted: _search,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: '역·병원·가게·주소 찾기',
                        hintStyle: TextStyle(fontSize: 14, color: kMute, fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (busy)
                    const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6)))
                  else if (q.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        q.clear();
                        _search('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18, color: kMute),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 6),
          child: Row(children: [
            Text(q.text.trim().isEmpty ? '자주 가는 곳' : '찾은 곳', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(kPad, 20, kPad, 20),
                  child: Text(
                    q.text.trim().isEmpty
                        ? '가고 싶은 곳을 찾아 길찾기를 누르면\n카카오맵·네이버 지도에서 버스·지하철 길이 바로 열려요.\n☆ 을 누르면 자주 가는 곳에 저장돼요.'
                        : (searched ? '찾는 곳이 없어요. 이름을 조금 다르게 써 보세요.' : ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.5),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 30),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _row(list[i]),
                ),
        ),
      ]),
    );
  }

  Widget _row(GoPlace p) {
    final km = _km(widget.c.lat, widget.c.lng, p.lat, p.lng);
    final fav = _isFav(p);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F4)))),
      child: Row(children: [
        InkWell(
          onTap: () => _toggleFav(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 10, 4),
            child: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, size: 22, color: fav ? const Color(0xFFF5B400) : kMute),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => openTransit(context, widget.c, p, fromHere: fromHere),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text('${_dist(km)} · ${p.addr}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // 집으로(그곳 → 우리 단지)
        if (fav && !fromHere)
          _MiniBtn('집으로', primary: false, onTap: () => openTransit(context, widget.c, p, reverse: true)),
        if (fav && !fromHere) const SizedBox(width: 6),
        _MiniBtn('길찾기', onTap: () => openTransit(context, widget.c, p, fromHere: fromHere)),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.4), color: Colors.white));
}

class _MiniBtn extends StatelessWidget {
  final String t;
  final bool primary;
  final VoidCallback onTap;
  const _MiniBtn(this.t, {required this.onTap, this.primary = true});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary ? kBlue : kLine),
          ),
          child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: primary ? Colors.white : kInk)),
        ),
      );
}
