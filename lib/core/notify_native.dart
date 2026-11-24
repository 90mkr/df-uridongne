// 휴대폰: flutter_local_notifications 로 정해진 때 알림, 안드로이드 SET_ALARM 으로 시계 앱 알람
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final _p = FlutterLocalNotificationsPlugin();
bool _inited = false;

bool get canNotify => Platform.isAndroid || Platform.isIOS;

Future<void> initNotify() async {
  if (_inited) return;
  _inited = true;
  try {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
  } catch (_) {}
}

Future<bool> askNotePermission() async {
  await initNotify();
  try {
    final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) return await a.requestNotificationsPermission() ?? true;
    final i = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (i != null) return await i.requestPermissions(alert: true, sound: true) ?? false;
  } catch (_) {}
  return false;
}

Future<void> scheduleNote(int id, DateTime when, String title, String body) async {
  await initNotify();
  if (!when.isAfter(DateTime.now())) return;
  try {
    await _p.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('anniv', '기념일 알림', channelDescription: '등록한 기념일을 미리 알려 드려요', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  } catch (_) {}
}

Future<void> cancelNote(int id) async {
  await initNotify();
  try {
    await _p.cancel(id);
  } catch (_) {}
}

/// 휴대폰 기본 시계 앱에 알람 넣기. days: 1=일 2=월 … 7=토 (안드로이드 Calendar 값)
Future<bool> setPhoneAlarm(int hour, int minute, String label, List<int> days) async {
  if (!Platform.isAndroid) return false;
  try {
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        if (label.isNotEmpty) 'android.intent.extra.alarm.MESSAGE': label,
        if (days.isNotEmpty) 'android.intent.extra.alarm.DAYS': days,
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    await intent.launch();
    return true;
  } catch (_) {
    return false;
  }
}
