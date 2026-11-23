// 동네 전화번호부 — 업종 화면 (지도 중심)
// 휴대폰: 지도(가게 핀+상호 말풍선) + 아래 명함 카드 넘기기 줄 / 「지도·목록」 전환(마지막 선택 기억)
// 태블릿·가로: 왼쪽 40% 명함 카드 목록 + 오른쪽 60% 지도 (지도 범위 안 가게만 목록에)
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'card.dart';
import 'data.dart';
import 'shop_sheet.dart';

enum Sort { rec, near }

const _maxPins = 250; // 지도에 한 번에 올리는 가게 수
const _gap = 10.0; // 카드 사이

class ShopListPage extends StatefulWidget {
  final Complex complex;
  final List<Shop> all;
  final Cat? cat;
  const ShopListPage({super.key, required this.complex, required this.all, this.cat});
  @override
  State<ShopListPage> createState() => _ShopListPageState();
}

class _ShopListPageState extends State<ShopListPage> with TickerProviderStateMixin {
  final q = TextEditingController();
  final mapCtl = MapController();
  final listCtl = ScrollController();
  bool mapView = true;
  Sort sort = Sort.near;
  bool openOnly = false;
  String sub = '';
  String? sel; // 고른 가게 id
  LatLngBounds? bounds; // 태블릿: 지도에 보이는 범위
  double zoom = 16;
  LatLng? _center;
  Timer? _deb;
  AnimationController? _glide;
  List<Shop> _lastPins = const []; // 지도 보기에 올린 가게들
  bool _userMoved = false;
  bool listHidden = false; // 휴대폰 목록 보기: 지도 바탕을 누르면 목록이 쏙 들어감
  Shop? _pending; // 목록에서 눌러 지도로 넘어올 때 맞춰 볼 가게
  bool _wide = false;
  final Map<String, GlobalKey> _keys = {};

  Complex get c => widget.complex;
  LatLng get from => c.pos;

  @override
  void initState() {
    super.initState();
    recTick.addListener(_re);
    loadRecs(c.areaId);
    loadLotsAround(from).then((_) => _re());
  }

  @override
  void dispose() {
    recTick.removeListener(_re);
    _deb?.cancel();
    _glide?.dispose();
    listCtl.dispose();
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  // ---------- 고르기·정렬 ----------
  List<Shop> get base => widget.cat == null ? widget.all : widget.all.where((s) => s.cats.contains(widget.cat!.id)).toList();

  List<Shop> get items {
    var list = base;
    final t = q.text.trim().replaceAll(' ', '');
    if (t.isNotEmpty) {
      list = list.where((s) => '${s.name}${s.sub}${s.cats.map((c) => catOf(c).name).join()}${s.addr}'.replaceAll(' ', '').contains(t)).toList();
    }
    if (sub.isNotEmpty) list = list.where((s) => s.sub == sub).toList();
    final now = DateTime.now();
    if (openOnly) {
      list = list.where((s) {
        final o = s.openAt(now);
        return o == Open.open || o == Open.closing;
      }).toList();
    }
    final d = {for (final s in list) s.id: meters(from, s.pos)};
    final r = recsOf(c.areaId);
    int n(Shop s) => r[s.id]?.n ?? 0;
    return [...list]
      ..sort((a, b) {
        if (sort == Sort.rec) {
          final k = n(b).compareTo(n(a));
          if (k != 0) return k;
        }
        return d[a.id]!.compareTo(d[b.id]!);
      });
  }

  List<MapEntry<String, int>> get subs {
    if (widget.cat == null) return const [];
    final m = <String, int>{};
    for (final s in base) {
      if (s.sub.isNotEmpty) m[s.sub] = (m[s.sub] ?? 0) + 1;
    }
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.length < 2 ? const [] : e.take(8).toList();
  }

  // 언제나 지도로 먼저 열고, 목록은 원할 때만 (대표님 11-23)
  void _setView(bool map) {
    setState(() {
      mapView = map;
      sel = null;
    });
  }

  void _changed() {
    // 정렬·고르기가 바뀌면 첫 가게부터
    sel = null;
    if (listCtl.hasClients) listCtl.jumpTo(0);
  }

  // ---------- 지도 움직임 ----------
  // 가게가 카드에 가리지 않게 화면 위쪽(dy 만큼)에 오도록 옮긴다
  void _glideTo(LatLng p, {double? z, double dy = 0}) {
    final cam = mapCtl.camera;
    final tz = z ?? math.max(cam.zoom, 16.0);
    final mpp = 156543.03 * math.cos(p.latitude * math.pi / 180) / math.pow(2, tz);
    final target = LatLng(p.latitude - dy * mpp / 111320, p.longitude);
    final a = cam.center, az = cam.zoom;
    _glide?.dispose();
    final g = _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    final curve = CurvedAnimation(parent: g, curve: Curves.easeOutCubic);
    g.addListener(() {
      final t = curve.value;
      mapCtl.move(LatLng(a.latitude + (target.latitude - a.latitude) * t, a.longitude + (target.longitude - a.longitude) * t), az + (tz - az) * t);
    });
    g.forward();
  }

  // 아래 상세 카드에 가리지 않게 가게를 화면 위쪽으로
  double get _panelDy => (mapView && !_wide) ? 130 : 0; // 휴대폰 지도 보기에서만 아래 상세 카드가 있음

  // 지도 핀을 누름: 그 가게 상세를 아래에 띄우고, 태블릿 목록은 그 카드로
  void _pin(Shop s) {
    setState(() {
      sel = s.id;
      listHidden = false;
    });
    _glideTo(s.pos, z: mapCtl.camera.zoom, dy: _panelDy);
    if (!mapView) {
      final k = _keys[s.id];
      final ctx = k?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic, alignment: 0.05);
    }
  }

  // 지도 가운데(아래 상세 카드에 가리지 않는 곳)에 가장 가까운 가게 (화면 너비의 1/3 안)
  Shop? _nearestToFocus(MapCamera cam) {
    final mpp = 156543.03 * math.cos(cam.center.latitude * math.pi / 180) / math.pow(2, cam.zoom);
    final focus = LatLng(cam.center.latitude + _panelDy * mpp / 111320, cam.center.longitude);
    final limit = mpp * (cam.nonRotatedSize.width / 3);
    Shop? best;
    var bd = double.infinity;
    for (final s in _lastPins) {
      final d = meters(focus, s.pos);
      if (d < bd) {
        bd = d;
        best = s;
      }
    }
    return bd <= limit ? best : null;
  }

  // 카드를 누름: 「이 가게가 우리 단지에서 어디쯤인지」 — 단지와 가게가 함께 보이게 알맞게 확대
  void _focus(Shop s) {
    // 목록 보기(휴대폰도 옆에 지도가 있음): 옆 지도를 그 가게로 옮기고 표시만
    setState(() => sel = s.id);
    _fit(s, animate: true);
  }

  void _fit(Shop s, {bool animate = false}) {
    try {
      final fit = CameraFit.coordinates(
        coordinates: [from, s.pos],
        padding: mapView ? EdgeInsets.fromLTRB(60, 90, 60, _wide ? 60 : 330) : EdgeInsets.fromLTRB(_wide ? 60 : 22, 60, _wide ? 60 : 22, 60),
        maxZoom: 17.2,
        minZoom: 12,
      ).fit(mapCtl.camera);
      if (animate) {
        _glideTo(fit.center, z: fit.zoom);
      } else {
        mapCtl.move(fit.center, fit.zoom);
      }
    } catch (_) {
      mapCtl.move(s.pos, 16.5);
    }
  }

  // ---------- 화면 ----------
  @override
  Widget build(BuildContext context) {
    final list = items;
    return ScrollConfiguration(
      behavior: const _Drag(),
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (ctx, box) {
          final wide = box.maxWidth >= 760 || (box.maxWidth > box.maxHeight && box.maxWidth >= 640);
          _wide = wide;
          return Column(children: [
            _head(wide),
            _bar(list.length, wide),
            const Divider(height: 1, color: kLine),
            Expanded(child: mapView ? _fullMap(list, wide) : _split(list, box.maxWidth, compact: !wide)),
          ]);
        }),
      ),
    ),
    );
  }

  Widget _head(bool wide) {
    final title = widget.cat?.name ?? '찾기';
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 4, right: 14),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kInk)),
        if (widget.cat == null)
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(controller: q, autofocus: true, onChanged: (_) => setState(_changed), style: const TextStyle(fontSize: 14.5), decoration: inputDeco('세탁소, 떡집, 가게 이름')),
            ),
          )
        else ...[
          LineIcon(widget.cat!.id, size: 26),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(width: 6),
          Text('${items.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w300, color: kSub)),
          if (wide) ...[
            const SizedBox(width: 10),
            Flexible(child: Text('${c.name} 기준', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMute))),
          ],
          const Spacer(),
        ],
        const SizedBox(width: 10),
        _toggle(),
      ]),
    );
  }

  // 「지도 · 목록」 전환
  Widget _toggle() {
    Widget seg(String t, String icon, bool on, VoidCallback f) => InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(7), boxShadow: on ? kShadow : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LineIcon(icon, size: 16, line: on ? kInk : kMute, fill: on ? kSoft : Colors.transparent),
              const SizedBox(width: 4),
              Text(t, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? kInk : kMute)),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('지도', 'map', mapView, () => _setView(true)),
        seg('목록', 'list', !mapView, () => _setView(false)),
      ]),
    );
  }

  // 정렬·필터 (지도·목록 공통) + 세부 업종
  Widget _bar(int n, bool wide) {
    final ss = subs;
    return SizedBox(
      height: 46,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), children: [
        _chip('이웃 추천 순', sort == Sort.rec, () => setState(() {
              sort = Sort.rec;
              _changed();
            })),
        _chip('가까운 순', sort == Sort.near, () => setState(() {
              sort = Sort.near;
              _changed();
            })),
        _chip('지금 영업 중', openOnly, () => setState(() {
              openOnly = !openOnly;
              _changed();
            }), dot: true),
        if (ss.isNotEmpty) ...[
          Container(width: 1, margin: const EdgeInsets.fromLTRB(4, 8, 10, 8), color: kLine),
          _chip('전체', sub.isEmpty, () => setState(() {
                sub = '';
                _changed();
              }), light: true),
          for (final e in ss)
            _chip(e.key, sub == e.key, () => setState(() {
                  sub = sub == e.key ? '' : e.key;
                  _changed();
                }), light: true),
        ],
      ]),
    );
  }

  Widget _chip(String t, bool on, VoidCallback f, {bool dot = false, bool light = false}) {
    final bg = on ? (light ? const Color(0xFFEEF3FF) : kInk) : Colors.white;
    final fg = on ? (light ? kBlue : Colors.white) : kSub;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17), border: Border.all(color: on ? (light ? const Color(0xFFC9D8FF) : kInk) : kLine)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFF7FB0FF) : kBlue)),
              const SizedBox(width: 5),
            ],
            Text(t, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: fg)),
          ]),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                openOnly
                    ? '지금 영업 중인 곳을 찾지 못했어요'
                    : q.text.isEmpty
                        ? '아직 모은 곳이 없어요'
                        : '찾는 곳이 없어요',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (openOnly) ...[
              const SizedBox(height: 5),
              const Text('영업시간을 아는 가게만 골라 보여 드려요', style: TextStyle(fontSize: 12, color: kMute)),
            ],
            const SizedBox(height: 16),
            SizedBox(width: 210, child: Btn('우리 가게 등록하기', icon: 'owner', h: 42, onTap: () => openOwnerForm(context, c, cat: widget.cat?.id))),
          ]),
        ),
      );

  // ---------- 지도 보기 (휴대폰·태블릿 같음): 지도만 넓게, 가게를 누르면 아래에 상세 카드 ----------
  Widget _fullMap(List<Shop> list, bool wide) {
    final pins = list.take(_maxPins).toList();
    _lastPins = pins;
    final selShop = list.where((s) => s.id == sel).firstOrNull;
    final bottom = 12 + MediaQuery.of(context).padding.bottom;
    return Stack(children: [
      Positioned.fill(child: _map(pins, wide: false, padBottom: selShop == null ? 0 : 280)),
      if (pins.isEmpty) Positioned(left: 20, right: 20, bottom: 30, child: _floatBox(_empty())),
      if (selShop != null)
        Positioned(
          left: 12,
          right: wide ? null : 12,
          width: wide ? 400 : null,
          bottom: bottom,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(selShop.id),
            tween: Tween(begin: 24, end: 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Transform.translate(offset: Offset(0, v), child: Opacity(opacity: 1 - v / 24, child: child)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
              child: SingleChildScrollView(child: ShopCard(shop: selShop, complex: c, onClose: () => setState(() => sel = null))),
            ),
          ),
        ),
    ]);
  }

  Widget _floatBox(Widget child) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: kLine), boxShadow: kShadow),
        child: child,
      );

  // ---------- 휴대폰: 목록 (명함 카드, 누르면 지도에서 위치) ----------
  Widget _phoneList(List<Shop> list) {
    if (list.isEmpty) return _empty();
    final n = math.min(list.length, 300);
    return Container(
      color: kBg,
      child: ListView.separated(
        controller: listCtl,
        padding: EdgeInsets.fromLTRB(14, 12, 14, 30 + MediaQuery.of(context).padding.bottom),
        itemCount: n + 1,
        separatorBuilder: (_, __) => const SizedBox(height: _gap),
        itemBuilder: (_, i) {
          if (i == n) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(list.length > n ? '가까운 $n곳까지 보여 드려요' : '${list.length}곳 · ${c.name} 기준', textAlign: TextAlign.center, style: T.small),
            );
          }
          final s = list[i];
          return ShopCard(key: ValueKey(s.id), shop: s, complex: c, tapHint: '지도', onTap: () => _focus(s));
        },
      ),
    );
  }

  // ---------- 태블릿·가로 목록 보기: 왼쪽 목록 40% + 오른쪽 지도 60% ----------
  // 목록 보기: 왼쪽 카드 목록 + 오른쪽 지도 (휴대폰은 카드 3/5 + 지도 2/5, 대표님 11-24)
  Widget _split(List<Shop> list, double w, {bool compact = false}) {
    final b = compact ? null : bounds;
    final inView = b == null ? list : list.where((s) => b.contains(s.pos)).toList();
    final shown = inView.take(120).toList();
    final leftW = compact ? w * 0.46 : (w * 0.4).clamp(340.0, 460.0);
    final hide = compact && listHidden;
    return Stack(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: hide ? 0 : leftW,
        child: OverflowBox(
          alignment: Alignment.centerRight,
          minWidth: leftW,
          maxWidth: leftW,
          child: Container(
          color: kBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 18, compact ? 10 : 12, 12, 2),
              child: Text(b == null ? '${list.length}곳 · 가까운 순' : '지도 안 ${inView.length}곳', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kSub)),
            ),
            Expanded(
              child: shown.isEmpty
                  ? _empty()
                  : SingleChildScrollView(
                      controller: listCtl,
                      padding: EdgeInsets.fromLTRB(compact ? 8 : 14, 8, compact ? 8 : 14, 30),
                      child: Column(children: [
                        for (final s in shown)
                          Padding(
                            key: _keys.putIfAbsent(s.id, () => GlobalKey()),
                            padding: EdgeInsets.only(bottom: compact ? 8 : _gap),
                            child: ShopCard(shop: s, complex: c, selected: sel == s.id, tapHint: '지도', compact: compact, onTap: () => _focus(s)),
                          ),
                      ]),
                    ),
            ),
          ]),
        ),
      ),
        ),
      Container(width: 1, color: kLine),
      Expanded(child: _map(list.take(_maxPins * 2).toList(), wide: !compact)),
    ]),
      // 목록을 접었을 때 다시 펼치는 단추
      if (hide)
        Positioned(
          left: 10,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: Material(
            color: Colors.white,
            elevation: 0,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => listHidden = false),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine), boxShadow: kShadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.view_list_rounded, size: 17, color: kBlue),
                  const SizedBox(width: 5),
                  Text('목록 ${list.length}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  // ---------- 지도 ----------
  Widget _map(List<Shop> pins, {required bool wide, double padBottom = 0}) {
    final now = DateTime.now();
    final selShop = pins.where((s) => s.id == sel).firstOrNull;
    return LayoutBuilder(builder: (ctx, box) {
    final named = _labels(pins, box.biggest, padBottom);
    // 점 → 카드 → 고른 가게 순으로 그려 카드 위에 점이 올라오지 않게
    final ordered = [
      ...pins.where((s) => s.id != sel && !named.contains(s.id)),
      ...pins.where((s) => s.id != sel && named.contains(s.id)),
      if (selShop != null) selShop,
    ];
    return Stack(children: [
      FlutterMap(
        mapController: mapCtl,
        options: MapOptions(
          initialCenter: from,
          initialZoom: 16,
          minZoom: 11,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: () {
            final p = _pending;
            if (p != null) {
              _pending = null;
              _fit(p);
            }
            if (wide) setState(() => bounds = mapCtl.camera.visibleBounds);
          },
          onPositionChanged: (cam, gesture) {
            if (gesture) _userMoved = true;
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 140), () {
              if (!mounted) return;
              final moved = _userMoved;
              _userMoved = false;
              setState(() {
                zoom = cam.zoom;
                _center = cam.center;
                if (wide) bounds = cam.visibleBounds;
                // 야놀자처럼: 상세 카드가 열린 채 지도를 끌면, 가운데(카드 위쪽)에 가장 가까운 가게로 상세가 바뀐다
                if (moved && mapView && sel != null) {
                  final near = _nearestToFocus(cam);
                  if (near != null) sel = near.id;
                }
              });
            });
          },
          onTap: (_, __) => setState(() {
            sel = null;
            if (!mapView && !_wide) listHidden = true;
          }),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
          MarkerLayer(markers: [
            for (final s in ordered)
              Marker(
                point: s.pos,
                width: _pinW,
                height: _pinH + 8,
                alignment: Alignment.topCenter,
                child: _ShopPin(
                  shop: s,
                  rec: recsOf(c.areaId)[s.id]?.n ?? 0,
                  open: s.openAt(now),
                  selected: s.id == sel,
                  label: named.contains(s.id),
                  onTap: () => _pin(s),
                ),
              ),
            Marker(point: from, width: 150, height: 44, alignment: Alignment.topCenter, child: _AptPin(c.name)),
          ]),
        ],
      ),
      Positioned(
        left: 8,
        top: 8,
        child: GestureDetector(
          onTap: () => openUrl('https://www.openstreetmap.org/copyright'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
            child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9.5, color: kMute)),
          ),
        ),
      ),
      Positioned(
        right: 14,
        top: 12,
        child: _MapBtn(icon: 'apt', tip: '우리 단지로', onTap: () => _glideTo(from, z: 16)),
      ),
      Positioned(
        right: 14,
        top: 60,
        child: Column(children: [
          _MapBtn(text: '+', onTap: () => mapCtl.move(mapCtl.camera.center, math.min(19, mapCtl.camera.zoom + 1))),
          const SizedBox(height: 6),
          _MapBtn(text: '−', onTap: () => mapCtl.move(mapCtl.camera.center, math.max(11, mapCtl.camera.zoom - 1))),
        ]),
      ),
    ]);
    });
  }

  // 말풍선끼리 겹치지 않게: 가까운(목록 앞) 가게부터 이름을 달고, 겹치면 점으로만
  Set<String> _labels(List<Shop> pins, Size size, double padBottom) {
    final out = <String>{};
    if (sel != null) out.add(sel!);
    if (zoom < 15 || size.width < 260) return out; // 좁은 옆 지도는 점만 (고른 가게만 카드)
    final c0 = _center ?? from;
    final scale = 256 * math.pow(2, zoom).toDouble();
    Offset pr(LatLng p) {
      final x = (p.longitude + 180) / 360 * scale;
      final r = p.latitude * math.pi / 180;
      final y = (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * scale;
      return Offset(x, y);
    }

    final o = pr(c0);
    final placed = <Rect>[];
    Rect rectOf(Shop s) {
      final q = pr(s.pos) - o + Offset(size.width / 2, size.height / 2);
      final w = _cardW(s.name);
      return Rect.fromLTWH(q.dx - w / 2, q.dy - _pinH - 6, w, _pinH);
    }

    // 단지 이름표 자리는 비워 둠
    final apt = pr(from) - o + Offset(size.width / 2, size.height / 2);
    placed.add(Rect.fromLTWH(apt.dx - 75, apt.dy - 34, 150, 30));
    final sp = pins.where((s) => s.id == sel).firstOrNull;
    if (sp != null) placed.add(rectOf(sp).inflate(4));
    final view = Rect.fromLTWH(0, 24, size.width, size.height - padBottom - 24);
    placed.add(Rect.fromLTWH(size.width - 64, 0, 64, 160)); // 지도 단추 자리
    for (final s in pins) {
      if (s.id == sel) continue;
      if (out.length >= 30) break;
      final r = rectOf(s);
      if (!view.overlaps(r)) continue;
      final rr = r.inflate(3);
      if (placed.any((x) => x.overlaps(rr))) continue;
      placed.add(rr);
      out.add(s.id);
    }
    return out;
  }
}

// 마우스로도 끌어 넘길 수 있게 (PC 화면에서 카드 넘기기)
class _Drag extends MaterialScrollBehavior {
  const _Drag();
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus};
}

// 가게 핀 (콕플처럼 작은 카드): 업종 그림 + 상호 + 한 줄(영업 상태·이웃 추천·세부 업종)
// 자리가 있으면 카드, 겹치면 작은 점. 영업 중 = 파랑, 곧 마감 = 주황, 그 밖 = 회색
const _pinW = 190.0, _pinH = 46.0;
double _cardW(String name) => math.min(_pinW, math.max(104.0, name.length * 11.8 + 62));

class _ShopPin extends StatelessWidget {
  final Shop shop;
  final int rec;
  final Open open;
  final bool selected, label;
  final VoidCallback onTap;
  const _ShopPin({required this.shop, required this.rec, required this.open, required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = switch (open) {
      Open.open => kBlue,
      Open.closing => const Color(0xFFE07A10),
      _ => const Color(0xFF8A919C),
    };
    final Widget body;
    if (!label) {
      body = Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(color: col, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1), boxShadow: kShadow),
      );
    } else {
      final bg = selected ? kBlue : Colors.white;
      final fg = selected ? Colors.white : kInk;
      final sub = selected ? const Color(0xD9FFFFFF) : kSub;
      final cat = shop.cats.isEmpty ? 'pin' : shop.cats.first;
      // 둘째 줄: 영업 상태가 있으면 그것, 없으면 이웃 추천, 그것도 없으면 세부 업종
      final Widget line2 = open == Open.open || open == Open.closing
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: selected ? Colors.white : col, shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Text(open == Open.open ? '영업 중' : '곧 마감', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? Colors.white : col, height: 1.2)),
              if (rec > 0) Text('  ·  추천 $rec', style: TextStyle(fontSize: 10, color: sub, height: 1.2)),
            ])
          : Text(rec > 0 ? '이웃 추천 $rec' : (shop.sub.isNotEmpty ? shop.sub : catOf(cat).name),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: sub, height: 1.2, fontWeight: rec > 0 ? FontWeight.w600 : FontWeight.w400));
      final card = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _cardW(shop.name),
        height: _pinH,
        padding: const EdgeInsets.fromLTRB(5, 5, 9, 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kBlue : const Color(0xFFD5DAE1)),
          boxShadow: [BoxShadow(color: selected ? kBlue.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.10), blurRadius: selected ? 16 : 8)],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 36,
              height: 36,
              color: selected ? const Color(0x26FFFFFF) : const Color(0xFFF2F4F7),
              alignment: Alignment.center,
              child: shop.photo.startsWith('http')
                  ? Image.network(shop.photo, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => LineIcon(cat, size: 23))
                  : LineIcon(cat, size: 23, line: selected ? Colors.white : kInk, fill: selected ? const Color(0x40FFFFFF) : kSoft),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg, height: 1.2, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              line2,
            ]),
          ),
        ]),
      );
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        card,
        CustomPaint(size: const Size(12, 6), painter: _Tail(bg, selected ? kBlue : const Color(0xFFD5DAE1))),
      ]);
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body),
    );
  }
}

class _AptPin extends StatelessWidget {
  final String name;
  const _AptPin(this.name);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(14), boxShadow: kShadow),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const LineIcon('apt', size: 15, line: Colors.white, fill: Color(0x40FFFFFF)),
              const SizedBox(width: 4),
              Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2))),
            ]),
          ),
          CustomPaint(size: const Size(10, 6), painter: _Tail(kBlue, kBlue)),
        ]),
      );
}

class _Tail extends CustomPainter {
  final Color fill, line;
  _Tail(this.fill, this.line);
  @override
  void paint(Canvas canvas, Size s) {
    final p = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(s.width, 0);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(p, Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    canvas.drawLine(const Offset(1, 0), Offset(s.width - 1, 0), Paint()
      ..color = fill
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _Tail o) => o.fill != fill || o.line != line;
}

class _MapBtn extends StatelessWidget {
  final String? icon, text, tip;
  final VoidCallback onTap;
  const _MapBtn({this.icon, this.text, this.tip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine), boxShadow: kShadow),
          child: icon != null ? LineIcon(icon!, size: 22) : Text(text ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: kInk, height: 1)),
        ),
      ),
    );
    return tip == null ? b : Tooltip(message: tip!, child: b);
  }
}
