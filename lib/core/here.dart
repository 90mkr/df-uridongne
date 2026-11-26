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
const kNearbyFeatures = {'toilet', 'phonebook', 'pharmacy', 'charger', 'gas', 'parking', 'pet', 'events', 'lotto', 'postcode', 'subway', 'bus'};

// 단지에서 이만큼 떨어져 있으면 저절로 「지금 내 위치」 기준
const _farM = 1500.0;

// 이번에 앱을 켜 있는 동안 고른 기준 (null = 저절로: 멀면 내 위치)
final hereChoice = ValueNotifier<bool?>(null);

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
  LatLng? pos;
  bool busy = false;

  bool get _far => pos != null && meters(pos!, widget.home.pos) > _farM;
  bool get _useHere => pos != null && (hereChoice.value ?? _far);

  @override
  void initState() {
    super.initState();
    pos = myPos.value;
    _locate(ask: false);
  }

  Future<void> _locate({required bool ask}) async {
    final p = await myLocation(ask: ask).timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (!mounted) return;
    if (p != null) setState(() => pos = p);
  }

  Future<void> _toggle() async {
    if (_useHere) {
      hereChoice.value = false;
      setState(() {});
      return;
    }
    if (pos == null) {
      setState(() => busy = true);
      await _locate(ask: true);
      if (!mounted) return;
      setState(() => busy = false);
      if (pos == null) {
        toast(context, '위치를 알 수 없어요. 휴대폰 위치(GPS)를 켜 주세요');
        return;
      }
    }
    hereChoice.value = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final here = _useHere;
    final c = here ? hereComplex(pos!, widget.home) : widget.home;
    return Stack(children: [
      KeyedSubtree(key: ValueKey(c.id), child: widget.builder(context, c)),
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
  }
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
