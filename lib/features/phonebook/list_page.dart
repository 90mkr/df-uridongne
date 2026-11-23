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
  PageController? pageCtl;
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
  int? _pageTarget;

  Complex get c => widget.complex;
  LatLng get from => c.pos;

  @override
  void initState() {
    super.initState();
    recTick.addListener(_re);
    prefGet('phonebook.view').then((v) {
      if (v == 'list' && mounted) setState(() => mapView = false);
    });
    loadRecs(c.areaId);
    loadLotsAround(from).then((_) => _re());
  }

  @override
  void dispose() {
    recTick.removeListener(_re);
    _deb?.cancel();
    _glide?.dispose();
    pageCtl?.dispose();
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

  void _setView(bool map) {
    setState(() => mapView = map);
    prefSet('phonebook.view', map ? 'map' : 'list');
  }

  void _changed() {
    // 정렬·고르기가 바뀌면 첫 가게부터
    sel = null;
    if (pageCtl?.hasClients ?? false) pageCtl!.jumpToPage(0);
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

  void _pick(Shop s, List<Shop> list, {required bool wide, bool fromPin = false}) {
    setState(() => sel = s.id);
    if (wide) {
      _glideTo(s.pos);
      if (fromPin) {
        final i = list.indexWhere((x) => x.id == s.id);
        if (i >= 0 && listCtl.hasClients) {
          listCtl.animateTo(math.min(i * (kCardH + _gap), listCtl.position.maxScrollExtent), duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
        }
      }
    } else {
      final i = list.indexWhere((x) => x.id == s.id);
      if (fromPin && i >= 0 && (pageCtl?.hasClients ?? false)) {
        final cur = pageCtl!.page?.round() ?? 0;
        if ((cur - i).abs() > 3) {
          pageCtl!.jumpToPage(i);
        } else {
          _pageTarget = i;
          pageCtl!.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
        }
      }
      _glideTo(s.pos, dy: (kCardH + 24) / 2);
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
          return Column(children: [
            _head(wide),
            _bar(list.length, wide),
            const Divider(height: 1, color: kLine),
            Expanded(child: wide ? _split(list, box.maxWidth) : (mapView ? _phoneMap(list, box.maxWidth) : _phoneList(list))),
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
          const SizedBox(width: 8),
          Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMute))),
          const Spacer(),
        ],
        if (!wide) ...[const SizedBox(width: 10), _toggle()],
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

  // ---------- 휴대폰: 지도 + 넘기는 카드 ----------
  Widget _phoneMap(List<Shop> list, double w) {
    final pins = list.take(_maxPins).toList();
    final frac = (w - 44) / w;
    final pc = pageCtl ??= PageController(viewportFraction: frac);
    return Stack(children: [
      Positioned.fill(child: _map(pins, wide: false, padBottom: kCardH + 30)),
      if (pins.isEmpty) Positioned(left: 20, right: 20, bottom: 30, child: _floatBox(_empty())),
      if (pins.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          bottom: 14 + MediaQuery.of(context).padding.bottom,
          height: kCardH + 8,
          child: PageView.builder(
            controller: pc,
            padEnds: true,
            itemCount: pins.length,
            onPageChanged: (i) {
              if (_pageTarget != null && i != _pageTarget) return;
              _pageTarget = null;
              _pick(pins[i], pins, wide: false);
            },
            itemBuilder: (_, i) {
              final s = pins[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: ShopCard(shop: s, complex: c, selected: sel == s.id, onTap: () => showShop(context, s, c)),
              );
            },
          ),
        ),
      if (pins.isNotEmpty)
        Positioned(
          left: 16,
          top: 12,
          child: _countTag('${list.length}곳${list.length > pins.length ? ' 중 가까운 ${pins.length}곳' : ''}'),
        ),
    ]);
  }

  Widget _floatBox(Widget child) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: kLine), boxShadow: kShadow),
        child: child,
      );

  Widget _countTag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine), boxShadow: kShadow),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kInk)),
      );

  // ---------- 휴대폰: 목록 (명함 카드) ----------
  Widget _phoneList(List<Shop> list) {
    if (list.isEmpty) return _empty();
    final n = math.min(list.length, 300);
    return Container(
      color: kBg,
      child: ListView.separated(
        controller: listCtl,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 30 + MediaQuery.of(context).padding.bottom),
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
          return ShopCard(shop: s, complex: c, maxStickers: 3, onTap: () => showShop(context, s, c));
        },
      ),
    );
  }

  // ---------- 태블릿·가로: 왼쪽 목록 40% + 오른쪽 지도 60% ----------
  Widget _split(List<Shop> list, double w) {
    final b = bounds;
    final inView = b == null ? list : list.where((s) => b.contains(s.pos)).toList();
    final shown = inView.take(_maxPins).toList();
    final leftW = (w * 0.4).clamp(340.0, 460.0);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        width: leftW,
        child: Container(
          color: kBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 2),
              child: Text(b == null ? '${list.length}곳' : '지도 안 ${inView.length}곳', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kSub)),
            ),
            Expanded(
              child: shown.isEmpty
                  ? _empty()
                  : ListView.separated(
                      controller: listCtl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: _gap),
                      itemBuilder: (_, i) {
                        final s = shown[i];
                        return ShopCard(
                          shop: s,
                          complex: c,
                          maxStickers: 3,
                          selected: sel == s.id,
                          onTap: () => sel == s.id ? showShop(context, s, c) : _pick(s, shown, wide: true),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
      Container(width: 1, color: kLine),
      Expanded(child: _map(list.take(_maxPins * 2).toList(), wide: true, listForPick: shown)),
    ]);
  }

  // ---------- 지도 ----------
  Widget _map(List<Shop> pins, {required bool wide, double padBottom = 0, List<Shop>? listForPick}) {
    final now = DateTime.now();
    final selShop = pins.where((s) => s.id == sel).firstOrNull;
    final ordered = [...pins.where((s) => s.id != sel), if (selShop != null) selShop];
    return LayoutBuilder(builder: (ctx, box) {
    final named = _labels(pins, box.biggest, padBottom);
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
            if (wide) setState(() => bounds = mapCtl.camera.visibleBounds);
          },
          onPositionChanged: (cam, gesture) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 140), () {
              if (!mounted) return;
              setState(() {
                zoom = cam.zoom;
                _center = cam.center;
                if (wide) bounds = cam.visibleBounds;
              });
            });
          },
          onTap: (_, __) => setState(() => sel = null),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'kr.designfeel.dongne'),
          MarkerLayer(markers: [
            for (final s in ordered)
              Marker(
                point: s.pos,
                width: 170,
                height: 46,
                alignment: Alignment.topCenter,
                child: _ShopPin(
                  name: s.name,
                  open: s.openAt(now),
                  selected: s.id == sel,
                  label: named.contains(s.id),
                  onTap: () => _pick(s, listForPick ?? pins, wide: wide, fromPin: true),
                ),
              ),
            Marker(point: from, width: 150, height: 44, alignment: Alignment.topCenter, child: _AptPin(c.name)),
          ]),
          const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
        ],
      ),
      Positioned(
        right: 14,
        top: 12,
        child: _MapBtn(icon: 'apt', tip: '우리 단지로', onTap: () => _glideTo(from, z: 16, dy: wide ? 0 : padBottom / 2 - 20)),
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
    if (zoom < 14.5) return out;
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
      final w = math.min(160.0, s.name.length * 11.5 + 30);
      return Rect.fromLTWH(q.dx - w / 2, q.dy - 34, w, 28);
    }

    // 단지 이름표 자리는 비워 둠
    final apt = pr(from) - o + Offset(size.width / 2, size.height / 2);
    placed.add(Rect.fromLTWH(apt.dx - 75, apt.dy - 34, 150, 30));
    final sp = pins.where((s) => s.id == sel).firstOrNull;
    if (sp != null) placed.add(rectOf(sp).inflate(4));
    final view = Rect.fromLTWH(0, 0, size.width, size.height - padBottom);
    for (final s in pins) {
      if (s.id == sel) continue;
      if (out.length >= 45) break;
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

// 가게 핀: 확대하면 상호 말풍선, 멀리서는 점. 영업 중 = 파랑, 곧 마감 = 주황, 그 밖 = 회색
class _ShopPin extends StatelessWidget {
  final String name;
  final Open open;
  final bool selected, label;
  final VoidCallback onTap;
  const _ShopPin({required this.name, required this.open, required this.selected, required this.label, required this.onTap});

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
        width: 14,
        height: 14,
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(color: col, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1), boxShadow: kShadow),
      );
    } else {
      final bg = selected ? kInk : Colors.white;
      final fg = selected ? Colors.white : kInk;
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? kInk : const Color(0xFFD3D8E0)),
            boxShadow: kShadow,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: selected ? 12.5 : 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: fg, height: 1.2)),
            ),
          ]),
        ),
        CustomPaint(size: const Size(10, 6), painter: _Tail(bg, selected ? kInk : const Color(0xFFD3D8E0))),
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
