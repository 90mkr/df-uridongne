import 'dart:async';
// 파이어베이스 (본부 방만 고침): 콕플과 같은 「디자인필」 프로젝트(kokple)를 함께 쓴다.
// ─ 로그인: 카카오 · 구글 · 이메일 (콕플과 같은 계정 — 한 번 가입하면 두 앱 공통)
// ─ 저장 칸 이름은 모두 dn_ 로 시작한다 (콕플 칸과 섞이지 않게). 기능 칸은 dn_<기능>_… (예: dn_trash_days)
// ─ 규칙은 저장소의 firestore.dongne.rules — 본부 방이 콕플 규칙과 합쳐 게시한다.
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart' as fc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const kFb = <String, String>{
  'apiKey': 'AIzaSyCtAYeMr_86li7WmmkXUL6Nx0ae8xmG5ME',
  'androidApiKey': 'AIzaSyB5wrd2GrSG7LqmrZqCvcWBBRWH7glm5Os',
  'authDomain': 'kokple.firebaseapp.com',
  'projectId': 'kokple',
  'storageBucket': 'kokple.firebasestorage.app',
  'messagingSenderId': '233879188710',
  'webAppId': '1:233879188710:web:543f8fd620c76f0685f727',
  'androidAppId': '1:233879188710:android:d370f784c3a7f72185f727',
};
const kAdminEmails = ['dfmail@naver.com', 'dfmail2580@gmail.com'];

Future<bool>? _fbF;
bool fbOn = false;
Future<bool> fbReady() => _fbF ??= () async {
      try {
        await fc.Firebase.initializeApp(
          options: fc.FirebaseOptions(
            apiKey: kIsWeb ? kFb['apiKey']! : kFb['androidApiKey']!,
            appId: kIsWeb ? kFb['webAppId']! : kFb['androidAppId']!,
            messagingSenderId: kFb['messagingSenderId']!,
            projectId: kFb['projectId']!,
            authDomain: kFb['authDomain'],
            storageBucket: kFb['storageBucket'],
          ),
        );
        fbOn = true;
        fa.FirebaseAuth.instance.setLanguageCode('ko').catchError((_) {});
        fa.FirebaseAuth.instance.authStateChanges().listen((_) => authTick.value++);
      } catch (_) {
        fbOn = false;
      }
      return fbOn;
    }();

fs.FirebaseFirestore get db => fs.FirebaseFirestore.instance;
fa.User? get me => fbOn ? fa.FirebaseAuth.instance.currentUser : null;
bool get isAdmin => kAdminEmails.contains(me?.email?.toLowerCase()) && (me?.emailVerified ?? false);
final authTick = ValueNotifier<int>(0);

String get myName {
  final u = me;
  if (u == null) return '';
  final n = (u.displayName ?? '').trim();
  if (n.isNotEmpty) return n;
  return (u.email ?? '').split('@').first;
}

// ---- 로그인 ----
// 방금 로그인이 「처음 가입」이었는지 (가입 축하 창을 띄울지, 대표님 11-28)
bool lastLoginNew = false;

Future<String?> signInGoogle() => _run(() async {
      final p = fa.GoogleAuthProvider();
      final c = kIsWeb ? await fa.FirebaseAuth.instance.signInWithPopup(p) : await fa.FirebaseAuth.instance.signInWithProvider(p);
      lastLoginNew = c.additionalUserInfo?.isNewUser ?? false;
    }, '구글 로그인을 마치지 못했어요');

Future<String?> signInKakao() => _run(() async {
      final p = fa.OAuthProvider('oidc.kakao');
      final c = kIsWeb ? await fa.FirebaseAuth.instance.signInWithPopup(p) : await fa.FirebaseAuth.instance.signInWithProvider(p);
      lastLoginNew = c.additionalUserInfo?.isNewUser ?? false;
      final u = c.user;
      final prof = c.additionalUserInfo?.profile ?? const <String, dynamic>{};
      final nick = (prof['nickname'] ?? prof['name'] ?? '').toString().trim();
      if (u != null && (u.displayName ?? '').isEmpty) {
        await u.updateDisplayName(nick.isNotEmpty ? nick : '카카오 회원');
        await u.reload();
      }
    }, '카카오 로그인을 마치지 못했어요');

Future<String?> signInEmail(String email, String pass, {bool join = false, String nick = ''}) => _run(() async {
      final a = fa.FirebaseAuth.instance;
      if (join) {
        final c = await a.createUserWithEmailAndPassword(email: email, password: pass);
        lastLoginNew = true;
        // 가입할 때 받은 닉네임 (대표님 11-28)
        if (nick.trim().isNotEmpty) {
          await c.user?.updateDisplayName(nick.trim());
          await c.user?.reload();
        }
        await c.user?.sendEmailVerification();
      } else {
        lastLoginNew = false;
        await a.signInWithEmailAndPassword(email: email, password: pass);
      }
    }, '로그인을 마치지 못했어요');

// 닉네임 바꾸기 (내 정보)
Future<String?> setNick(String n) async {
  final u = me;
  if (u == null) return '로그인해 주세요';
  try {
    await u.updateDisplayName(n.trim());
    await u.reload();
    authTick.value++;
    return null;
  } catch (e) {
    return '닉네임을 바꾸지 못했어요';
  }
}

Future<void> signOut() async {
  if (!fbOn) return;
  await fa.FirebaseAuth.instance.signOut();
}

Future<String?> _run(Future<void> Function() f, String fail) async {
  if (!await fbReady()) return '지금은 로그인할 수 없어요';
  lastLoginNew = false;
  try {
    // 브라우저로 넘어갔다 돌아오지 못하면 단추가 계속 잠기지 않게 (대표님 11-24: 구글 단추가 안 눌림)
    await f().timeout(const Duration(seconds: 90));
    authTick.value++;
    return null;
  } on fa.FirebaseAuthException catch (e) {
    debugPrint('login: ${e.code} ${e.message}');
    final m = authMsg(e.code);
    // 원인을 알 수 있게 알 수 없는 오류는 짧은 설명을 붙인다 (대표님 11-26 「카카오·구글 둘 다 안 됨」)
    return m.contains(e.code) && (e.message ?? '').isNotEmpty ? '$m\n${_cut(e.message!)}' : m;
  } on TimeoutException {
    return '로그인 창에서 앱으로 돌아오지 못했어요. 다시 눌러 주세요';
  } on PlatformException catch (e) {
    debugPrint('login: ${e.code} ${e.message}');
    return '$fail (${e.code})\n${_cut(e.message ?? '')}';
  } catch (e) {
    debugPrint('login: $e');
    return '$fail\n${_cut('$e')}';
  }
}

String _cut(String s) => s.length > 120 ? '${s.substring(0, 120)}…' : s;

String authMsg(String code) => switch (code) {
      'invalid-email' => '이메일 모양이 맞지 않아요',
      'user-not-found' || 'wrong-password' || 'invalid-credential' => '이메일이나 비밀번호가 맞지 않아요',
      'email-already-in-use' => '이미 가입한 이메일이에요. 로그인해 주세요',
      'weak-password' => '비밀번호를 6자 넘게 넣어 주세요',
      'too-many-requests' => '잠시 뒤에 다시 해 주세요',
      'popup-closed-by-user' || 'web-context-canceled' || 'canceled' => '로그인 창을 닫았어요',
      'network-request-failed' => '인터넷 연결을 확인해 주세요',
      _ => '로그인을 마치지 못했어요 ($code)',
    };

// ---- 신청 보내기: 사장님 등록 · 정보 수정 신고 (관리자 확인 뒤 반영) ----
Future<bool> sendRequest(Map<String, dynamic> data) async {
  if (!await fbReady()) return false;
  try {
    await db.collection('dn_reqs').add({...data, 'app': 'dongne', 'st': 'new', 'at': fs.FieldValue.serverTimestamp()});
    return true;
  } catch (_) {
    return false;
  }
}
