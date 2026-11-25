// 우리 동네 반려동물 — 업체 화면 (응급·24시 / 동물병원 / 미용 / 호텔·돌봄 / 용품 / 동물약국)
// 목록·지도가 함께 있는 화면은 지도 먼저 (대표님 11-23), 응급만 「가장 가까운 한 곳 크게」 먼저
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

const kPetGreen = Color(0xFF16A34A);

// 동물병원 거르기 (상호로 알 수 있는 것만)
const _hospFilters = [
  ('all', '전체', ''),
  ('night', '24시·응급', ''),
  ('cat', '고양이', r'고양이|캣|냥|cat|Cat|CAT'),
  ('dental', '치과', r'치과|덴탈|dental|Dental'),
  ('exotic', '특수동물', r'특수|조류|파충|이그조틱|엑조틱|토끼|햄스터|앵무'),
  ('big', '큰 병원', r'메디컬센터|메디컬 센터|의료센터|종합|센터|2차|대학'),
];

bool _hospMatch(PetPlace p, String f) {
  if (f == 'all') return true;
  if (f == 'night') return p.night;
  final re = _hospFilters.firstWhere((x) => x.$1 == f).$3;
  return RegExp(re).hasMatch(p.name);
}

// ---------------- 칸별 화면 (지도 먼저) ----------------
class PetPlacesPage extends StatefulWidget {
  final Complex complex;
  final PetKind kind;
  const PetPlacesPage({super.key, required this.complex, required this.kind});
  @override
  State<PetPlacesPage> createState() => _PetPlacesPageState();
}

class _PetPlacesPageState extends State<PetPlacesPage> {
  bool loading = true, map = true;
  String filter = 'all';
  List<(PetPlace, double)> all = const [];
  double km = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var v = (await petNear(widget.complex.pos, km: km)).where((x) => x.$1.kind == widget.kind).toList();
    // 드문 칸(약국·호텔)은 넓혀서
    if (v.length < 5 && km < 8) {
      km = 8;
      v = (await petNear(widget.complex.pos, km: km)).where((x) => x.$1.kind == widget.kind).toList();
    }
    if (!mounted) return;
    setState(() {
      all = v;
      loading = false;
    });
  }

  List<(PetPlace, double)> get list => widget.kind == PetKind.hosp ? all.where((x) => _hospMatch(x.$1, filter)).toList() : all;

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final l = list;
    return DetailPage(
      title: petKindName(k) == '용품' ? '반려동물 용품' : petKindName(k),
      icon: kindIcon(k),
      actions: [
        if (!loading && all.isNotEmpty)
          TextButton(onPressed: () => setState(() => map = !map), child: Text(map ? '목록 보기' : '지도 보기', style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
      body: loading
          ? const PetLoading('가까운 곳을 찾고 있어요')
          : all.isEmpty
              ? PetEmpty('${widget.complex.name} 둘레 ${km.round()}km 안에 등록된 ${petKindName(k)}이 없어요')
              : Column(children: [
                  if (k == PetKind.hosp) _filters(),
                  Expanded(
                    child: map
                        ? DongneMap(
                            key: ValueKey('pet-$filter'),
                            center: widget.complex.pos,
                            zoom: 15,
                            icon: 'pet',
                            points: [for (final x in l.take(200)) petPoint(x.$1, x.$2)],
                          )
                        : ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 30), children: [
                            Text('${widget.complex.name}에서 가까운 순 · ${l.length}곳', style: T.small),
                            const SizedBox(height: 4),
                            for (final x in l.take(80)) PetRow(p: x.$1, m: x.$2),
                            const SizedBox(height: 14),
                            const PetNote(),
                          ]),
                  ),
                ]),
    );
  }

  Widget _filters() => Container(
        color: Colors.white,
        height: 50,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(kPad, 8, kPad, 8), children: [
          for (final f in _hospFilters) ...[
            ChoiceChipBox('${f.$2}${f.$1 == 'all' ? '' : ' ${all.where((x) => _hospMatch(x.$1, f.$1)).length}'}',
                on: filter == f.$1, onTap: () => setState(() => filter = f.$1)),
            const SizedBox(width: 6),
          ],
        ]),
      );
}

String kindIcon(PetKind k) => switch (k) {
      PetKind.hosp => 'hosp',
      PetKind.groom => 'hair',
      PetKind.hotel => 'home',
      PetKind.shop => 'mart',
      PetKind.pharm => 'pharm',
    };

MapPoint petPoint(PetPlace p, double m) => MapPoint(
      id: 'pet_${p.id}',
      name: p.name,
      sub: '${p.night ? '24시·응급 · ' : ''}${petDist(m)} · ${distText(m)}',
      pos: p.pos,
      icon: kindIcon(p.kind),
      onTap: (ctx) => showPetPlace(ctx, p, m),
    );

// ---------------- 응급·24시 (급할 때: 열자마자 가장 가까운 한 곳 크게) ----------------
class PetEmergencyPage extends StatefulWidget {
  final Complex complex;
  const PetEmergencyPage({super.key, required this.complex});
  @override
  State<PetEmergencyPage> createState() => _PetEmergencyPageState();
}

class _PetEmergencyPageState extends State<PetEmergencyPage> {
  bool loading = true, map = false, fromGps = false;
  LatLng? at;
  List<(PetPlace, double)> night = const [], near = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await myLocation(ask: true).timeout(const Duration(seconds: 6), onTimeout: () => null);
    at = p ?? widget.complex.pos;
    fromGps = p != null;
    final r = await Future.wait([nightVets(at!), petNear(at!, km: 6)]);
    final mine = r[1].where((x) => x.$1.kind == PetKind.hosp).toList();
    // 24시: 카카오(지금 찾은 것) + 동네 자료 상호 → 이름으로 합침
    final seen = <String>{};
    final n = <(PetPlace, double)>[];
    for (final x in [...r[0], ...mine.where((x) => x.$1.night)]) {
      if (seen.add(x.$1.name.replaceAll(' ', ''))) n.add(x);
    }
    n.sort((a, b) => a.$2.compareTo(b.$2));
    if (!mounted) return;
    setState(() {
      night = n;
      near = mine;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nightNow = petNightNow(now);
    final top = night.isNotEmpty ? night.first : (near.isNotEmpty ? near.first : null);
    return DetailPage(
      title: '응급·24시 동물병원',
      icon: 'night',
      actions: [
        if (!loading && top != null)
          TextButton(onPressed: () => setState(() => map = !map), child: Text(map ? '목록 보기' : '지도 보기', style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
      body: loading
          ? const PetLoading('밤에도 여는 동물병원을 찾고 있어요')
          : top == null
              ? const PetEmpty('가까운 동물병원을 찾지 못했어요')
              : map
                  ? DongneMap(center: at!, zoom: 13, icon: 'pet', focus: 'pet_${top.$1.id}', points: [
                      for (final x in night.take(40)) petPoint(x.$1, x.$2),
                      for (final x in near.where((x) => !x.$1.night).take(80)) petPoint(x.$1, x.$2),
                    ])
                  : ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 30), children: [
                      Text(fromGps ? '지금 계신 곳에서 가까운 순' : '${widget.complex.name} 기준 · 위치를 켜면 지금 계신 곳 기준', style: T.small),
                      const SizedBox(height: 10),
                      _Hero(p: top.$1, m: top.$2, night: night.isNotEmpty, nightNow: nightNow),
                      if (night.length > 1) ...[
                        const SizedBox(height: 24),
                        const MixTitle('밤에도 여는', '다른 병원', size: 15),
                        const SizedBox(height: 4),
                        for (final x in night.skip(1).take(10)) PetRow(p: x.$1, m: x.$2),
                      ],
                      if (near.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        MixTitle('가까운', nightNow ? '동물병원 · 지금은 닫았을 수 있어요' : '동물병원', size: 15),
                        const SizedBox(height: 4),
                        for (final x in near.where((x) => !x.$1.night).take(10)) Opacity(opacity: nightNow ? 0.5 : 1, child: PetRow(p: x.$1, m: x.$2)),
                      ],
                      const SizedBox(height: 18),
                      const _FirstAid(),
                      const SizedBox(height: 14),
                      const PetNote(),
                    ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final PetPlace p;
  final double m;
  final bool night, nightNow;
  const _Hero({required this.p, required this.m, required this.night, required this.nightNow});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
          boxShadow: [BoxShadow(color: kBlue.withValues(alpha: 0.08), blurRadius: 18)],
        ),
        child: InkWell(
          onTap: () => showPetPlace(context, p, m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(night ? '가장 가까운 24시·응급 병원' : '가장 가까운 동물병원', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBlue)),
              const Spacer(),
              if (night) const Pill('밤에도 진료', color: kPetGreen, bg: Color(0xFFE5F6EC)),
            ]),
            const SizedBox(height: 8),
            Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.2)),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: m < 1200 ? '걸어서 ' : '차로 ', style: const TextStyle(fontSize: 15, color: kSub)),
              TextSpan(text: petDist(m).split(' ').last, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.6)),
              TextSpan(text: '  ${distText(m)}', style: const TextStyle(fontSize: 14, color: kSub)),
            ])),
            if (p.addr.isNotEmpty) ...[const SizedBox(height: 4), Text(p.addr, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis)],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _CallBtn(p: p, h: 56, primary: false)),
              const SizedBox(width: 10),
              Expanded(child: Btn('길안내', icon: 'route', primary: true, h: 56, onTap: () => startNav(context, name: p.name, lat: p.lat, lng: p.lng))),
            ]),
            const SizedBox(height: 10),
            Text(!night && nightNow ? '근처에 24시 병원을 찾지 못했어요. 가기 전에 꼭 전화로 진료 중인지 확인해 주세요.' : '가기 전에 전화로 지금 진료 중인지 확인하면 기다리는 시간이 줄어요.',
                style: T.tiny),
          ]),
        ),
      );
}

// 응급 때 먼저 할 일 (일반 안내 — 병원 대신이 아님)
class _FirstAid extends StatelessWidget {
  const _FirstAid();
  @override
  Widget build(BuildContext context) {
    const items = [
      ('바로 병원으로', '숨쉬기 힘들어함 · 잇몸이 하얗거나 파람 · 경련 · 의식 흐림 · 배가 갑자기 부풂'),
      ('먹으면 안 되는 걸 먹었다면', '억지로 토하게 하지 말고, 먹은 것·양·시간을 챙겨 바로 전화'),
      ('다쳤을 때', '피가 나면 깨끗한 천으로 꾹 눌러 주고, 아파서 물 수 있으니 조심해서 옮기기'),
      ('열사병 같을 때', '시원한 곳으로 옮겨 미지근한 물로 몸을 적시고 바로 병원으로 (얼음물 금지)'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MixTitle('응급할 때', '먼저 할 일', size: 14.5),
        const SizedBox(height: 6),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(i.$2, style: T.small),
            ]),
          ),
        const SizedBox(height: 4),
        const Text('일반적인 안내예요. 아이 상태는 꼭 수의사에게 물어 주세요.', style: T.tiny),
      ]),
    );
  }
}

// ---------------- 공용 조각 ----------------
class PetRow extends StatelessWidget {
  final PetPlace p;
  final double m;
  const PetRow({super.key, required this.p, required this.m});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => showPetPlace(context, p, m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
          child: Row(children: [
            SizedBox(
              width: 54,
              child: Column(children: [
                Text(distText(m), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text(m < 1200 ? '걸어서' : '차로', style: T.tiny),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title)),
                  if (p.night) ...[const SizedBox(width: 6), const Pill('24시·응급', color: kPetGreen, bg: Color(0xFFE5F6EC))],
                ]),
                const SizedBox(height: 2),
                Text(p.addr.isEmpty ? p.sub : p.addr, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
            const SizedBox(width: 4),
            IconButton(tooltip: '전화', onPressed: () => callPet(context, p), icon: const LineIcon('phone', size: 24)),
          ]),
        ),
      );
}

Future<void> callPet(BuildContext context, PetPlace p) async {
  final t = await petPhone(p);
  if (t.isEmpty) {
    if (context.mounted) toast(context, '전화번호를 찾지 못했어요. 카카오맵에서 확인해 주세요');
    return;
  }
  await callTel(t);
}

class _CallBtn extends StatelessWidget {
  final PetPlace p;
  final double h;
  final bool primary;
  const _CallBtn({required this.p, this.h = 46, this.primary = false});
  @override
  Widget build(BuildContext context) => Btn('전화', icon: 'phone', h: h, primary: primary, onTap: () => callPet(context, p));
}

Future<void> showPetPlace(BuildContext context, PetPlace p, double m) => showSheet(context, (ctx) {
      Widget kv(String k, String v, {bool copy = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 56, child: Text(k, style: T.small)),
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
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            if (p.night) const Pill('24시·응급', color: kPetGreen, bg: Color(0xFFE5F6EC)),
          ]),
          const SizedBox(height: 4),
          Text('${p.sub.isEmpty ? petKindName(p.kind) : p.sub} · ${petDist(m)} · ${distText(m)}', style: T.small),
          const SizedBox(height: 10),
          if (p.addr.isNotEmpty) kv('주소', p.addr, copy: true),
          FutureBuilder<String>(
            future: petPhone(p),
            builder: (_, s) => kv('전화', s.connectionState != ConnectionState.done ? '찾는 중…' : (s.data?.isNotEmpty == true ? s.data! : '등록된 번호 없음')),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _CallBtn(p: p)),
            const SizedBox(width: 10),
            Expanded(child: Btn('길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: p.name, lat: p.lat, lng: p.lng))),
          ]),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => openUrl(p.kakaoUrl),
              child: const Text('카카오맵에서 사진·후기 보기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
          const Text('진료·영업시간은 공공자료에 없어요. 가기 전에 전화로 확인해 주세요.', style: T.tiny),
        ]),
      );
    });

class PetLoading extends StatelessWidget {
  final String text;
  const PetLoading(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(strokeWidth: 2.4), const SizedBox(height: 14), Text(text, style: T.small)]));
}

class PetEmpty extends StatelessWidget {
  final String text;
  const PetEmpty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LineIcon('pet', size: 56),
            const SizedBox(height: 14),
            Text(text, style: T.title, textAlign: TextAlign.center),
          ]),
        ),
      );
}

class PetNote extends StatelessWidget {
  const PetNote({super.key});
  @override
  Widget build(BuildContext context) =>
      const Text('소상공인시장진흥공단 상가정보·행정안전부 인허가 자료 기준이에요. 문을 닫았거나 바뀐 곳이 있을 수 있어요.', style: T.tiny);
}
