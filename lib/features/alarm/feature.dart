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
  String get version => '0.1.0';
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
    final ok = await setPhoneAlarm(r.h, r.m, r.label.isEmpty ? '우리동네 알람' : r.label, r.days);
    if (!mounted) return;
    if (!ok) {
      toast(context, '알람은 안드로이드 휴대폰 앱에서만 넣을 수 있어요');
      return;
    }
    setState(() => list = [...list, r]..sort((a, b) => (a.h * 60 + a.m).compareTo(b.h * 60 + b.m)));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('알람', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('알람 추가', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 96), children: [
            Container(
              decoration: cardBox(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: const Row(children: [
                LineIcon('alarm', size: 30),
                SizedBox(width: 10),
                Expanded(child: Text('휴대폰 시계 앱에 알람을 넣어 드려요. 잠금·절전 중에도 확실히 울려요. 끄거나 지울 때는 시계 앱에서 해 주세요.', style: T.small)),
              ]),
            ),
            const SizedBox(height: 14),
            const MixTitle('자주 쓰는', '알람', size: 15),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in const [
                _Alarm(7, 0, '출근 준비', [2, 3, 4, 5, 6]),
                _Alarm(8, 20, '아이 등원', [2, 3, 4, 5, 6]),
                _Alarm(19, 30, '분리수거 내놓기', []),
                _Alarm(22, 0, '약 먹기', [1, 2, 3, 4, 5, 6, 7]),
              ])
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _add(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: cardBox(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(p.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text('${p.time} · ${p.daysText}', style: T.tiny),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            if (list.isNotEmpty) ...[
              const MixTitle('넣은', '알람', size: 15),
              const SizedBox(height: 8),
              for (var i = 0; i < list.length; i++) ...[
                Container(
                  decoration: cardBox(),
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(list[i].time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        Text('${list[i].label.isEmpty ? '알람' : list[i].label} · ${list[i].daysText}', style: T.small),
                      ]),
                    ),
                    IconButton(
                      tooltip: '목록에서 빼기',
                      icon: const Icon(Icons.close_rounded, color: kSub),
                      onPressed: () {
                        setState(() => list = [...list]..removeAt(i));
                        _save();
                        toast(context, '목록에서 뺐어요. 울리는 알람은 시계 앱에서 꺼 주세요');
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ]),
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
