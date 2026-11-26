// 「내 정보·기록」 저장 (본부 방만 고침, 대표님 11-26)
//
// 원칙
//  · 내 정보·기록을 적는 곳(반려동물 아이 등록, 몸무게 기록 등)만 저장할 때 로그인을 요청하고, 로그인한 사람만 저장한다.
//  · 우리 단지 선택·홈 편집·보는 기능은 로그인 없이 지금처럼 (이 휴대폰 prefs).
//  · 저장은 파이어베이스 dn_my/{로그인 번호}/d/{키} — 다시 깔거나 폰을 바꿔도 로그인하면 그대로.
//
// 기능 방 쓰는 법 (키는 「기능이름.무엇」 — 예: 'pet.kids', 'pet.weight')
//    if (await saveMine(context, 'pet.kids', list)) { … 저장됨 … }     // 로그인 안 했으면 로그인 창 → 로그인하면 저장
//    final v = await loadMine('pet.kids');                             // 로그인 안 했으면 null
//    await deleteMine('pet.kids');
//    ValueListenableBuilder(valueListenable: authTick, …)               // 로그인·로그아웃하면 다시 불러오기
// 값은 JSON 으로 바꿀 수 있는 것(Map·List·문자·숫자·참거짓)이면 됨. 한 키에 400KB 까지 (사진은 넣지 말 것).
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import 'data.dart';
import 'fb.dart';
import 'me.dart' show openLogin;
import 'theme.dart';
import 'ui.dart';

bool get signedIn => me != null;

fs.DocumentReference<Map<String, dynamic>> _doc(String uid, String key) => db.collection('dn_my').doc(uid).collection('d').doc(key.replaceAll('/', '_'));

/// 로그인 확인: 되어 있으면 true. 아니면 「로그인하면 저장돼요」 안내 → 로그인 창. 로그인하면 true.
Future<bool> needLogin(BuildContext context, {String why = '내 정보'}) async {
  await fbReady();
  if (signedIn) return true;
  if (!context.mounted) return false;
  final go = await showSheet<bool>(
    context,
    (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const MixTitle('로그인하면', '저장돼요', size: 17),
        const SizedBox(height: 8),
        Text('$why은(는) 로그인한 분만 저장해요.\n앱을 다시 깔거나 휴대폰을 바꿔도 로그인하면 그대로 나와요.', style: const TextStyle(fontSize: 13.5, color: kSub, height: 1.45)),
        const SizedBox(height: 16),
        Btn('로그인하고 저장하기', primary: true, onTap: () => Navigator.pop(ctx, true)),
        const SizedBox(height: 8),
        Btn('다음에 할게요', onTap: () => Navigator.pop(ctx, false)),
      ]),
    ),
  );
  if (go != true || !context.mounted) return false;
  await openLogin(context);
  return signedIn;
}

/// 저장 (로그인 안 했으면 로그인부터). 저장되면 true
Future<bool> saveMine(BuildContext context, String key, Object? value, {String why = '내 정보'}) async {
  if (!await needLogin(context, why: why)) return false;
  final u = me!;
  final j = jsonEncode(value);
  try {
    await _doc(u.uid, key).set({'j': j, 'at': fs.FieldValue.serverTimestamp()});
    await prefSet('my.${u.uid}.$key', j); // 다음에 빨리 보이게 (서버가 바탕)
    return true;
  } catch (_) {
    if (context.mounted) toast(context, '저장하지 못했어요. 인터넷을 확인해 주세요');
    return false;
  }
}

/// 불러오기 — 로그인 안 했으면 null. 서버를 못 닿으면 이 휴대폰에 남은 마지막 값
Future<dynamic> loadMine(String key) async {
  await fbReady();
  final u = me;
  if (u == null) return null;
  try {
    final d = await _doc(u.uid, key).get().timeout(const Duration(seconds: 8));
    final j = d.data()?['j'];
    if (j is String) {
      await prefSet('my.${u.uid}.$key', j);
      return jsonDecode(j);
    }
    return null;
  } catch (_) {
    final c = await prefGet('my.${u.uid}.$key');
    return (c == null || c.isEmpty) ? null : jsonDecode(c);
  }
}

/// 지우기
Future<void> deleteMine(String key) async {
  await fbReady();
  final u = me;
  if (u == null) return;
  try {
    await _doc(u.uid, key).delete();
  } catch (_) {}
  await prefSet('my.${u.uid}.$key', '');
}

/// 조용히 저장 — 로그인해 있을 때만 (로그인 창 없이). 설정 백업용
Future<void> putMine(String key, Object? value) async {
  if (!fbOn) return;
  final u = me;
  if (u == null) return;
  final j = jsonEncode(value);
  try {
    await _doc(u.uid, key).set({'j': j, 'at': fs.FieldValue.serverTimestamp()});
    await prefSet('my.${u.uid}.$key', j);
  } catch (_) {}
}
