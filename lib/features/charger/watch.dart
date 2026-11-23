// 빈자리 알림 · 충전 타이머 (이 폴더는 충전소 담당 방만 고침)
// 지금은 앱이 켜져 있는 동안 앱 안에서 알립니다(진동 + 알림 창).
// 휴대폰 알림(앱을 닫아도 울리는 것)은 본부에 공용 알림 부품을 요청해 두었고, 생기면 notify() 한 곳만 바꾸면 됩니다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import 'data.dart';

BuildContext? _root;

// 상세 화면이 열릴 때 앱 맨 바깥 화면을 잡아 둔다 (상세 화면을 닫아도 알림 창을 띄울 수 있게)
void bindRoot(BuildContext context) {
  try {
    _root = Navigator.of(context, rootNavigator: true).context;
  } catch (_) {}
}

Future<void> notify(String title, String body) async {
  try {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  } catch (_) {}
  final ctx = _root;
  if (ctx == null || !ctx.mounted) return;
  await showDialog<void>(
    context: ctx,
    barrierColor: Colors.black.withValues(alpha: 0.12),
    builder: (c) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45, color: kSub)),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w700)))],
    ),
  );
}

// ---------------- 빈자리 알림 ----------------
class Watch {
  final Station s;
  final Set<String> plugs;
  final DateTime until;
  Watch(this.s, this.plugs, this.until);
}

final watches = ValueNotifier<List<Watch>>([]);
Timer? _tick;

bool isWatching(Station s) => watches.value.any((w) => w.s.id == s.id);

void startWatch(Station s, Set<String> plugs) {
  if (isWatching(s)) return;
  watches.value = [...watches.value, Watch(s, {...plugs}, DateTime.now().add(const Duration(hours: 1)))];
  _ensureTick();
}

void stopWatch(Station s) => watches.value = watches.value.where((w) => w.s.id != s.id).toList();

void _ensureTick() {
  _tick ??= Timer.periodic(const Duration(seconds: 45), (_) => _check());
}

Future<void> _check() async {
  final now = DateTime.now();
  // 충전 타이머
  final t = chargeTimer.value;
  if (t != null) {
    if (!t.warned && t.fast && now.isAfter(t.start.add(const Duration(minutes: 50))) && now.isBefore(t.end)) {
      chargeTimer.value = t.copy(warned: true);
      await notify('급속 충전 50분이 지났어요', '급속 충전구역은 1시간을 넘겨 세워 두면 과태료가 나올 수 있어요. 곧 차를 빼 주세요.');
    }
    final t2 = chargeTimer.value;
    if (t2 != null && now.isAfter(t2.end)) {
      await stopTimer();
      await notify(
        '충전이 끝날 시간이에요',
        t2.fast
            ? '${t2.name.isEmpty ? '' : '${t2.name}\n'}이제 차를 빼 주세요. 급속 충전구역은 1시간을 넘기면 과태료(10만 원)가 나올 수 있어요.'
            : '${t2.name.isEmpty ? '' : '${t2.name}\n'}완속 충전구역은 14시간을 넘기면 과태료가 나올 수 있어요.',
      );
    }
  }
  // 빈자리 알림
  for (final w in [...watches.value]) {
    if (now.isAfter(w.until)) {
      stopWatch(w.s);
      await notify('빈자리 알림을 껐어요', '${w.s.name}\n1시간 동안 빈 충전기가 나오지 않아 알림을 껐어요.');
      continue;
    }
    await refreshStation(w.s);
    final free = w.s.pick(plugs: w.plugs).where((c) => c.use == Use.free).length;
    if (free > 0) {
      stopWatch(w.s);
      await notify('빈 충전기가 생겼어요', '${w.s.name}\n내 차에 맞는 충전기 $free대가 지금 비어 있어요.');
    }
  }
  if (watches.value.isEmpty && chargeTimer.value == null) {
    _tick?.cancel();
    _tick = null;
  }
}

// ---------------- 충전 타이머 ----------------
class ChargeTimer {
  final String name;
  final bool fast;
  final DateTime start, end;
  final bool warned;
  const ChargeTimer(this.name, this.fast, this.start, this.end, {this.warned = false});
  ChargeTimer copy({bool? warned}) => ChargeTimer(name, fast, start, end, warned: warned ?? this.warned);
  Map<String, dynamic> toJson() => {'n': name, 'f': fast, 's': start.millisecondsSinceEpoch, 'e': end.millisecondsSinceEpoch, 'w': warned};
  static ChargeTimer? fromJson(dynamic j) {
    if (j is! Map) return null;
    return ChargeTimer('${j['n'] ?? ''}', j['f'] == true, DateTime.fromMillisecondsSinceEpoch((j['s'] as num).toInt()),
        DateTime.fromMillisecondsSinceEpoch((j['e'] as num).toInt()),
        warned: j['w'] == true);
  }
}

final chargeTimer = ValueNotifier<ChargeTimer?>(null);
bool _timerLoaded = false;

Future<void> loadTimer() async {
  if (_timerLoaded) return;
  _timerLoaded = true;
  try {
    final v = await prefGet('charger.timer');
    if (v == null || v.isEmpty) return;
    chargeTimer.value = ChargeTimer.fromJson(jsonDecode(v));
    if (chargeTimer.value != null) {
      _ensureTick();
      unawaited(_check());
    }
  } catch (_) {}
}

Future<void> startTimer(String name, bool fast, Duration d) async {
  final now = DateTime.now();
  chargeTimer.value = ChargeTimer(name, fast, now, now.add(d));
  await prefSet('charger.timer', jsonEncode(chargeTimer.value!.toJson()));
  _ensureTick();
}

Future<void> stopTimer() async {
  chargeTimer.value = null;
  await prefSet('charger.timer', '');
}

String clockText(DateTime t) {
  final h = t.hour, m = '${t.minute}'.padLeft(2, '0');
  return '${h < 12 ? '오전' : '오후'} ${h % 12 == 0 ? 12 : h % 12}:$m';
}

String leftText(DateTime end) {
  final m = end.difference(DateTime.now()).inMinutes;
  if (m <= 0) return '곧 끝나요';
  if (m < 60) return '$m분 남음';
  return '${m ~/ 60}시간 ${m % 60}분 남음';
}
