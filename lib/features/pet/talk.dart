// 우리 구 멍냥 소통방 (대표님 11-26) — 반려동물 테마 방
// 구(시·군·구) 단위 이웃 반려인끼리: 자랑·수다 · 질문 · 병원·가게 후기 · 나눔 · 실종·목격
// 냥이·멍이 3D 스티커(28개, assets/art/pet_emo_*)를 글쓴이 캐릭터와 댓글 스티커로 씀
//
// 저장: 게시판과 같은 파이어베이스 dn_posts (규칙 그대로 — 로그인 회원만 읽고 씀, 신고는 dn_post_reports)
//   cid = 'p_<구 id>' (동네 게시판 'a_…'·단지 게시판과 섞이지 않음), area = 단지의 동네 id (동 이름 표시용)
//   cat 은 규칙에 있는 값만 써서 말머리를 나타냄: free 자랑·수다 / news 질문 / rec 병원·가게 후기 / share 나눔 / lost 실종·목격
//   스티커 댓글은 본문을 ':emo:<스티커 id>:' 로 저장 → 화면에서 그림으로
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/mydata.dart' show needLogin;
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'kids.dart';

// ---------------- 스티커 ----------------

const kEmoNames = ['wow', 'lol', 'love', 'omg', 'cool', 'hmm', 'idea', 'sad', 'angry', 'sleepy', 'sick', 'shy', 'yum', 'party'];
const kEmoLabel = {
  'wow': '신나요', 'lol': '웃겨요', 'love': '사랑해요', 'omg': '놀라워요', 'cool': '최고예요', 'hmm': '궁금해요', 'idea': '좋은 생각',
  'sad': '슬퍼요', 'angry': '화나요', 'sleepy': '졸려요', 'sick': '아파요', 'shy': '부끄러워요', 'yum': '맛있어요', 'party': '축하해요',
};
final kEmoIds = [for (final k in ['c', 'd']) for (final n in kEmoNames) '${k}_$n'];
String emoAsset(String id) => 'assets/art/pet_emo_$id.png';

class Emo extends StatelessWidget {
  final String id;
  final double size;
  const Emo(this.id, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Image.asset(emoAsset(kEmoIds.contains(id) ? id : 'c_wow'), width: size, height: size, filterQuality: FilterQuality.medium);
}

/// 글쓴이 캐릭터 — 사람마다 늘 같은 스티커 (냥이·멍이 28개 중)
String avatarOf(String uid) {
  var h = 0;
  for (final c in uid.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return kEmoIds[h % kEmoIds.length];
}

String? stickerOf(String body) {
  final m = RegExp(r'^:emo:([cd]_[a-z]+):$').firstMatch(body.trim());
  return m?.group(1);
}

// ---------------- 말머리 ----------------

const kTalkCats = [('free', '자랑·수다'), ('news', '질문'), ('rec', '병원·가게 후기'), ('share', '나눔'), ('lost', '실종·목격')];
String talkCatName(String id) => kTalkCats.firstWhere((c) => c.$1 == id, orElse: () => kTalkCats.first).$2;

// ---------------- 방 (구 단위) ----------------

String talkKey(Complex c) => 'p_${c.areaId.split('_').first}';
bool hasTalk(Complex c) => c.areaId.isNotEmpty;
String talkRoomName(Complex c) {
  final a = c.area;
  final gu = a?.gu ?? '';
  if (gu.isNotEmpty) return gu;
  final t = c.town;
  return t.isEmpty ? '우리 동네' : t;
}

/// 글 아래 작은 동 이름 (나뉜 동네면 「해운대구/우동」의 뒷부분)
String dongOf(String areaId) {
  final a = areaById(areaId);
  if (a == null) return '';
  final p = a.name.split('/');
  return p.length > 1 ? p[1] : '';
}

/// 글쓴이 이름: 우리 아이가 있으면 「초코네」, 없으면 계정 이름
String talkName() {
  final ks = kids.value;
  if (ks.isNotEmpty && ks.first.name.trim().isNotEmpty) return '${ks.first.name.trim()}네';
  return myName;
}

class TalkPost {
  final String id, cat, title, body, uid, name, area;
  final DateTime at;
  final List<String> photos, thumbs;
  final int comments;
  final bool done;
  const TalkPost(this.id, this.cat, this.title, this.body, this.uid, this.name, this.area, this.at, this.photos, this.thumbs, this.comments, this.done);
  bool get mine => me?.uid == uid;
  int get photoCount => photos.isNotEmpty ? photos.length : thumbs.length;
  Uint8List photo(int i) => base64Decode(photos.length > i ? photos[i] : thumbs[i]);
  Uint8List thumb(int i) => base64Decode(thumbs.length > i ? thumbs[i] : photos[i]);

  static TalkPost of(String id, Map<String, dynamic> d) => TalkPost(
        id,
        '${d['cat'] ?? 'free'}',
        '${d['t'] ?? ''}',
        '${d['b'] ?? ''}',
        '${d['uid'] ?? ''}',
        '${d['name'] ?? ''}',
        '${d['area'] ?? ''}',
        (d['at'] is fs.Timestamp) ? (d['at'] as fs.Timestamp).toDate() : DateTime.now(),
        [for (final x in (d['ph'] as List? ?? const [])) '$x'],
        [for (final x in (d['th'] as List? ?? const [])) '$x'],
        (d['n'] as num?)?.toInt() ?? 0,
        d['done'] == true,
      );
}

class TalkComment {
  final String id, body, uid, name;
  final DateTime at;
  const TalkComment(this.id, this.body, this.uid, this.name, this.at);
  bool get mine => me?.uid == uid;
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return '${t.month}.${t.day}';
}

final talkTick = ValueNotifier<int>(0);

Future<List<TalkPost>> talkPosts(Complex c) async {
  if (!hasTalk(c) || me == null || !await fbReady()) return const [];
  try {
    final q = await db.collection('dn_posts').where('cid', isEqualTo: talkKey(c)).limit(300).get();
    return [for (final d in q.docs) TalkPost.of(d.id, d.data())]..sort((a, b) => b.at.compareTo(a.at));
  } catch (e) {
    debugPrint('소통방 읽기 실패: $e');
    return const [];
  }
}

Future<String?> talkWrite(Complex c, {required String cat, required String title, required String body, required List<Uint8List> photos, required List<Uint8List> thumbs}) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  if (!await fbReady()) return '서버에 연결하지 못했어요';
  try {
    await db.collection('dn_posts').add({
      'cid': talkKey(c),
      'area': c.areaId,
      'cat': cat,
      't': title,
      'b': body,
      'uid': u.uid,
      'name': talkName(),
      'at': fs.FieldValue.serverTimestamp(),
      'n': 0,
      'done': false,
      'ph': [for (final p in photos) base64Encode(p)],
      'th': [for (final p in thumbs) base64Encode(p)],
    });
    talkTick.value++;
    return null;
  } catch (_) {
    return '올리지 못했어요';
  }
}

Future<bool> talkDelete(TalkPost p) async {
  try {
    await db.collection('dn_posts').doc(p.id).delete();
    talkTick.value++;
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> talkSetDone(TalkPost p, bool v) async {
  try {
    await db.collection('dn_posts').doc(p.id).update({'done': v});
    talkTick.value++;
    return true;
  } catch (_) {
    return false;
  }
}

Future<List<TalkComment>> talkComments(TalkPost p) async {
  try {
    final q = await db.collection('dn_posts').doc(p.id).collection('cm').limit(300).get();
    return [
      for (final d in q.docs)
        TalkComment(d.id, '${d.data()['b'] ?? ''}', '${d.data()['uid'] ?? ''}', '${d.data()['name'] ?? ''}',
            (d.data()['at'] is fs.Timestamp) ? (d.data()['at'] as fs.Timestamp).toDate() : DateTime.now()),
    ]..sort((a, b) => a.at.compareTo(b.at));
  } catch (_) {
    return const [];
  }
}

Future<String?> talkComment(TalkPost p, String body) async {
  final u = me;
  if (u == null) return '로그인이 필요해요';
  try {
    final ref = db.collection('dn_posts').doc(p.id);
    await ref.collection('cm').add({'b': body, 'uid': u.uid, 'name': talkName(), 'at': fs.FieldValue.serverTimestamp()});
    try {
      await ref.update({'n': fs.FieldValue.increment(1), 'ca': fs.FieldValue.serverTimestamp()});
    } catch (_) {
      await ref.update({'n': fs.FieldValue.increment(1)});
    }
    talkTick.value++;
    return null;
  } catch (_) {
    return '댓글을 남기지 못했어요';
  }
}

Future<bool> talkDeleteComment(TalkPost p, TalkComment c) async {
  try {
    final ref = db.collection('dn_posts').doc(p.id);
    await ref.collection('cm').doc(c.id).delete();
    await ref.update({'n': fs.FieldValue.increment(-1)});
    talkTick.value++;
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> talkReport(TalkPost p, String why) async {
  final u = me;
  if (u == null || !await fbReady()) return false;
  try {
    await db.collection('dn_post_reports').add({'pid': p.id, 'cid': talkKey0(p), 'why': why, 'uid': u.uid, 'at': fs.FieldValue.serverTimestamp()});
    return true;
  } catch (_) {
    return false;
  }
}

String talkKey0(TalkPost p) => 'p_${p.area.split('_').first}';

// ---------------- 반려동물 첫 화면 띠 ----------------

class PetTalkStrip extends StatefulWidget {
  final Complex complex;
  const PetTalkStrip({super.key, required this.complex});
  @override
  State<PetTalkStrip> createState() => _PetTalkStripState();
}

class _PetTalkStripState extends State<PetTalkStrip> {
  List<TalkPost>? posts;

  @override
  void initState() {
    super.initState();
    authTick.addListener(_load);
    talkTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    authTick.removeListener(_load);
    talkTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final l = await talkPosts(widget.complex);
    if (mounted) setState(() => posts = l);
  }

  void _open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetTalkPage(complex: widget.complex)));

  @override
  Widget build(BuildContext context) {
    final c = widget.complex;
    if (!hasTalk(c)) return const SizedBox.shrink();
    final room = talkRoomName(c);
    final l = (posts ?? const <TalkPost>[]).take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: MixTitle(room, '멍냥 소통방', size: 15)),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _open,
          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Text('전체 보기', style: TextStyle(fontSize: 12.5, color: kSub, fontWeight: FontWeight.w600))),
        ),
      ]),
      const SizedBox(height: 10),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: _open,
          child: Ink(
            decoration: cardBox(),
            child: me == null || l.isEmpty ? _Invite(loggedIn: me != null, room: room, onTap: _open) : Column(children: [for (var i = 0; i < l.length; i++) _TalkRow(p: l[i], last: i == l.length - 1, compact: true)]),
          ),
        ),
      ),
    ]);
  }
}

// 로그인 전·첫 글 전: 스티커가 놀고 있는 초대 카드
class _Invite extends StatelessWidget {
  final bool loggedIn;
  final String room;
  final VoidCallback onTap;
  const _Invite({required this.loggedIn, required this.room, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(children: [
          const SizedBox(
            width: 92,
            height: 64,
            child: Stack(children: [
              Positioned(left: 0, top: 6, child: Emo('d_wow', size: 54)),
              Positioned(left: 40, top: 0, child: Emo('c_love', size: 54)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loggedIn ? '첫 이야기를 남겨 보세요' : '$room 반려인 이웃과 이야기해요', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 3),
              Text(loggedIn ? '우리 아이 자랑, 산책 친구, 병원 후기 무엇이든' : '로그인하면 이웃 글을 보고 스티커로 답할 수 있어요', style: T.small),
            ]),
          ),
          const Icon(Icons.chevron_right, size: 18, color: kMute),
        ]),
      );
}

class _TalkRow extends StatelessWidget {
  final TalkPost p;
  final bool last, compact;
  final VoidCallback? onTap;
  const _TalkRow({required this.p, required this.last, this.compact = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final dong = dongOf(p.area);
    final row = Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        Emo(avatarOf(p.uid), size: compact ? 40 : 46),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(talkCatName(p.cat), style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w700)),
              if (p.done) ...[const SizedBox(width: 5), Text(p.cat == 'lost' ? '찾았어요' : '완료', style: const TextStyle(fontSize: 11, color: kBlue, fontWeight: FontWeight.w700))],
            ]),
            const SizedBox(height: 1),
            Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text([p.name, if (dong.isNotEmpty) dong, ago(p.at)].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
          ]),
        ),
        if (p.photoCount > 0) ...[
          const SizedBox(width: 8),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(p.thumb(0), width: compact ? 44 : 52, height: compact ? 44 : 52, fit: BoxFit.cover, gaplessPlayback: true)),
        ],
        if (p.comments > 0) ...[
          const SizedBox(width: 8),
          Column(children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: kMute),
            Text('${p.comments}', style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

// ---------------- 전체 화면 ----------------

class PetTalkPage extends StatefulWidget {
  final Complex complex;
  const PetTalkPage({super.key, required this.complex});
  @override
  State<PetTalkPage> createState() => _PetTalkPageState();
}

class _PetTalkPageState extends State<PetTalkPage> {
  List<TalkPost>? posts;
  String cat = 'all';

  @override
  void initState() {
    super.initState();
    authTick.addListener(_load);
    talkTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    authTick.removeListener(_load);
    talkTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await loadKids();
    final l = await talkPosts(widget.complex);
    if (mounted) setState(() => posts = l);
  }

  Future<void> _write() async {
    if (!await needLogin(context, why: '소통방 글')) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _WritePage(complex: widget.complex, cat: cat == 'all' ? 'free' : cat)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complex;
    final room = talkRoomName(c);
    final all = posts;
    final l = all == null ? null : (cat == 'all' ? all : all.where((p) => p.cat == cat).toList());
    return DetailPage(
      title: '$room 멍냥 소통방',
      icon: 'pet',
      white: false,
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(0, 16, 0, 100), children: [
            // 머리: 스티커가 모여 있는 인사
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPad),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MixTitle(room, '반려인 이웃', size: 17),
                    const SizedBox(height: 3),
                    Text('자랑도, 질문도, 산책 친구 찾기도 여기서', style: T.small),
                  ]),
                ),
                const SizedBox(
                  width: 118,
                  height: 56,
                  child: Stack(children: [
                    Positioned(left: 0, top: 4, child: Emo('c_party', size: 50)),
                    Positioned(left: 34, top: 0, child: Emo('d_love', size: 52)),
                    Positioned(left: 70, top: 6, child: Emo('c_lol', size: 48)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: kPad), children: [
                for (final x in [('all', '전체'), ...kTalkCats]) ...[
                  _Chip(x.$2, on: cat == x.$1, onTap: () => setState(() => cat = x.$1)),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPad),
              child: me == null
                  ? Container(decoration: cardBox(), child: _Invite(loggedIn: false, room: room, onTap: _write))
                  : l == null
                      ? const Padding(padding: EdgeInsets.all(30), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                      : l.isEmpty
                          ? Container(
                              decoration: cardBox(),
                              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                              child: Column(children: [
                                const Emo('d_hmm', size: 72),
                                const SizedBox(height: 8),
                                Text(cat == 'lost' ? '실종·목격 글이 없어요. 다행이에요!' : '아직 글이 없어요. 첫 이야기를 남겨 주세요.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: kSub)),
                              ]),
                            )
                          : Container(
                              decoration: cardBox(),
                              child: Column(children: [
                                for (var i = 0; i < l.length; i++)
                                  _TalkRow(
                                    p: l[i],
                                    last: i == l.length - 1,
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PostPage(complex: c, post: l[i]))),
                                  ),
                              ]),
                            ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPad),
              child: Text('$room 이웃이 함께 보는 방이에요 · 로그인한 이웃만 볼 수 있어요 · 불편한 글은 글 안에서 신고해 주세요', style: T.tiny),
            ),
          ]),
        ),
        Positioned(
          right: kPad,
          bottom: 22,
          child: Material(
            color: kBlue,
            borderRadius: BorderRadius.circular(26),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: _write,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, size: 17, color: Colors.white),
                  SizedBox(width: 6),
                  Text('글쓰기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool on;
  final VoidCallback onTap;
  const _Chip(this.text, {required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), color: on ? kInk : Colors.white, border: Border.all(color: on ? kInk : kLine)),
          child: Text(text, style: TextStyle(fontSize: 12.5, color: on ? Colors.white : kInk, fontWeight: on ? FontWeight.w700 : FontWeight.w500, letterSpacing: -0.3)),
        ),
      );
}

// ---------------- 글 보기 + 댓글·스티커 ----------------

class _PostPage extends StatefulWidget {
  final Complex complex;
  final TalkPost post;
  const _PostPage({required this.complex, required this.post});
  @override
  State<_PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<_PostPage> {
  late TalkPost p = widget.post;
  List<TalkComment>? cms;
  final input = TextEditingController();
  bool sending = false, picker = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l = await talkComments(p);
    if (mounted) setState(() => cms = l);
  }

  Future<void> _send(String body) async {
    if (body.trim().isEmpty || sending) return;
    if (!await needLogin(context, why: '댓글')) return;
    setState(() => sending = true);
    final e = await talkComment(p, body.trim());
    if (!mounted) return;
    setState(() {
      sending = false;
      if (e == null) {
        input.clear();
        picker = false;
      }
    });
    if (e != null) {
      toast(context, e);
    } else {
      _load();
    }
  }

  Future<void> _more() async {
    final act = await showSheet<String>(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (p.mine && (p.cat == 'lost' || p.cat == 'share'))
            _SheetBtn(p.done ? '다시 진행 중으로' : (p.cat == 'lost' ? '찾았어요로 바꾸기' : '나눔 완료로 바꾸기'), () => Navigator.pop(ctx, 'done')),
          if (p.mine) _SheetBtn('글 지우기', () => Navigator.pop(ctx, 'del')),
          if (!p.mine) _SheetBtn('신고하기', () => Navigator.pop(ctx, 'report')),
        ]),
      ),
    );
    if (!mounted || act == null) return;
    if (act == 'done') {
      if (await talkSetDone(p, !p.done) && mounted) {
        setState(() => p = TalkPost(p.id, p.cat, p.title, p.body, p.uid, p.name, p.area, p.at, p.photos, p.thumbs, p.comments, !p.done));
      }
    } else if (act == 'del') {
      if (await talkDelete(p) && mounted) Navigator.pop(context);
    } else if (act == 'report') {
      final ok = await talkReport(p, '반려동물 소통방 글 신고');
      if (mounted) toast(context, ok ? '신고했어요. 확인할게요' : '신고하지 못했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dong = dongOf(p.area);
    final l = cms;
    return DetailPage(
      title: talkCatName(p.cat),
      icon: 'pet',
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 20), children: [
            Row(children: [
              Emo(avatarOf(p.uid), size: 52),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text([if (dong.isNotEmpty) dong, ago(p.at)].join(' · '), style: T.tiny),
                ]),
              ),
              IconButton(onPressed: _more, icon: const Icon(Icons.more_horiz_rounded, color: kSub)),
            ]),
            const SizedBox(height: 14),
            if (p.done) ...[Text(p.cat == 'lost' ? '찾았어요' : '완료', style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700)), const SizedBox(height: 4)],
            Text(p.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.3)),
            const SizedBox(height: 10),
            if (p.body.isNotEmpty) Text(p.body, style: const TextStyle(fontSize: 14, height: 1.55)),
            for (var i = 0; i < p.photoCount; i++) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(p.photo(i), fit: BoxFit.cover, gaplessPlayback: true)),
            ],
            const SizedBox(height: 22),
            Container(height: 1, color: kLine),
            const SizedBox(height: 14),
            Text(l == null ? '댓글' : '댓글 ${l.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (l == null)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            else if (l.isEmpty)
              Text('첫 댓글이나 스티커를 남겨 보세요', style: T.small)
            else
              for (final cm in l) _CommentRow(cm: cm, onDelete: cm.mine ? () async {
                if (await talkDeleteComment(p, cm)) _load();
              } : null),
          ]),
        ),
        // 스티커 고르기 (냥이 · 멍이)
        if (picker) _StickerPicker(onPick: (id) => _send(':emo:$id:')),
        // 입력 줄
        Container(
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
          padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + MediaQuery.of(context).padding.bottom),
          child: Row(children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => picker = !picker),
              child: Padding(padding: const EdgeInsets.all(2), child: Opacity(opacity: picker ? 1 : 0.9, child: Emo(picker ? 'd_wow' : 'c_wow', size: 36))),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF3F5F9), borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: input,
                  maxLength: 300,
                  onSubmitted: _send,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, counterText: '', hintText: '댓글을 남겨 주세요', hintStyle: TextStyle(fontSize: 13, color: kMute)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(onPressed: sending ? null : () => _send(input.text), child: const Text('보내기', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
      ]),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SheetBtn(this.text, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      );
}

class _CommentRow extends StatelessWidget {
  final TalkComment cm;
  final VoidCallback? onDelete;
  const _CommentRow({required this.cm, this.onDelete});
  @override
  Widget build(BuildContext context) {
    final st = stickerOf(cm.body);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Emo(avatarOf(cm.uid), size: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(cm.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(ago(cm.at), style: T.tiny),
              const Spacer(),
              if (onDelete != null) InkWell(onTap: onDelete, child: const Padding(padding: EdgeInsets.all(2), child: Text('지우기', style: TextStyle(fontSize: 11, color: kMute)))),
            ]),
            const SizedBox(height: 3),
            st != null ? Emo(st, size: 92) : Text(cm.body, style: const TextStyle(fontSize: 13.5, height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}

class _StickerPicker extends StatefulWidget {
  final void Function(String id) onPick;
  const _StickerPicker({required this.onPick});
  @override
  State<_StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<_StickerPicker> {
  String kind = 'c';
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            for (final k in [('c', '냥이'), ('d', '멍이')]) ...[
              _Chip(k.$2, on: kind == k.$1, onTap: () => setState(() => kind = k.$1)),
              const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: GridView.count(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (final n in kEmoNames)
                  Tooltip(
                    message: kEmoLabel[n] ?? '',
                    child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => widget.onPick('${kind}_$n'), child: Padding(padding: const EdgeInsets.all(2), child: Emo('${kind}_$n', size: 44))),
                  ),
              ],
            ),
          ),
        ]),
      );
}

// ---------------- 글쓰기 ----------------

const _photoCh = MethodChannel('dongne/photo');

class _Pic {
  final Uint8List full, thumb;
  _Pic(this.full, this.thumb);
}

class _WritePage extends StatefulWidget {
  final Complex complex;
  final String cat;
  const _WritePage({required this.complex, required this.cat});
  @override
  State<_WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<_WritePage> {
  late String cat = widget.cat;
  final title = TextEditingController();
  final body = TextEditingController();
  final pics = <_Pic>[];
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (pics.length >= 3) return;
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (x == null) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final m = await _photoCh.invokeMapMethod<String, dynamic>('prep', {'path': x.path, 'full': 960, 'thumb': 320});
          if (m != null && m['full'] is Uint8List && m['thumb'] is Uint8List) {
            setState(() => pics.add(_Pic(m['full'] as Uint8List, m['thumb'] as Uint8List)));
            return;
          }
        } catch (_) {}
      }
      final b = await x.readAsBytes();
      if (b.length > 180 * 1024) {
        if (mounted) toast(context, '사진이 커요. 조금 작은 사진을 골라 주세요');
        return;
      }
      setState(() => pics.add(_Pic(b, b)));
    } catch (_) {}
  }

  Future<void> _save() async {
    final t = title.text.trim();
    if (t.length < 2) {
      toast(context, '제목을 두 글자 이상 써 주세요');
      return;
    }
    setState(() => busy = true);
    final e = await talkWrite(widget.complex, cat: cat, title: t, body: body.text.trim(), photos: [for (final p in pics) p.full], thumbs: [for (final p in pics) p.thumb]);
    if (!mounted) return;
    setState(() => busy = false);
    if (e != null) {
      toast(context, e);
    } else {
      Navigator.pop(context);
      toast(context, '올렸어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = me?.uid ?? '';
    return DetailPage(
      title: '소통방 글쓰기',
      icon: 'pet',
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
        Row(children: [
          Emo(avatarOf(uid), size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(talkName(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('${talkRoomName(widget.complex)} 이웃에게 보여요', style: T.tiny),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in kTalkCats) SizedBox(height: 34, child: _Chip(x.$2, on: cat == x.$1, onTap: () => setState(() => cat = x.$1))),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: cardBox(r: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: title,
            maxLength: 60,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: cat == 'lost' ? '예: 송도동 공원 앞에서 갈색 푸들 봤어요' : '제목', hintStyle: const TextStyle(fontSize: 14, color: kMute, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: cardBox(r: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: body,
            maxLength: 1000,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: const InputDecoration(border: InputBorder.none, counterText: '', hintText: '우리 아이 자랑, 궁금한 것, 다녀온 병원 이야기…\n전화번호 같은 개인 정보는 적지 않는 게 좋아요', hintStyle: TextStyle(fontSize: 13, color: kMute, height: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < pics.length; i++) ...[
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(pics[i].thumb, width: 78, height: 78, fit: BoxFit.cover)),
              Positioned(
                right: 2,
                top: 2,
                child: InkWell(onTap: () => setState(() => pics.removeAt(i)), child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(3), child: const Icon(Icons.close, size: 13, color: Colors.white))),
              ),
            ]),
            const SizedBox(width: 8),
          ],
          if (pics.length < 3)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pick,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine), color: Colors.white),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: kSub, size: 22),
                  const SizedBox(height: 2),
                  Text('사진 ${pics.length}/3', style: T.tiny),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 20),
        Btn(busy ? '올리는 중…' : '올리기', primary: true, h: 48, onTap: busy ? null : _save),
      ]),
    );
  }
}
