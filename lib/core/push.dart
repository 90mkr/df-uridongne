// 휴대폰 알림 받기 (본부 방만 고침) — 파이어베이스 메시징 「주제」 구독
// 게시판 알림 고르기 (대표님 11-25): 게시판·범위마다 켜고 끄기. 처음엔 공지·소식만 켜짐.
//   주제 이름: dn_b_<게시판키>_<분류>  (게시판키 = 단지 id 또는 a_<동네id>)
//             dn_u_<회원id>            (내 글에 댓글)
// 보내는 쪽은 서버(깃허브 「알림 보내기」)가 새 글을 보고 그 주제로 보낸다.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'data.dart';
import 'fb.dart';

// 게시판 분류 (board/data.dart 의 kBoards 와 같게)
const kPushCats = ['news', 'share', 'free', 'rec', 'lost'];

String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');

String boardTopic(String boardKey, String cat) => _safe('dn_b_${boardKey}_$cat');
String userTopic(String uid) => _safe('dn_u_$uid');

// 기본값: 공지·소식만 켜짐, 내 글 댓글 켜짐
bool defaultOn(String key) => key.endsWith('.news') || key == 'mycomment';

Future<bool> pushOn(String key) async {
  final v = await prefGet('push.$key');
  return v == null ? defaultOn(key) : v == '1';
}

Future<bool> _ready() async {
  if (kIsWeb) return false;
  if (!await fbReady()) return false;
  try {
    final s = await FirebaseMessaging.instance.requestPermission();
    return s.authorizationStatus != AuthorizationStatus.denied;
  } catch (_) {
    return false;
  }
}

Future<void> setPush(String key, String topic, bool on) async {
  await prefSet('push.$key', on ? '1' : '0');
  if (!await _ready()) return;
  try {
    if (on) {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
  } catch (_) {}
}

// 단지를 고르거나 앱을 켤 때: 저장된 켜기/끄기대로 다시 구독 (단지가 바뀌면 옛 단지 주제는 끔)
Future<void> syncPush(Complex c, [List<String> cats = kPushCats]) async {
  if (!await _ready()) return;
  final prev = await prefGet('push.complex') ?? '';
  final keys = <String>[if (!c.isHome) c.id, if (c.areaId.isNotEmpty) 'a_${c.areaId}'];
  try {
    if (prev.isNotEmpty && prev != c.id) {
      for (final k in prev.split('|')) {
        for (final cat in cats) {
          await FirebaseMessaging.instance.unsubscribeFromTopic(boardTopic(k, cat));
        }
      }
    }
    for (final k in keys) {
      final scope = k.startsWith('a_') ? 'town' : 'complex';
      for (final cat in cats) {
        final on = await pushOn('$scope.$cat');
        final t = boardTopic(k, cat);
        on ? await FirebaseMessaging.instance.subscribeToTopic(t) : await FirebaseMessaging.instance.unsubscribeFromTopic(t);
      }
    }
    final u = me;
    if (u != null) {
      final t = userTopic(u.uid);
      await pushOn('mycomment') ? await FirebaseMessaging.instance.subscribeToTopic(t) : await FirebaseMessaging.instance.unsubscribeFromTopic(t);
    }
    await prefSet('push.complex', keys.join('|'));
  } catch (_) {}
}
