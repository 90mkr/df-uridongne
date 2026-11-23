// 내 차 어디 댔지 (이 폴더는 주차장 담당 방만 고침)
// 세운 위치·시각·주차장·층/구역 메모는 휴대폰 안(prefSet 'parking.car')에만 저장한다. 서버로 보내지 않는다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

class MyCar {
  final double lat, lng;
  final DateTime at;
  final String memo; // 층·구역 (예: 「B2 · C-14」)
  final int freeMin; // 따로 받은 무료 시간 (마트·병원 등록 등), 분
  final Lot? lot; // 세운 주차장 (요금 계산용, 모르면 null)
  const MyCar({required this.lat, required this.lng, required this.at, this.memo = '', this.freeMin = 0, this.lot});

  LatLng get pos => LatLng(lat, lng);
  int minutes(DateTime now) => now.difference(at).inMinutes.clamp(0, 1 << 30);

  // 지금까지 요금 (무료 시간을 뺀 뒤 주차장 요금표로). 모르면 null
  int? cost(DateTime now) {
    final l = lot;
    if (l == null) return freeMin > 0 && minutes(now) <= freeMin ? 0 : null;
    final m = minutes(now) - freeMin;
    if (m <= 0) return 0;
    return l.costFor(m);
  }

  // 무료가 끝나는 시각: 받은 무료 시간 → 노상 주차장의 요금 시작 시각 순으로
  DateTime? freeEnds() {
    if (freeMin > 0) return at.add(Duration(minutes: freeMin));
    final l = lot;
    if (l != null && l.freeAt(at)) return l.paidFrom(at);
    return null;
  }

  Map<String, dynamic> toJson() => {'y': lat, 'x': lng, 't': at.millisecondsSinceEpoch, 'm': memo, 'f': freeMin, if (lot != null) 'lot': lot!.toCar()};

  static MyCar? fromJson(dynamic j) {
    if (j is! Map || j['y'] == null) return null;
    return MyCar(
      lat: (j['y'] as num).toDouble(),
      lng: (j['x'] as num).toDouble(),
      at: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      memo: '${j['m'] ?? ''}',
      freeMin: (j['f'] as num?)?.toInt() ?? 0,
      lot: j['lot'] is Map ? Lot.fromJson(j['lot']) : null,
    );
  }
}

// 앱 어디서나 지켜보는 「지금 세워 둔 차」
final myCar = ValueNotifier<MyCar?>(null);
bool _loaded = false;

Future<MyCar?> loadCar() async {
  if (_loaded) return myCar.value;
  _loaded = true;
  try {
    final s = await prefGet('parking.car');
    if (s != null && s.isNotEmpty) myCar.value = MyCar.fromJson(jsonDecode(s));
  } catch (_) {}
  _watch();
  return myCar.value;
}

Future<void> saveCar(MyCar? c) async {
  myCar.value = c;
  await prefSet('parking.car', c == null ? '' : jsonEncode(c.toJson()));
  _watch();
}

// 무료 시간 끝나기 10분 전 알림 — 지금은 앱이 켜져 있는 동안만 (휴대폰 알림 공용 부품은 본부에 요청)
Timer? _alarm;
final carAlert = ValueNotifier<String?>(null);

void _watch() {
  _alarm?.cancel();
  final c = myCar.value;
  final end = c?.freeEnds();
  if (c == null || end == null) return;
  final at = end.subtract(const Duration(minutes: 10));
  final wait = at.difference(DateTime.now());
  if (wait.isNegative) return;
  _alarm = Timer(wait, () => carAlert.value = '무료 시간이 10분 남았어요 (${_hm(end)}까지)');
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String elapsedText(int m) => m < 60 ? '$m분' : (m % 60 == 0 ? '${m ~/ 60}시간' : '${m ~/ 60}시간 ${m % 60}분');

// 「1시간 20분 · 2,000원」
String carLine(MyCar c, DateTime now) {
  final m = c.minutes(now);
  final w = c.cost(now);
  return '${elapsedText(m)} · ${w == null ? '요금 모름' : (w == 0 ? '무료' : won(w))}';
}

// ---------------- 화면 ----------------

// 주차장 화면 맨 위 큰 버튼 / 주차 중 카드
class CarBar extends StatefulWidget {
  final List<Lot> lots;
  const CarBar({super.key, required this.lots});
  @override
  State<CarBar> createState() => _CarBarState();
}

class _CarBarState extends State<CarBar> {
  Timer? tick;
  @override
  void initState() {
    super.initState();
    loadCar().then((_) {
      if (mounted) setState(() {});
    });
    tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MyCar?>(
        valueListenable: myCar,
        builder: (_, c, __) {
          if (c == null) {
            return Material(
              color: kInk,
              borderRadius: BorderRadius.circular(kRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadius),
                onTap: () => parkHere(context, widget.lots),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Row(children: [
                    LineIcon('car', size: 30, line: Colors.white, fill: Colors.white.withValues(alpha: 0.18)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        MixTitle('내 차', '어디 댔지', size: 15, color: Colors.white),
                        SizedBox(height: 2),
                        Text('지금 자리를 저장해 두면 요금·찾아가기를 도와드려요', style: TextStyle(fontSize: 11.5, color: Color(0xFFB9BCC6), height: 1.3)),
                      ]),
                    ),
                    const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ]),
                ),
              ),
            );
          }
          return CarCard(car: c);
        },
      );
}

// 주차 중 카드 (주차장 화면 · 단지 홈 공통)
class CarCard extends StatelessWidget {
  final MyCar car;
  final bool small;
  const CarCard({super.key, required this.car, this.small = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = car.freeEnds();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => openCar(context),
        child: Ink(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            const LineIcon('car', size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('주차 중', style: T.title),
                  const SizedBox(width: 6),
                  Flexible(child: Text(car.lot?.name ?? (car.memo.isEmpty ? '' : car.memo), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)),
                ]),
                const SizedBox(height: 3),
                Text(carLine(car, now), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                if (end != null && end.isAfter(now)) Text('무료 ${_hm(end)}까지', style: T.tiny),
              ]),
            ),
            if (!small) ...[
              const SizedBox(width: 8),
              SizedBox(width: 92, child: Btn('찾아가기', icon: 'route', primary: true, h: 40, onTap: () => startNav(context, name: '내 차', lat: car.lat, lng: car.lng))),
            ] else
              const Icon(Icons.chevron_right_rounded, color: kMute),
          ]),
        ),
      ),
    );
  }
}

// 단지 홈 맨 위 작은 카드 (주차 중일 때만, 아니면 빈칸)
class CarHomeCard extends StatefulWidget {
  const CarHomeCard({super.key});
  @override
  State<CarHomeCard> createState() => _CarHomeCardState();
}

class _CarHomeCardState extends State<CarHomeCard> {
  Timer? tick;
  @override
  void initState() {
    super.initState();
    loadCar().then((_) {
      if (mounted) setState(() {});
    });
    tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MyCar?>(
        valueListenable: myCar,
        builder: (_, c, __) => c == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: CarCard(car: c, small: true)),
      );
}

// 단지 홈 본문 카드 「내 차 어디 댔지」
class CarMainCard extends StatefulWidget {
  final Complex c;
  const CarMainCard({super.key, required this.c});
  @override
  State<CarMainCard> createState() => _CarMainCardState();
}

class _CarMainCardState extends State<CarMainCard> {
  Timer? tick;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    loadCar().then((_) {
      if (mounted) setState(() {});
    });
    tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  Future<void> _park() async {
    if (busy) return;
    setState(() => busy = true);
    final lots = await lotsNear(widget.c.pos, km: 2);
    if (mounted) setState(() => busy = false);
    if (!mounted) return;
    await parkHere(context, lots);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MyCar?>(
        valueListenable: myCar,
        builder: (_, car, __) {
          if (car != null) return CarCard(car: car);
          return MainRowCard(
            icon: 'car',
            bold: '내 차',
            thin: '어디 댔지',
            sub: '세운 곳을 남겨 두면 찾아가기와 예상 요금을 알려 드려요',
            trailing: SizedBox(width: 104, child: Btn(busy ? '확인 중' : '여기 세웠어요', primary: true, h: 40, onTap: _park)),
          );
        },
      );
}

// 「여기 세웠어요」: 지금 위치 + 가장 가까운 주차장 자동 고르기 + 층·구역 메모 + 받은 무료 시간
Future<void> parkHere(BuildContext context, List<Lot> lots) async {
  toast(context, '지금 위치를 확인하고 있어요');
  final p = await myLocation();
  if (!context.mounted) return;
  if (p == null) {
    toast(context, '위치를 알 수 없어요. 휴대폰 위치 켜기를 확인해 주세요');
    return;
  }
  final near = [...lots]..sort((a, b) => meters(p, a.pos).compareTo(meters(p, b.pos)));
  final cands = near.where((l) => meters(p, l.pos) <= 400).take(5).toList();
  Lot? pick = cands.isNotEmpty && meters(p, cands.first.pos) <= 150 ? cands.first : null;
  final memo = TextEditingController();
  var free = 0;
  await showSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16), children: [
        const MixTitle('여기', '세웠어요', size: 16.5),
        const SizedBox(height: 4),
        const Text('위치는 이 휴대폰에만 저장돼요. 서버로 보내지 않아요.', style: T.tiny),
        const SizedBox(height: 14),
        const Text('주차장', style: T.title),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in cands) ChoiceChipBox('${l.name} · ${distText(meters(p, l.pos))}', on: pick?.id == l.id, onTap: () => set(() => pick = l)),
          ChoiceChipBox(cands.isEmpty ? '근처 주차장 정보 없음' : '목록에 없어요', on: pick == null, onTap: () => set(() => pick = null)),
        ]),
        const SizedBox(height: 14),
        Field('층·구역 (선택)', memo, hint: '예: B2 · C-14, 기둥 번호', max: 30),
        const Text('받은 무료 시간 (마트·병원 등록 등)', style: T.title),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in const [0, 30, 60, 120, 180]) ChoiceChipBox(m == 0 ? '없음' : elapsedText(m), on: free == m, onTap: () => set(() => free = m)),
        ]),
        const SizedBox(height: 18),
        Btn('저장하기', icon: 'car', primary: true, onTap: () {
          saveCar(MyCar(lat: p.latitude, lng: p.longitude, at: DateTime.now(), memo: memo.text.trim(), freeMin: free, lot: pick));
          Navigator.pop(ctx);
        }),
      ]),
    ),
  );
}

// 내 차 화면 (세운 곳 · 경과 요금 · 찾아가기 · 출차 완료)
Future<void> openCar(BuildContext context) => showSheet(context, (ctx) {
      final c = myCar.value;
      if (c == null) return const SizedBox(height: 40);
      final now = DateTime.now();
      final end = c.freeEnds();
      final m = c.minutes(now);
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16), children: [
        const MixTitle('내 차', '어디 댔지', size: 16.5),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(elapsedText(m), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${_hm(c.at)}에 세움', style: T.small)),
          const Spacer(),
          Builder(builder: (_) {
            final w = c.cost(now);
            return Text(w == null ? '요금 모름' : (w == 0 ? '무료' : won(w)), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.4));
          }),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kv('주차장', c.lot?.name ?? '목록에 없는 곳'),
            if (c.memo.isNotEmpty) _kv('층·구역', c.memo),
            if (c.freeMin > 0) _kv('받은 무료', elapsedText(c.freeMin)),
            if (end != null) _kv('무료 끝', end.isAfter(now) ? '${_hm(end)} (10분 전에 알려 드려요)' : '${_hm(end)} 지남'),
            if (c.lot != null && c.lot!.basicMin > 0 && !c.lot!.isFree)
              _kv('요금표', '${c.lot!.basicMin}분 ${won(c.lot!.basicWon)}${c.lot!.addMin > 0 ? ' · ${c.lot!.addMin}분마다 ${won(c.lot!.addWon)}' : ''}${c.lot!.dayWon > 0 ? ' · 하루 ${won(c.lot!.dayWon)}' : ''}'),
          ]),
        ),
        const SizedBox(height: 6),
        const Text('예상 요금은 공공데이터 요금표로 계산한 값이에요. 실제 정산과 다를 수 있어요.', style: T.tiny),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Btn('출차 완료', onTap: () {
            saveCar(null);
            Navigator.pop(ctx);
            toast(context, '출차 완료. 저장한 위치를 지웠어요');
          })),
          const SizedBox(width: 10),
          Expanded(child: Btn('찾아가기', icon: 'route', primary: true, onTap: () => startNav(ctx, name: '내 차', lat: c.lat, lng: c.lng))),
        ]),
      ]);
    });

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 70, child: Text(k, style: T.small)),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, height: 1.35))),
      ]),
    );
