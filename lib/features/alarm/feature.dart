// 알람 (알람 담당: 본부, 대표님 요청 11-24)
// 앱이 직접 울리면 휴대폰이 잠들거나 절전일 때 놓칠 수 있어서, 휴대폰 기본 시계 앱에 알람을 넣는다 (확실히 울림).
// 앱에는 넣은 알람 목록만 남긴다 (이 휴대폰에만 저장, prefs: alarm.list). 끄기·지우기는 시계 앱에서.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/notify.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class AlarmFeature extends Feature {
  @override
  String get id => 'alarm';
  @override
  String get name => '알람';
  @override
  String get icon => 'alarm';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 61;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;

  @override
  Widget page(BuildContext context, Complex c) => const AlarmPage();
}

class _Alarm {
  final int h, m;
  final String label;
  final List<int> days; // 1=일 … 7=토
  const _Alarm(this.h, this.m, this.label, this.days);
  Map<String, dynamic> toJson() => {'h': h, 'm': m, 'l': label, 'd': days};
  static _Alarm fromJson(Map j) => _Alarm((j['h'] as num).toInt(), (j['m'] as num).toInt(), '${j['l'] ?? ''}', [for (final x in (j['d'] as List? ?? const [])) (x as num).toInt()]);
  String get time => '${h < 12 ? '오전' : '오후'} ${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')}';
  String get daysText {
    if (days.isEmpty) return '한 번';
    if (days.length == 7) return '매일';
    final s = days.toSet();
    if (s.length == 5 && s.containsAll([2, 3, 4, 5, 6])) return '평일';
    if (s.length == 2 && s.containsAll([1, 7])) return '주말';
    const n = ['', '일', '월', '화', '수', '목', '금', '토'];
    return [for (final d in [2, 3, 4, 5, 6, 7, 1]) if (s.contains(d)) n[d]].join(' ');
  }
}

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});
  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  List<_Alarm> list = [];

  @override
  void initState() {
    super.initState();
    prefGet('alarm.list').then((s) {
      if (s == null || s.isEmpty || !mounted) return;
      try {
        setState(() => list = [for (final j in jsonDecode(s) as List) _Alarm.fromJson(j as Map)]);
      } catch (_) {}
    });
  }

  Future<void> _save() => prefSet('alarm.list', jsonEncode([for (final a in list) a.toJson()]));

  Future<void> _add([_Alarm? preset]) async {
    final r = await showModalBottomSheet<_Alarm>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _Form(preset: preset),
    );
    if (r == null || !mounted) return;
    final ok = await setPhoneAlarm(r.h, r.m, r.label.isEmpty ? '요기콕 알람' : r.label, r.days);
    if (!mounted) return;
    if (!ok) {
      toast(context, '알람은 안드로이드 휴대폰 앱에서만 넣을 수 있어요');
      return;
    }
    setState(() => list = [...list, r]..sort((a, b) => (a.h * 60 + a.m).compareTo(b.h * 60 + b.m)));
    await _save();
  }

  // 자주 쓰는 알람 (대표님 시안 11-25: 입체 아이콘 칸 + 켜기 스위치)
  static const _presets = [
    (_Alarm(7, 0, '출근 준비', [2, 3, 4, 5, 6]), 'al_brief'),
    (_Alarm(8, 20, '아이 등원', [2, 3, 4, 5, 6]), 'al_cap'),
    (_Alarm(19, 30, '분리수거 내놓기', []), 'al_bin'),
    (_Alarm(22, 0, '약 먹기', [1, 2, 3, 4, 5, 6, 7]), 'al_pill'),
  ];
  static const _bg = Color(0xFFE8F1FD);

  int _find(_Alarm p) => list.indexWhere((a) => a.label == p.label);

  void _remove(int i) {
    setState(() => list = [...list]..removeAt(i));
    _save();
    toast(context, '목록에서 뺐어요. 울리는 알람은 시계 앱에서 꺼 주세요');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 760 ? 4 : 2;
    final artH = w.clamp(0.0, 900.0) * 1313 / 1198; // 배경 그림 높이 (너비에 맞춤)
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x400B52CF), blurRadius: 16)]),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _add(),
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              height: 56,
              padding: const EdgeInsets.fromLTRB(20, 0, 26, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2C7BEF), Color(0xFF0B4FC9)]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 26),
                SizedBox(width: 8),
                Text('알람 추가', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
              ]),
            ),
          ),
        ),
      ),
      body: Stack(children: [
        // 대표님 배경(시계·물결) — 아래는 바탕색 덮개로 녹여 경계선 없게, 사진은 덮개보다 2px 짧게
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: artH,
          child: ClipRect(
            child: Stack(fit: StackFit.expand, children: [
              Positioned(left: 0, right: 0, top: 0, bottom: 2, child: Image.asset('assets/art/alarm_bg.jpg', fit: BoxFit.cover, alignment: Alignment.topRight, filterQuality: FilterQuality.medium)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bg.withValues(alpha: 0), _bg.withValues(alpha: 0), _bg, _bg], stops: const [0, 0.55, 0.85, 1]),
                ),
              ),
            ]),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(padding: EdgeInsets.fromLTRB(kPad, top + 6, kPad, 100), children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, size: 26, color: Colors.white)),
                const SizedBox(width: 2),
                Image.asset('assets/icons/bell_add.png', width: 36, height: 36),
                const SizedBox(width: 8),
                const Text('알람', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Colors.white, shadows: [Shadow(color: Color(0x330B2A5B), blurRadius: 6)])),
              ]),
              SizedBox(height: (w * 0.1).clamp(14.0, 60.0)),
              // 안내: 흰 알약 상자 (오른쪽은 배경 시계가 보이도록 여백)
              Padding(
                padding: EdgeInsets.only(right: w < 600 ? 0 : w * 0.18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x1A0B2A5B), blurRadius: 14)]),
                  child: const Row(children: [
                    LineIcon('alarm', size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '휴대폰 시계 앱에 알람을 넣어 드려요.\n', style: TextStyle(fontWeight: FontWeight.w700, color: kInk)),
                          TextSpan(text: '잠금·절전 중에도 확실히 울려요.\n끄거나 지울 때는 '),
                          TextSpan(text: '시계 앱', style: TextStyle(fontWeight: FontWeight.w700, color: kInk)),
                          TextSpan(text: '에서 해 주세요.'),
                        ]),
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5468), height: 1.45),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 26),
              _head('자주 쓰는 알람'),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, box) {
                final cw = (box.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final (p, icon) in _presets) SizedBox(width: cw, child: _preset(p, icon)),
                ]);
              }),
              if (list.isNotEmpty) ...[
                const SizedBox(height: 26),
                _head('넣은 알람'),
                const SizedBox(height: 12),
                for (var i = 0; i < list.length; i++) ...[
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3EAF5)), boxShadow: const [BoxShadow(color: Color(0x120B2A5B), blurRadius: 12)]),
                    padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                    child: Row(children: [
                      const Icon(Icons.alarm_rounded, size: 26, color: kBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(list[i].time, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
                          Text('${list[i].label.isEmpty ? '알람' : list[i].label} · ${list[i].daysText}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF5A6475))),
                        ]),
                      ),
                      IconButton(tooltip: '목록에서 빼기', icon: const Icon(Icons.close_rounded, color: kSub), onPressed: () => _remove(i)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _head(String t) => Row(children: [
        Container(width: 3, height: 19, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 9),
        Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
      ]);

  // 자주 쓰는 알람 한 칸: 입체 아이콘 · 이름 · 시각 · 켜기 스위치 (켜면 시계 앱에 넣기, 끄면 목록에서 빼기) · 켜진 칸은 아래 옅은 파랑 띠
  Widget _preset(_Alarm p, String icon) {
    final i = _find(p);
    final on = i >= 0;
    final narrow = MediaQuery.of(context).size.width < 380;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: on ? const Color(0x262C7BEF) : const Color(0x140B2A5B), blurRadius: 14)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => on ? _remove(i) : _add(p),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFF3F8FF)]),
                border: Border(bottom: BorderSide(color: on ? const Color(0xFF7DB6F7) : const Color(0xFFE1E7F0), width: 3)),
              ),
              padding: EdgeInsets.fromLTRB(narrow ? 12 : 16, 14, narrow ? 8 : 12, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset('assets/icons/$icon.png', width: narrow ? 50 : 58, height: narrow ? 50 : 58),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(p.label, maxLines: 1, style: TextStyle(fontSize: narrow ? 14.5 : 16, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: kInk)),
                      ),
                      const SizedBox(height: 3),
                      Text('${p.time} · ${p.daysText}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: narrow ? 11.5 : 12.5, color: const Color(0xFF5A6475))),
                    ]),
                  ),
                  Transform.scale(
                    scale: narrow ? 0.78 : 0.85,
                    child: Switch(
                      value: on,
                      thumbColor: const WidgetStatePropertyAll(Colors.white),
                      activeTrackColor: const Color(0xFF2C7BEF),
                      inactiveTrackColor: const Color(0xFFC9D2DE),
                      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                      onChanged: (v) => v ? _add(p) : _remove(i),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  final _Alarm? preset;
  const _Form({this.preset});
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late TimeOfDay t = TimeOfDay(hour: widget.preset?.h ?? 7, minute: widget.preset?.m ?? 0);
  late final label = TextEditingController(text: widget.preset?.label ?? '');
  late Set<int> days = {...(widget.preset?.days ?? const [2, 3, 4, 5, 6])};

  @override
  Widget build(BuildContext context) {
    const n = ['', '일', '월', '화', '수', '목', '금', '토'];
    final a = _Alarm(t.hour, t.minute, '', days.toList());
    return Padding(
      padding: EdgeInsets.fromLTRB(kPad, 18, kPad, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const MixTitle('알람', '넣기', size: 17),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final r = await showTimePicker(context: context, initialTime: t);
            if (r != null) setState(() => t = r);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(a.time, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: kBlue)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in [2, 3, 4, 5, 6, 7, 1]) ChoiceChipBox(n[d], on: days.contains(d), onTap: () => setState(() => days.contains(d) ? days.remove(d) : days.add(d))),
        ]),
        const SizedBox(height: 4),
        Text(days.isEmpty ? '요일을 안 고르면 한 번만 울려요' : '${a.daysText} 울려요', style: T.tiny),
        const SizedBox(height: 12),
        Field('이름 (선택)', label, hint: '예: 출근 준비', max: 20),
        Btn('시계 앱에 넣기', primary: true, onTap: () => Navigator.pop(context, _Alarm(t.hour, t.minute, label.text.trim(), (days.toList()..sort())))),
      ]),
    );
  }
}
