// 내 차 어디 댔지 (이 폴더는 주차장 담당 방만 고침)
// 세운 위치·시각·주차장·층/구역 메모는 휴대폰 안(prefSet 'parking.car')에만 저장한다. 서버로 보내지 않는다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/here.dart';
import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'page.dart';

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

// 세운 자리 사진 — 이 휴대폰에만 저장 (서버로 안 보냄). 출차 완료하면 지움
final carPhoto = ValueNotifier<Uint8List?>(null);

Future<void> saveCarPhoto(Uint8List? b) async {
  carPhoto.value = b;
  await prefSet('parking.carPhoto', b == null ? '' : base64Encode(b));
}

Future<Uint8List?> takeCarPhoto() async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    return x == null ? null : await x.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<MyCar?> loadCar() async {
  if (_loaded) return myCar.value;
  _loaded = true;
  try {
    final s = await prefGet('parking.car');
    if (s != null && s.isNotEmpty) myCar.value = MyCar.fromJson(jsonDecode(s));
    final ph = await prefGet('parking.carPhoto');
    if (ph != null && ph.isNotEmpty) carPhoto.value = base64Decode(ph);
  } catch (_) {}
  _watch();
  return myCar.value;
}

Future<void> saveCar(MyCar? c) async {
  myCar.value = c;
  if (c == null) await saveCarPhoto(null);
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
            return Container(
              decoration: _carBox,
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(children: [
                Image.asset('assets/icons/car.png', width: 52, height: 52),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('내 차 어디 댔지', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
                    SizedBox(height: 3),
                    Text('세운 자리를 저장하면\n요금 계산·찾아가기를 도와드려요', style: TextStyle(fontSize: 11.5, color: kSub, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 8),
                _BlueBtn('여기 세웠어요', icon: Icons.add_rounded, onTap: () => parkHere(context, widget.lots)),
              ]),
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
        borderRadius: BorderRadius.circular(18),
        onTap: () => openCar(context),
        child: Ink(
          decoration: _carBox,
          padding: EdgeInsets.fromLTRB(14, small ? 10 : 12, 12, small ? 10 : 12), // 주차 카드 줄임 (대표님 11-28)
          child: Row(children: [
            Image.asset('assets/icons/car.png', width: small ? 34 : 40, height: small ? 34 : 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('주차 중', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kInk)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(car.lot?.name ?? car.memo, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny)),
                ]),
                const SizedBox(height: 2),
                Text(carLine(car, now), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: small ? 14 : 15, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: kInk)),
                if (end != null && end.isAfter(now)) Text('무료 ${_hm(end)}까지', style: T.tiny),
              ]),
            ),
            if (!small) ...[
              const SizedBox(width: 8),
              _BlueBtn('찾아가기', iconName: 'route', onTap: () => startNav(context, name: '내 차', lat: car.lat, lng: car.lng, walk: true)),
            ] else
              const Icon(Icons.chevron_right_rounded, color: kMute),
          ]),
        ),
      ),
    );
  }
}

final _carBox = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFFE4EAF3)),
  boxShadow: const [BoxShadow(color: Color(0x141E3A6E), blurRadius: 20)],
);

// 파란 단추 (찾아가기 · 여기 세웠어요)
class _BlueBtn extends StatelessWidget {
  final String text;
  final IconData? icon;
  final String? iconName;
  final VoidCallback onTap;
  const _BlueBtn(this.text, {this.icon, this.iconName, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: kBlue,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (iconName != null) LineIcon(iconName!, size: 16, line: Colors.white, fill: Colors.transparent),
              if (icon != null) Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
            ]),
          ),
        ),
      );
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
        builder: (_, car, __) => _carPart(car),
      );

  Widget _carPart(MyCar? car) {
          if (car != null) return CarCard(car: car);
          return MainRowCard(
            icon: 'car',
            bold: '내 차',
            thin: '어디 댔지',
            sub: '세운 곳을 남겨 두면 찾아가기와 예상 요금을 알려 드려요',
            trailing: SizedBox(width: 104, child: Btn(busy ? '확인 중' : '여기 세웠어요', primary: true, h: 40, onTap: _park)),
          );
  }
}

// 단지 홈: 가까운 공영주차장 3곳 (이름 · 거리 · 요금, 지금 무료면 초록) — 누르면 주차장 화면 (대표님 11-25)
class NearLotsCard extends StatefulWidget {
  final Complex c;
  const NearLotsCard({super.key, required this.c});
  @override
  State<NearLotsCard> createState() => _NearLotsCardState();
}

class _NearLotsCardState extends State<NearLotsCard> {
  List<Lot>? lots;
  @override
  void initState() {
    super.initState();
    lotsNear(widget.c.pos, km: 3).then((l) {
      if (!mounted) return;
      final pub = l.where((x) => x.kind.contains('공영')).toList();
      setState(() => lots = (pub.length >= 3 ? pub : l).take(3).toList());
    }).catchError((_) {
      if (mounted) setState(() => lots = const []);
    });
  }

  void _open() => pushNearby(context, 'parking', widget.c, (b) => ParkingPage(complex: b));

  @override
  Widget build(BuildContext context) {
    final l = lots;
    if (l != null && l.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Container(
      decoration: cardBox(r: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const LineIcon('parking', size: 28),
          const SizedBox(width: 8),
          const Expanded(child: MixTitle('주차', '어디 하지', size: 16)),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _open,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 4, 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('전체 보기', style: TextStyle(fontSize: 12.5, color: kSub)),
                Icon(Icons.chevron_right_rounded, size: 18, color: kSub),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        if (l == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
        else
          for (final (i, x) in l.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEFF2F6)),
            InkWell(
              onTap: _open,
              child: SizedBox(
                height: 50,
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                      Text([distText(meters(widget.c.pos, x.pos)), if (x.label.isNotEmpty) x.label, if (x.spaces > 0) '${x.spaces}면'].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: x.freeAt(now) ? const Color(0xFFE3F5EB) : const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(x.freeAt(now) ? '지금 무료' : x.feeShort,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: x.freeAt(now) ? const Color(0xFF1C8A5A) : kBlue)),
                  ),
                  const SizedBox(width: 4),
                ]),
              ),
            ),
          ],
      ]),
    );
  }
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
  Uint8List? shot;
  await showSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 16), children: [
        const MixTitle('여기', '세웠어요', size: 16.5),
        const SizedBox(height: 4),
        const Text('위치·사진은 이 휴대폰에만 저장돼요. 서버로 보내지 않아요.', style: T.tiny),
        const SizedBox(height: 14),
        const Text('주차장', style: T.title),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in cands) ChoiceChipBox('${l.name} · ${distText(meters(p, l.pos))}', on: pick?.id == l.id, onTap: () => set(() => pick = l)),
          ChoiceChipBox(cands.isEmpty ? '근처 주차장 정보 없음' : '목록에 없어요', on: pick == null, onTap: () => set(() => pick = null)),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Field('층·구역 (선택)', memo, hint: '예: B2 · C-14, 기둥 번호', max: 30)),
          const SizedBox(width: 8),
          // 오른쪽 사진 단추: 기둥 번호·표지판을 찍어 두기
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final b = await takeCarPhoto();
                if (b != null) set(() => shot = b);
              },
              child: Container(
                width: 50,
                height: 50,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine), color: Colors.white),
                child: shot != null ? Image.memory(shot!, fit: BoxFit.cover) : const Icon(Icons.photo_camera_outlined, size: 22, color: kSub),
              ),
            ),
          ),
        ]),
        const Text('받은 무료 시간 (마트·병원 등록 등)', style: T.title),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in const [0, 30, 60, 120, 180]) ChoiceChipBox(m == 0 ? '없음' : elapsedText(m), on: free == m, onTap: () => set(() => free = m)),
        ]),
        const SizedBox(height: 18),
        Btn('저장하기', icon: 'car', primary: true, onTap: () {
          saveCarPhoto(shot);
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
        if (carPhoto.value case final ph?) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => showDialog(
              context: ctx,
              builder: (d) => GestureDetector(onTap: () => Navigator.pop(d), child: InteractiveViewer(child: Image.memory(ph, fit: BoxFit.contain))),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(ph, height: 170, width: double.infinity, fit: BoxFit.cover)),
          ),
        ],
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
          Expanded(child: Btn('찾아가기', icon: 'route', primary: true, onTap: () => startNav(ctx, name: '내 차', lat: c.lat, lng: c.lng, walk: true))),
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
