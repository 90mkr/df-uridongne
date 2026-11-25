// 가까운 화장실 (본부 방, 11-25 대표님 지시 · requests/toilet-1125-가까운-화장실-새-기능.md)
// 급할 때 기준: 열자마자 가장 가까운 한 곳을 크게(이름 · 걸어서 몇 분 · 지금 열림 · 큰 길안내) → 그 아래 다음 가까운 곳
// 지금 닫힌 곳은 아래로·흐리게. 자료는 휴대폰에 저장해 두어 인터넷이 약해도 뜬다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _green = Color(0xFF16A34A);

class ToiletFeature extends Feature {
  @override
  String get id => 'toilet';
  @override
  String get name => '가까운 화장실';
  @override
  String get icon => 'toilet';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 1; // 생활 도구 맨 앞줄 (tools_tab 에서도 앞으로)
  @override
  String get version => '0.1.0';
  @override
  bool get ready => true;

  @override
  Widget page(BuildContext context, Complex c) => ToiletPage(complex: c);

  @override
  Future<List<MapPoint>> mapPoints(Complex c) async {
    final v = await toiletsNear(c.pos, km: 2);
    final now = DateTime.now();
    return [
      for (final x in v.take(200))
        MapPoint(
            id: 'toilet_${x.$1.id}',
            name: x.$1.name,
            sub: '${x.$1.openAt(now) == false ? '지금 닫힘' : x.$1.hoursText} · ${distText(x.$2)}',
            pos: x.$1.pos,
            onTap: (ctx) => showToilet(ctx, x.$1, x.$2)),
    ];
  }
}

class ToiletPage extends StatefulWidget {
  final Complex complex;
  const ToiletPage({super.key, required this.complex});
  @override
  State<ToiletPage> createState() => _ToiletPageState();
}

class _ToiletPageState extends State<ToiletPage> {
  LatLng? at;
  bool fromGps = false;
  bool loading = true;
  bool map = false;
  List<(Toilet, double)> list = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 급할 때는 「지금 내가 있는 곳」 기준 — 위치를 못 받으면 우리 단지 기준
    final p = await myLocation(ask: true).timeout(const Duration(seconds: 6), onTimeout: () => null);
    at = p ?? widget.complex.pos;
    fromGps = p != null;
    var v = await toiletsNear(at!, km: 2);
    if (v.length < 3) v = await toiletsNear(at!, km: 6);
    if (!mounted) return;
    setState(() {
      list = urgentOrder(v, DateTime.now());
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return DetailPage(
      title: '가까운 화장실',
      icon: 'toilet',
      actions: [
        if (list.isNotEmpty)
          TextButton(onPressed: () => setState(() => map = !map), child: Text(map ? '목록으로' : '지도로 보기', style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
      body: loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(strokeWidth: 2.4), SizedBox(height: 14), Text('가까운 화장실을 찾고 있어요', style: T.small)]))
          : list.isEmpty
              ? _empty()
              : map
                  ? DongneMap(
                      center: at!,
                      zoom: 16,
                      icon: 'toilet',
                      focus: 'toilet_${list.first.$1.id}',
                      points: [
                        for (final x in list.take(150))
                          MapPoint(
                              id: 'toilet_${x.$1.id}',
                              name: x.$1.name,
                              sub: '걸어서 ${walkMin(x.$2)}분 · ${x.$1.openAt(now) == false ? '지금 닫힘' : x.$1.hoursText}',
                              pos: x.$1.pos,
                              onTap: (ctx) => showToilet(ctx, x.$1, x.$2)),
                      ],
                    )
                  : ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
                      Text(fromGps ? '지금 계신 곳에서 가까운 순' : '${widget.complex.name} 기준 · 위치를 켜면 지금 계신 곳 기준', style: T.small),
                      const SizedBox(height: 10),
                      _Hero(t: list.first.$1, m: list.first.$2, now: now),
                      if (list.length > 1) ...[
                        const SizedBox(height: 22),
                        const Text('다음으로 가까운 곳', style: T.h2),
                        const SizedBox(height: 6),
                        for (final x in list.skip(1).take(30)) _Row(t: x.$1, m: x.$2, now: now),
                      ],
                      const SizedBox(height: 16),
                      const Text('공공데이터(행정안전부 공중화장실정보) 기준이라 개방 시간은 현장 사정에 따라 다를 수 있어요.', style: T.tiny),
                    ]),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          const LineIcon('toilet', size: 56),
          const SizedBox(height: 14),
          const Text('근처에 등록된 공중화장실을 찾지 못했어요', style: T.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('지하철역·공원·주민센터·주유소 화장실은 대부분 누구나 쓸 수 있어요', style: T.small, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SizedBox(width: 200, child: Btn('다시 찾기', onTap: () {
            setState(() => loading = true);
            _load();
          })),
        ]),
      );
}

Widget _openPill(Toilet t, DateTime now) {
  final o = t.openAt(now);
  if (o == true) return const Pill('지금 열림', color: _green, bg: Color(0xFFE5F6EC));
  if (o == false) return const Pill('지금 닫힘', color: Color(0xFFB4232F), bg: Color(0xFFFDECEE));
  return const Pill('개방 시간 확인 필요');
}

List<String> _facts(Toilet t) => [
      if (t.men > 0 || t.women > 0) '남 ${t.men} · 여 ${t.women}',
      if (t.disabled) '장애인',
      if (t.diaper) '기저귀 교환대',
      if (t.bell) '비상벨',
      if (t.cctv) '입구 CCTV',
    ];

// 가장 가까운 한 곳 — 크게, 길안내 하나
class _Hero extends StatelessWidget {
  final Toilet t;
  final double m;
  final DateTime now;
  const _Hero({required this.t, required this.m, required this.now});
  @override
  Widget build(BuildContext context) {
    final f = _facts(t);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: [BoxShadow(color: kBlue.withValues(alpha: 0.08), blurRadius: 18)],
      ),
      child: InkWell(
        onTap: () => showToilet(context, t, m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('가장 가까운 화장실', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBlue)), const Spacer(), _openPill(t, now)]),
          const SizedBox(height: 8),
          Text(t.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.2)),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            const TextSpan(text: '걸어서 ', style: TextStyle(fontSize: 15, color: kSub)),
            TextSpan(text: '${walkMin(m)}분', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.6)),
            TextSpan(text: '  ${distText(m)}', style: const TextStyle(fontSize: 14, color: kSub)),
          ])),
          if (t.hoursText.isNotEmpty || f.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text([if (t.hoursText.isNotEmpty) t.hoursText, ...f].join('  ·  '), style: T.small),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Btn('길안내', icon: 'route', primary: true, h: 56, onTap: () => startNav(context, name: t.name, lat: t.pos.latitude, lng: t.pos.longitude, walk: true)),
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Toilet t;
  final double m;
  final DateTime now;
  const _Row({required this.t, required this.m, required this.now});
  @override
  Widget build(BuildContext context) {
    final closed = t.openAt(now) == false;
    return Opacity(
      opacity: closed ? 0.45 : 1,
      child: InkWell(
        onTap: () => showToilet(context, t, m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
          child: Row(children: [
            SizedBox(
              width: 52,
              child: Column(children: [
                Text('${walkMin(m)}분', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text(distText(m), style: T.tiny),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title),
                const SizedBox(height: 2),
                Text([closed ? '지금 닫힘 · ${t.hoursText}' : t.hoursText, ..._facts(t).skip(1)].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '길안내',
              onPressed: () => startNav(context, name: t.name, lat: t.pos.latitude, lng: t.pos.longitude, walk: true),
              icon: const LineIcon('route', size: 26),
            ),
          ]),
        ),
      ),
    );
  }
}

// 자세히 — 아래에서 올라오는 창
Future<void> showToilet(BuildContext context, Toilet t, double m) => showSheet(context, (ctx) {
      final now = DateTime.now();
      final f = _facts(t);
      Widget kv(String k, String v, {bool copy = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 64, child: Text(k, style: T.small)),
              Expanded(child: Text(v, style: T.body)),
              if (copy)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: v));
                    toast(ctx, '주소를 복사했어요');
                  },
                  child: const Padding(padding: EdgeInsets.only(left: 8), child: Text('복사', style: TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700))),
                ),
            ]),
          );
      return Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(t.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            _openPill(t, now),
          ]),
          const SizedBox(height: 4),
          Text('${t.kind.isEmpty ? '공중화장실' : t.kind} · 걸어서 ${walkMin(m)}분 · ${distText(m)}', style: T.small),
          const SizedBox(height: 10),
          if (t.addr.isNotEmpty) kv('주소', t.addr, copy: true),
          if (t.hoursText.isNotEmpty) kv('개방 시간', t.hoursText),
          if (f.isNotEmpty) kv('시설', f.join(' · ')),
          if (t.org.isNotEmpty) kv('관리', t.org),
          const SizedBox(height: 12),
          Row(children: [
            if (t.tel.isNotEmpty) ...[Expanded(child: Btn('관리기관 전화', icon: 'phone', onTap: () => callTel(t.tel))), const SizedBox(width: 10)],
            Expanded(child: Btn('길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: t.name, lat: t.pos.latitude, lng: t.pos.longitude, walk: true))),
          ]),
          const SizedBox(height: 10),
          const Text('개방 시간은 현장 사정에 따라 다를 수 있어요', style: T.tiny),
        ]),
      );
    });
