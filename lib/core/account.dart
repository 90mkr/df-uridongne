// 회원 탈퇴 (본부 방만 고침, 대표님 11-28 — 플레이 출시: 앱 안에서 바로 탈퇴)
//  지우는 것: 내 정보·기록(dn_my), 내가 쓴 글(dn_posts)·댓글(cm), 이웃 추천(dn_recs), 행사 알리기(dn_events),
//            주차장·충전소 제보, 내 글 댓글 알림 주제, 로그인 계정
//  남는 것: 신고 기록(관리자가 처리 후 지움), 단지 배출 요일처럼 함께 쓰는 정보
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fb.dart';
import 'push.dart';

/// 마지막 로그인이 오래됐으면 계정 삭제가 막힘 (구글 정책: 최근 로그인 필요) → 먼저 다시 로그인
bool get needFreshLogin {
  final t = me?.metadata.lastSignInTime;
  if (t == null) return true;
  return DateTime.now().difference(t).inMinutes >= 4;
}

Future<void> _wipe(fs.Query<Map<String, dynamic>> q) async {
  try {
    final r = await q.limit(500).get();
    for (final d in r.docs) {
      try {
        await d.reference.delete();
      } catch (e) {
        debugPrint('탈퇴 지우기 건너뜀 ${d.reference.path}: $e');
      }
    }
  } catch (e) {
    debugPrint('탈퇴 목록 못 읽음: $e');
  }
}

/// 성공이면 null, 다시 로그인이 필요하면 'relogin', 그 밖은 안내 문구
Future<String?> deleteAccount() async {
  final u = me;
  if (u == null) return '로그인해 주세요';
  final uid = u.uid;
  try {
    await _wipe(db.collection('dn_my').doc(uid).collection('d'));
    await _wipe(db.collection('dn_posts').where('uid', isEqualTo: uid));
    await _wipe(db.collectionGroup('cm').where('uid', isEqualTo: uid));
    await _wipe(db.collection('dn_recs').where('uid', isEqualTo: uid));
    await _wipe(db.collection('dn_events').where('uid', isEqualTo: uid));
    await _wipe(db.collection('dn_parking_busy').where('uid', isEqualTo: uid));
    await _wipe(db.collection('dn_charger_reports').where('uid', isEqualTo: uid));
    if (!kIsWeb) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(userTopic(uid));
      } catch (_) {}
    }
    await u.delete();
    authTick.value++;
    return null;
  } on fa.FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') return 'relogin';
    return '탈퇴를 마치지 못했어요 (${e.code})';
  } catch (e) {
    return '탈퇴를 마치지 못했어요';
  }
}
