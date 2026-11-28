// 「어디 기준」 — 우리 단지 / 지금 내 위치 (대표님 11-26)
// 집을 나와 시내에서 화장실·약국·가게를 찾으면 우리 단지가 아니라 지금 있는 곳 기준이어야 한다.
// 근처를 찾는 기능 화면에 작은 알약 단추를 띄우고, 단지에서 멀리 나와 있으면 저절로 「지금 내 위치」로 연다.
// 기능 방은 따로 고칠 것 없음: 화면에 넘겨주는 단지(Complex)를 「지금 내 위치」 가상 단지로 바꿔 준다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'theme.dart';
import 'ui.dart';

// 근처를 찾는 기능 (여기 든 기능만 알약 단추가 뜬다)
const kNearbyFeatures = {'weather', 'air', 'toilet', 'phonebook', 'pharmacy', 'charger', 'gas', 'parking', 'pet', 'events', 'lotto', 'postcode', 'subway', 'bus'};

// 단지에서 이만큼 떨어져 있으면 저절로 「지금 내 위치」 기준
const _farM = 1500.0;

// 이번에 앱을 켜 있는 동안 고른 기준 (null = 저절로: 멀면 내 위치)
final hereChoice = ValueNotifier<bool?>(null);
// 그 기준을 고른 곳 — 거기서 1.5km 넘게 움직이면 고른 것을 잊고 다시 저절로 (대표님 11-27: 송도에서 「우리 단지로」 눌러 둔 채 용인 가면 계속 송도)
LatLng? _choiceAt;

// 지금 위치에 세운 가상 단지 (id 'here_…' — 단지 게시판·단지별 저장과 섞이지 않게)
Complex hereComplex(LatLng p, Complex home) {
  final a = areaAt(p);
  return Complex(
    id: 'here_${p.latitude.toStringAsFixed(3)}_${p.longitude.toStringAsFixed(3)}',
    name: '지금 내 위치',
    addr: a?.name ?? '',
    areaId: a?.id ?? home.areaId,
    lat: p.latitude,
    lng: p.longitude,
  );
}

extension ComplexHere on Complex {
  bool get isHere => id.startsWith('here_');
}

// ───────── 앱 전체 「기준 하나」 (대표님 11-28: 기능마다 따로 바꾸게 하지 말고 한 번에) ─────────
// 홈 카드·기능 화면 모두 baseFor() 로 단지를 받는다. 홈 맨 위 「우리 집 | 지금 여기」 한 곳에서 바꾸면 전부 따라온다.
final baseTick = ValueNotifier<int>(0);
LatLng? _tickAt;

bool useHereFor(Complex home) {
  final p = myPos.value;
  if (p == null) return false;
  return hereChoice.value ?? (meters(p, home.pos) > _farM);
}

/// 이 기능이 지금 볼 단지 — 근처 기능이고 「지금 여기」 기준이면 지금 위치에 세운 가상 단지
Complex baseFor(Complex home, String featureId) =>
    kNearbyFeatures.contains(featureId) && useHereFor(home) ? hereComplex(myPos.value!, home) : home;

void setHereChoice(bool? v) {
  hereChoice.value = v;
  _choiceAt = v == null ? null : myPos.value;
  baseTick.value++;
}

void _onMyPos() {
  final p = myPos.value;
  if (p == null) return;
  // 고른 곳에서 1.5km 넘게 움직이면 고른 것을 잊고 다시 저절로
  if (_choiceAt != null && meters(p, _choiceAt!) > _farM) {
    hereChoice.value = null;
    _choiceAt = null;
    _tickAt = p;
    baseTick.value++;
    return;
  }
  // 300m 넘게 움직였을 때만 다시 그림 (걸을 때마다 깜빡이지 않게)
  if (_tickAt == null || meters(p, _tickAt!) > 300) {
    _tickAt = p;
    baseTick.value++;
  }
}

class _HereWatch with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) myLocation(ask: false);
  }
}

bool _watching = false;

/// 앱이 켜질 때 한 번 (shell): 위치를 지켜보다 바뀌면 baseTick 으로 알림 — 다시 열 때·3분마다 조용히 위치 확인
void startHereWatch() {
  if (_watching) return;
  _watching = true;
  myPos.addListener(_onMyPos);
  WidgetsBinding.instance.addObserver(_HereWatch());
  myLocation(ask: false);
  Timer.periodic(const Duration(minutes: 3), (_) => myLocation(ask: false));
}

/// 「지금 여기」로 바꾸기 (위치 권한이 없으면 묻는다). 못 찾으면 false
Future<bool> switchToHere() async {
  final p = myPos.value ?? await myLocation(ask: true).timeout(const Duration(seconds: 12), onTimeout: () => null);
  if (p == null) return false;
  setHereChoice(true);
  return true;
}

/// 홈 맨 위 「우리 집 | 지금 여기」
class BaseSwitch extends StatefulWidget {
  final Complex home;
  final bool compact; // 홈 머리 단지 이름 옆 (날씨 자리, 대표님 11-28)
  const BaseSwitch({super.key, required this.home, this.compact = false});
  @override
  State<BaseSwitch> createState() => _BaseSwitchState();
}

class _BaseSwitchState extends State<BaseSwitch> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: baseTick,
        builder: (context, _, __) {
          final here = useHereFor(widget.home);
          final homeName = widget.home.isHome ? '우리 집' : '우리 단지';
          final town = here ? (areaAt(myPos.value!)?.name ?? '') : '';
          final cp = widget.compact;
          Widget seg(bool on, IconData ic, String t, VoidCallback tap) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: on || busy ? null : tap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: cp ? 32 : 34,
                    decoration: BoxDecoration(
                      color: on ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: on ? Border.all(color: const Color(0xFFC9D8FB)) : null,
                      boxShadow: on ? const [BoxShadow(color: Color(0x141C3A6E), blurRadius: 8)] : null,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: cp ? 6 : 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(ic, size: cp ? 14 : 15, color: on ? kBlue : Colors.white),
                      SizedBox(width: cp ? 3 : 5),
                      Flexible(
                        child: Text(t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: cp ? 12.5 : 13, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? kInk : Colors.white, letterSpacing: -0.3)),
                      ),
                    ]),
                  ),
                ),
              );
          final row = Row(children: [
              seg(!here, Icons.home_rounded, cp ? '집' : '$homeName 기준', () => setHereChoice(false)),
              seg(here, busy ? Icons.more_horiz_rounded : Icons.my_location_rounded, cp ? '현재 위치' : (here && town.isNotEmpty ? '지금 여기 · $town' : '지금 여기 기준'), () async {
                setState(() => busy = true);
                final ok = await switchToHere();
                if (!mounted) return;
                setState(() => busy = false);
                if (!ok) toast(context, '위치를 찾지 못했어요. 위치 권한을 켜 주세요');
              }),
            ]);
          return Container(
            width: cp ? 158 : null,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFF8F99A8), borderRadius: BorderRadius.circular(21)), // 진한 회색 바탕 + 흰 글씨 (대표님 11-28: 단추처럼 보이게)
            child: row,
          );
        },
      );
}

/// 기능 화면을 감싸 「우리 단지 / 지금 내 위치」 기준을 바꿔 준다
class HereFrame extends StatefulWidget {
  final String featureId;
  final Complex home;
  final Widget Function(BuildContext, Complex) builder;
  const HereFrame({super.key, required this.featureId, required this.home, required this.builder});

  @override
  State<HereFrame> createState() => _HereFrameState();
}

class _HereFrameState extends State<HereFrame> {
  bool busy = false;

  Future<void> _toggle() async {
    if (useHereFor(widget.home)) {
      setHereChoice(false);
      return;
    }
    setState(() => busy = true);
    final ok = await switchToHere();
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) toast(context, '위치를 찾지 못했어요. 위치 권한을 켜 주세요');
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: baseTick,
        builder: (context, _, __) {
          final here = useHereFor(widget.home);
          final c = baseFor(widget.home, widget.featureId);
          return Stack(children: [
            // 알약이 목록 맨 아래를 가리지 않게 아래 여백을 더 준다
            MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: MediaQuery.of(context).padding.copyWith(bottom: MediaQuery.of(context).padding.bottom + 64)),
              child: KeyedSubtree(key: ValueKey(c.id), child: widget.builder(context, c)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Center(child: _Pill(here: here, busy: busy, homeName: widget.home.isHome ? '우리 집' : '우리 단지', onTap: _toggle)),
                ),
              ),
            ),
          ]);
        },
      );
}

class _Pill extends StatelessWidget {
  final bool here, busy;
  final String homeName;
  final VoidCallback onTap;
  const _Pill({required this.here, required this.busy, required this.homeName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kLine),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6))
                : Icon(here ? Icons.my_location_rounded : Icons.home_outlined, size: 16, color: kBlue),
            const SizedBox(width: 7),
            Text(here ? '지금 내 위치 기준' : '$homeName 기준',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -0.3)),
            Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 10), color: kLine),
            Text(here ? '$homeName으로' : '내 위치로',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kBlue, letterSpacing: -0.3)),
          ]),
        ),
      ),
    );
  }
}

/// 기능 화면 만들기 — 근처 기능이면 「어디 기준」 틀로 감싼다
Widget featurePage(BuildContext context, String id, Complex c, Widget Function(BuildContext, Complex) build) =>
    kNearbyFeatures.contains(id) ? HereFrame(featureId: id, home: c, builder: build) : build(context, c);
