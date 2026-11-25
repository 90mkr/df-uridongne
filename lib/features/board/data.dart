// 우리 단지 게시판 (게시판 담당: 본부, 대표님 요청 11-24)
// 같은 단지 주민끼리: 소식 · 나눔 · 자유 · 업체 추천. 파이어베이스 dn_posts (+ 댓글 dn_posts/{id}/cm)
// 목록은 사진 없이 한 줄 글로 (공지사항처럼, 대표님 11-24). 사진은 글 안에서만.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';

import '../../core/data.dart';
import '../../core/fb.dart';

// 게시판들 (대표님 11-25: 단체 홈페이지처럼 게시판 여러 개) — (id, 짧은 이름, 게시판 이름)
const kBoards = [('news', '소식', '공지·소식'), ('share', '나눔', '나눔터'), ('free', '자유', '자유게시판'), ('rec', '추천', '업체 추천'), ('lost', '분실', '분실물')];
final kBoardCats = [for (final b in kBoards) (b.$1, b.$2)];
String catName(String id) => kBoards.firstWhere((c) => c.$1 == id, orElse: () => ('', '자유', '자유게시판')).$2;
String boardName(String id) => kBoards.firstWhere((c) => c.$1 == id, orElse: () => ('', '자유', '자유게시판')).$3;

// 일자리 마당 — 고용24(옛 워크넷) 채용 공고, 구(시군구) 단위 · 본부 「전국 자료」가 job_<동네>.json 으로 매일 (키 들어오면)
class Job {
  final String title, company, pay, until, place, url;
  const Job(this.title, this.company, this.pay, this.until, this.place, this.url);
}

Future<List<Job>?> jobsOf(Complex c) async {
  if (c.areaId.isEmpty) return null;
  final j = await getJson('${storeBase}job_${c.areaId}.json');
  if (j is! Map) return null;
  return [
    for (final x in (j['jobs'] as List? ?? const []))
      if (x is Map) Job('${x['t'] ?? ''}', '${x['c'] ?? ''}', '${x['p'] ?? ''}', '${x['u'] ?? ''}', '${x['a'] ?? ''}', '${x['l'] ?? ''}')
  ];
}

class Post {
  final String id, cid, cat, title, body, uid, name;
  final DateTime at;
  final List<String> photos, thumbs;
  final int comments;
  final bool done; // 나눔 완료
  const Post({
    required this.id,
    required this.cid,
    required this.cat,
    required this.title,
    required this.body,
    required this.uid,
    required this.name,
    required this.at,
    this.photos = const [],
    this.thumbs = const [],
    this.comments = 0,
    this.done = false,
  });

  bool get mine => me?.uid == uid;
  Uint8List photo(int i) => base64Decode(photos.length > i ? photos[i] : thumbs[i]);

  static Post of(String id, Map<String, dynamic> d) => Post(
        id: id,
        cid: '${d['cid'] ?? ''}',
        cat: '${d['cat'] ?? 'free'}',
        title: '${d['t'] ?? ''}',
        body: '${d['b'] ?? ''}',
        uid: '${d['uid'] ?? ''}',
        name: '${d['name'] ?? ''}',
        at: (d['at'] is fs.Timestamp) ? (d['at'] as fs.Timestamp).toDate() : DateTime.now(),
        photos: [for (final x in (d['ph'] as List? ?? const [])) '$x'],
        thumbs: [for (final x in (d['th'] as List? ?? const [])) '$x'],
        comments: (d['n'] as num?)?.toInt() ?? 0,
        done: d['done'] == true,
      );
}

class Comment {
  final String id, body, uid, name;
  final DateTime at;
  const Comment(this.id, this.body, this.uid, this.name, this.at);
}

String agoText(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return '${t.month}.${t.day}';
}

final boardTick = ValueNotifier<int>(0);

// 게시판 두 층 (대표님 11-25): 우리 단지(같은 단지끼리) · 우리 동네(동네 id 하나 — 아파트·주택 주민 함께)
// 동네 글은 cid 를 「a_<동네id>」로 저장한다 (규칙·색인 바꾸지 않고 같은 dn_posts 에)
String boardKey(Complex c, bool town) => town ? 'a_${c.areaId}' : c.id;
bool hasTownBoard(Complex c) => c.areaId.isNotEmpty;

Future<List<Post>> postsOf(Complex c, {bool town = false}) async {
  if (!await fbReady()) return const [];
  if (town && !hasTownBoard(c)) return const [];
  try {
    // 색인 없이: 단지(또는 동네)로만 거르고 시간 순은 앱에서
    final q = await db.collection('dn_posts').where('cid', isEqualTo: boardKey(c, town)).limit(300).get();
    final l = [for (final d in q.docs) Post.of(d.id, d.data())]..sort((a, b) => b.at.compareTo(a.at));
    return l;
  } catch (e) {
    debugPrint('게시판 읽기 실패: $e');
    return const [];
  }
}

Future<String?> writePost({required Complex c, bool town = false, required String cat, required String title, required String body, required List<Uint8List> photos, required List<Uint8List> thumbs}) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  if (!await fbReady()) return '서버에 연결하지 못했어요';
  try {
    await db.collection('dn_posts').add({
      'cid': boardKey(c, town),
      'area': c.areaId,
      'cat': cat,
      't': title,
      'b': body,
      'uid': u.uid,
      'name': myName,
      'at': fs.FieldValue.serverTimestamp(),
      'n': 0,
      'done': false,
      'ph': [for (final p in photos) base64Encode(p)],
      'th': [for (final p in thumbs) base64Encode(p)],
    });
    boardTick.value++;
    return null;
  } catch (e) {
    return '올리지 못했어요';
  }
}

Future<bool> deletePost(Post p) async {
  try {
    await db.collection('dn_posts').doc(p.id).delete();
    boardTick.value++;
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> setDone(Post p, bool v) async {
  try {
    await db.collection('dn_posts').doc(p.id).update({'done': v});
    boardTick.value++;
    return true;
  } catch (_) {
    return false;
  }
}

Future<List<Comment>> commentsOf(Post p) async {
  try {
    final q = await db.collection('dn_posts').doc(p.id).collection('cm').limit(200).get();
    final l = [
      for (final d in q.docs)
        Comment(d.id, '${d.data()['b'] ?? ''}', '${d.data()['uid'] ?? ''}', '${d.data()['name'] ?? ''}',
            (d.data()['at'] is fs.Timestamp) ? (d.data()['at'] as fs.Timestamp).toDate() : DateTime.now()),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return l;
  } catch (_) {
    return const [];
  }
}

Future<String?> addComment(Post p, String body) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  try {
    final ref = db.collection('dn_posts').doc(p.id);
    await ref.collection('cm').add({'b': body, 'uid': u.uid, 'name': myName, 'at': fs.FieldValue.serverTimestamp()});
    try {
      // ca: 마지막 댓글 시각 — 서버가 「내 글 댓글」 알림을 찾을 때 씀
      await ref.update({'n': fs.FieldValue.increment(1), 'ca': fs.FieldValue.serverTimestamp()});
    } catch (_) {
      await ref.update({'n': fs.FieldValue.increment(1)});
    }
    boardTick.value++;
    return null;
  } catch (_) {
    return '댓글을 남기지 못했어요';
  }
}

Future<bool> deleteComment(Post p, Comment c) async {
  try {
    final ref = db.collection('dn_posts').doc(p.id);
    await ref.collection('cm').doc(c.id).delete();
    await ref.update({'n': fs.FieldValue.increment(-1)});
    boardTick.value++;
    return true;
  } catch (_) {
    return false;
  }
}

// 신고: 관리자에게 (사장님 신고와 같은 dn_reqs 에 넣지 않고 따로)
Future<bool> reportPost(Post p, String why) async {
  final u = me;
  if (u == null || !await fbReady()) return false;
  try {
    await db.collection('dn_post_reports').add({'pid': p.id, 'cid': p.cid, 'why': why, 'uid': u.uid, 'at': fs.FieldValue.serverTimestamp()});
    return true;
  } catch (_) {
    return false;
  }
}
