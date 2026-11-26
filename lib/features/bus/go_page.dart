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

  static const _quick = [
    ('지하철역', 'subway'),
    ('버스터미널', 'terminal'),
    ('공항', 'airport'),
    ('대학병원', 'hospital'),
    ('시청', 'cityhall'),
    ('구청', 'office'),
    ('기차역', 'train'),
    ('대형마트', 'mart'),
  ];

  void _quickFind(String k) {
    q.text = k;
    setState(() {});
    _search(k);
  }

  @override
  Widget build(BuildContext context) {
    final typing = q.text.trim().isNotEmpty;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final imgH = w * 388 / 1080;
        final cardTop = math.max(top + 58, imgH * 0.47);
        return Stack(children: [
          // 하늘 그림 머리 (아래쪽은 흰색으로 이어져 경계 없음)
          Positioned(top: 0, left: 0, right: 0, child: Image.asset('assets/art/go_head.jpg', width: w, fit: BoxFit.fitWidth)),
          Positioned(
            top: top + 4,
            left: 4,
            right: 4,
            child: Row(children: [
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, size: 25, color: Color(0xFF10213F))),
              const Text('어디로 가세요?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Color(0xFF10213F))),
            ]),
          ),
          Positioned.fill(
            top: cardTop,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: kPad), child: _routeCard()),
                  Expanded(child: typing ? _results() : _home()),
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  // 출발 · 도착 카드
  Widget _routeCard() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EAF5)),
          boxShadow: const [BoxShadow(color: Color(0x1A2F6FD6), blurRadius: 24)],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, size: 24, color: kBlue),
              const SizedBox(width: 6),
              const Text('출발', style: TextStyle(fontSize: 13, color: kSub)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(fromHere ? '지금 내 위치' : widget.c.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              ),
              const SizedBox(width: 8),
              // 잘 보이는 바꾸기 버튼 (대표님 11-26)
              Material(
                color: fromHere ? kBlue : Colors.white,
                shape: StadiumBorder(side: BorderSide(color: kBlue.withValues(alpha: fromHere ? 1 : 0.7))),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => setState(() => fromHere = !fromHere),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 7, 14, 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(fromHere ? Icons.apartment_rounded : Icons.near_me_rounded, size: 16, color: fromHere ? Colors.white : kBlue),
                      const SizedBox(width: 5),
                      Text(fromHere ? '우리 단지로' : '내 위치로 바꾸기',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fromHere ? Colors.white : kBlue, letterSpacing: -0.2)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          Container(height: 1, color: const Color(0xFFEDF0F4), margin: const EdgeInsets.symmetric(horizontal: 14)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, size: 24, color: Color(0xFFEF4F4F)),
              const SizedBox(width: 6),
              const Text('도착', style: TextStyle(fontSize: 13, color: kSub)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: q,
                  onChanged: (v) {
                    setState(() {});
                    _typed(v);
                  },
                  onSubmitted: _search,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: '역·병원·가게·주소 찾기',
                    hintStyle: TextStyle(fontSize: 15, color: kMute, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
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
      );

  // 찾기 전: 저장한 곳 · 자주 가는 곳(3D 아이콘) · 안내 띠
  Widget _home() => ListView(padding: const EdgeInsets.fromLTRB(kPad, 22, kPad, 30), children: [
        if (favs.isNotEmpty) ...[
          _title(Icons.star_rounded, '저장한 곳', const Color(0xFFF5B400)),
          const SizedBox(height: 4),
          for (final p in favs) _row(p),
          const SizedBox(height: 22),
        ],
        _title(Icons.location_on_rounded, '자주 가는 곳', kBlue),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final per = box.maxWidth >= 600 ? 8 : 4;
          const gap = 10.0;
          final tw = (box.maxWidth - gap * (per - 1)) / per;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final k in _quick) SizedBox(width: tw, child: _QuickTile(k.$1, 'assets/art/go_${k.$2}.png', onTap: () => _quickFind(k.$1))),
          ]);
        }),
        const SizedBox(height: 22),
        _guide(),
      ]);

  Widget _title(IconData ic, String t, Color c) => Row(children: [
        Icon(ic, size: 24, color: c),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
      ]);

  Widget _guide() => Container(
        decoration: BoxDecoration(color: const Color(0xFFE7F2FD), borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: 0, bottom: 0, child: Image.asset('assets/art/go_city.png', height: 86, opacity: const AlwaysStoppedAnimation(0.9))),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
            child: Row(children: [
              Image.asset('assets/art/go_map.png', width: 96),
              Container(width: 1, height: 64, color: const Color(0xFFC9D8EE), margin: const EdgeInsets.symmetric(horizontal: 12)),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '가고 싶은 곳을 찾아 '),
                      TextSpan(text: '‘길찾기’', style: TextStyle(color: kBlue, fontSize: 17, fontWeight: FontWeight.w900)),
                      TextSpan(text: '를 누르면'),
                    ]),
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.3, color: Color(0xFF10213F)),
                  ),
                  SizedBox(height: 5),
                  Text('카카오맵·네이버 지도에서 버스·지하철 길이 바로 열려요.', style: TextStyle(fontSize: 12, color: kInk, height: 1.4)),
                  SizedBox(height: 3),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.star_outline_rounded, size: 15, color: kBlue)),
                    SizedBox(width: 3),
                    Expanded(child: Text('을 누르면 자주 가는 곳에 저장돼요.', style: TextStyle(fontSize: 12, color: kInk, height: 1.4))),
                  ]),
                ]),
              ),
            ]),
          ),
        ]),
      );

  // 찾은 곳
  Widget _results() {
    if (found.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 30, kPad, 20),
        child: Text(searched && !busy ? '찾는 곳이 없어요. 이름을 조금 다르게 써 보세요.' : '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: kSub, height: 1.5)),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 30), children: [
      _title(Icons.search_rounded, '찾은 곳', kBlue),
      const SizedBox(height: 4),
      for (final p in found) _row(p),
    ]);
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

// 자주 가는 곳 칸 (대표님 3D 아이콘)
class _QuickTile extends StatelessWidget {
  final String t, img;
  final VoidCallback onTap;
  const _QuickTile(this.t, this.img, {required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF5)),
              boxShadow: const [BoxShadow(color: Color(0x142F6FD6), blurRadius: 14)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset(img, width: 46, height: 46, filterQuality: FilterQuality.medium),
              const SizedBox(height: 7),
              FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.4))),
            ]),
          ),
        ),
      );
}
