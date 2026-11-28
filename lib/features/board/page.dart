// 우리 단지 게시판 화면: 위 분류 칸 · 한 줄 목록(사진 없이) · 글쓰기 · 글 보기(사진·댓글)
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/feature.dart';
import '../../core/feedback.dart';
import '../../core/icons.dart';
import '../../features/registry.dart' show featureById;
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'noti.dart';

class BoardPage extends StatefulWidget {
  final Complex c;
  final String cat;
  final bool town; // 처음부터 「우리 동네」 칸
  const BoardPage({super.key, required this.c, this.cat = '', this.town = false});
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  late String cat = widget.cat; // '' = 전체
  late bool town = widget.town || widget.c.isHome; // 주택이면 동네 게시판만
  List<Post>? all;
  String get townName => widget.c.area?.name.split('/').first ?? '우리 동네';

  @override
  void initState() {
    super.initState();
    boardTick.addListener(_load);
    authTick.addListener(_load);
    blockTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    boardTick.removeListener(_load);
    authTick.removeListener(_load);
    blockTick.removeListener(_load);
    super.dispose();
  }

  void _pick(String id) => setState(() => cat = id);

  Future<void> _load() async {
    final t = town;
    final l = await postsOf(widget.c, town: t);
    final b = await blockedUids(); // 차단한 이웃 글은 안 보임 (대표님 11-28)
    if (mounted && t == town) setState(() => all = l.where((p) => !b.contains(p.uid)).toList());
  }

  Future<void> _write() async {
    // 로그인 + 이메일 가입이면 메일 인증 확인 (대표님 11-28)
    if (!await canWrite(context) || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _WritePage(c: widget.c, town: town, cat: cat.isEmpty ? 'free' : cat)));
  }

  @override
  Widget build(BuildContext context) {
    final l = (all ?? const <Post>[]).where((p) => cat.isEmpty || p.cat == cat).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: '알림 설정',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardNotiPage(c: widget.c))),
          ),
        ],
        title: Text.rich(TextSpan(children: [
          TextSpan(text: '${town ? townName : widget.c.name} ', style: const TextStyle(fontWeight: FontWeight.w800)),
          const TextSpan(text: '이야기', style: TextStyle(fontWeight: FontWeight.w300)),
        ]), style: const TextStyle(fontSize: 16.5, letterSpacing: -0.4), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _write,
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.edit_rounded, size: 19),
        label: const Text('글쓰기', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        // 우리 단지 · 우리 동네 (주택은 동네만)
        if (!widget.c.isHome && hasTownBoard(widget.c))
          Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 2, kPad, 8),
            child: Row(children: [
              for (final (t, label) in [(false, '우리 단지'), (true, '우리 동네 · $townName')]) ...[
                if (t) const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (town == t) return;
                    setState(() {
                      town = t;
                      all = null;
                    });
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: town == t ? kInk : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: town == t ? kInk : kLine),
                    ),
                    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: town == t ? FontWeight.w800 : FontWeight.w500, color: town == t ? Colors.white : kInk)),
                  ),
                ),
              ],
            ]),
          ),
        // 분류: 그누보드식 붙은 칸
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 10),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
            clipBehavior: Clip.antiAlias,
            child: Row(children: [
              for (final (i, t) in [('', '모아 보기'), ...kBoardCats].indexed) ...[
                if (i > 0) const VerticalDivider(width: 1, color: kLine),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => cat = t.$1),
                    child: Container(
                      color: cat == t.$1 ? kBlue : Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(t.$2, style: TextStyle(fontSize: 13, fontWeight: cat == t.$1 ? FontWeight.w800 : FontWeight.w500, color: cat == t.$1 ? Colors.white : kInk)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
        Expanded(
          child: all == null
              ? const Center(child: CircularProgressIndicator(color: kBlue))
              : cat.isEmpty
                  ? _portal()
              : l.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(me == null ? (town ? '로그인하면 $townName 이웃 글을 볼 수 있어요.\n(아파트·주택 주민이 함께 보는 동네 게시판이에요)' : '로그인하면 우리 단지 이웃 글을 볼 수 있어요.\n(같은 단지 주민끼리 보는 게시판이에요)') : cat == 'share' ? '아직 나눔 글이 없어요.\n안 쓰는 물건을 이웃과 나눠 보세요.' : '아직 글이 없어요.\n첫 이야기를 남겨 주세요.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: kSub, height: 1.5)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 90),
                        children: [
                          Container(
                            decoration: cardBox(),
                            clipBehavior: Clip.antiAlias,
                            child: Column(children: [
                              for (final (i, p) in l.indexed) ...[
                                if (i > 0) const Divider(height: 1, color: Color(0xFFF0F2F5)),
                                _Row(p: p, showCat: cat.isEmpty, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ReadPage(p: p)))),
                              ],
                            ]),
                          ),
                          const Padding(padding: EdgeInsets.only(top: 12), child: Text('우리 단지 주민끼리 보는 게시판이에요. 광고·비방 글은 신고해 주세요.', style: T.tiny, textAlign: TextAlign.center)),
                          FeedbackBanner(area: widget.c.areaId),
                        ],
                      ),
                    ),
        ),
      ]),
    );
  }
}

extension on _BoardPageState {
  // 모아 보기 (대표님 11-25): 단체 홈페이지 첫 화면처럼 게시판마다 최근 글 몇 줄 → 「더보기」로 그 게시판
  Widget _portal() {
    final posts = all ?? const <Post>[];
    final benefits = featureById('benefit');
    void openRead(Post p) => Navigator.push(context, MaterialPageRoute(builder: (_) => _ReadPage(p: p)));
    Widget section(String id) {
      final v = posts.where((p) => p.cat == id).take(4).toList();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: cardBox(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => _pick(id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Row(children: [
                Text(boardName(id), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(width: 6),
                if (v.isNotEmpty) Text('${posts.where((p) => p.cat == id).length}', style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('더보기', style: TextStyle(fontSize: 12, color: kSub)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: kSub),
              ]),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          if (v.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
              child: Text(id == 'lost' ? '잃어버린 물건·주운 물건을 알려 주세요' : '아직 글이 없어요', style: const TextStyle(fontSize: 13, color: kMute)),
            )
          else
            for (final (i, p) in v.indexed) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFF5F6F8)),
              _Row(p: p, showCat: false, onTap: () => openRead(p)),
            ],
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 90),
        children: [
          if (me == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(town ? '로그인하면 $townName 이웃 글을 볼 수 있어요' : '로그인하면 우리 단지 이웃 글을 볼 수 있어요', style: T.small),
            ),
          // 우리 동네 지원금·혜택 (지원금 방이 만든 기능이 있으면 카드로 연결)
          if (benefits != null) _BenefitCard(f: benefits, c: widget.c),
          for (final b in kBoards) section(b.$1),
          const Padding(padding: EdgeInsets.only(top: 4), child: Text('광고·비방 글은 신고해 주세요. 여러 번 신고된 글은 가려져요.', style: T.tiny, textAlign: TextAlign.center)),
          // 맨 아래 강조: 오류·개선 의견 (대표님 11-28 「적극 반영해 드리겠습니다」)
          FeedbackBanner(area: widget.c.areaId),
          FutureBuilder<Set<String>>(
            future: blockedUids(),
            builder: (_, b) => (b.data?.isEmpty ?? true)
                ? const SizedBox()
                : Center(
                    child: TextButton(
                      onPressed: () async {
                        await unblockAll();
                        if (mounted) toast(context, '차단을 모두 풀었어요');
                      },
                      child: Text('차단한 이웃 ${b.data!.length}명 · 모두 풀기', style: const TextStyle(fontSize: 12, color: kSub)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// 지원금·혜택 큰 카드 (첫 화면 배너처럼) → 누르면 그 기능 화면
class _BenefitCard extends StatelessWidget {
  final Feature f;
  final Complex c;
  const _BenefitCard({required this.f, required this.c});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: const Color(0xFF1E4FD8),
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => f.page(ctx, c))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.area?.gu ?? '우리 동네'} 지원금·혜택', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                    const SizedBox(height: 3),
                    const Text('몰라서 못 받는 혜택, 우리 구 것만 모아 봤어요', style: TextStyle(fontSize: 12, color: Color(0xFFDCE6FF))),
                  ]),
                ),
                LineIcon(f.icon, size: 40),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ]),
            ),
          ),
        ),
      );
}

// 한 줄 글 (사진 없이, 공지사항처럼)
class _Row extends StatelessWidget {
  final Post p;
  final bool showCat;
  final VoidCallback onTap;
  const _Row({required this.p, required this.showCat, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            if (showCat) ...[
              SizedBox(width: 50, child: Text(catName(p.cat), style: const TextStyle(fontSize: 11.5, color: kSub, fontWeight: FontWeight.w600))),
            ],
            if (p.cat == 'share' && p.done) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEFF1F4), borderRadius: BorderRadius.circular(10)),
                child: const Text('완료', style: TextStyle(fontSize: 10.5, color: kSub, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: p.done ? kSub : kInk)),
            ),
            if (p.photos.isNotEmpty || p.thumbs.isNotEmpty) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.image_outlined, size: 15, color: kMute)),
            if (p.comments > 0) Padding(padding: const EdgeInsets.only(left: 5), child: Text('[${p.comments}]', style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(agoText(p.at), style: const TextStyle(fontSize: 11, color: kMute)),
          ]),
        ),
      );
}

// ---------------- 글 보기 ----------------
class _ReadPage extends StatefulWidget {
  final Post p;
  const _ReadPage({required this.p});
  @override
  State<_ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<_ReadPage> {
  late Post p = widget.p;
  List<Comment>? cms;
  final ctl = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await commentsOf(p);
    final b = await blockedUids();
    if (mounted) setState(() => cms = l.where((c) => !b.contains(c.uid)).toList());
  }

  Future<void> _send() async {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    if (!await canWrite(context) || !mounted) return;
    setState(() => busy = true);
    final e = await addComment(p, t);
    if (!mounted) return;
    setState(() => busy = false);
    if (e != null) return toast(context, e);
    ctl.clear();
    FocusScope.of(context).unfocus();
    _load();
  }

  Future<void> _menu() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p.mine && p.cat == 'share') ListTile(title: Text(p.done ? '나눔 다시 열기' : '나눔 완료로 표시'), onTap: () => Navigator.pop(ctx, 'done')),
          if (p.mine || isAdmin) ListTile(title: const Text('글 지우기', style: TextStyle(color: Color(0xFFE5484D))), onTap: () => Navigator.pop(ctx, 'del')),
          if (!p.mine) ListTile(title: const Text('신고하기'), onTap: () => Navigator.pop(ctx, 'report')),
          if (!p.mine) ListTile(title: const Text('이 이웃 차단하기'), subtitle: const Text('이 사람의 글과 댓글이 더는 보이지 않아요', style: TextStyle(fontSize: 12)), onTap: () => Navigator.pop(ctx, 'block')),
        ]),
      ),
    );
    if (!mounted || r == null) return;
    if (r == 'done') {
      if (await setDone(p, !p.done) && mounted) {
        setState(() => p = Post(id: p.id, cid: p.cid, cat: p.cat, title: p.title, body: p.body, uid: p.uid, name: p.name, at: p.at, photos: p.photos, thumbs: p.thumbs, comments: p.comments, done: !p.done));
      }
    } else if (r == 'del') {
      if (await deletePost(p) && mounted) Navigator.pop(context);
    } else if (r == 'block') {
      await blockUser(p.uid);
      if (!mounted) return;
      toast(context, '차단했어요. 동네 이야기 맨 아래에서 풀 수 있어요');
      Navigator.pop(context);
    } else if (r == 'report') {
      final ok = await reportPost(p, '이용자 신고');
      if (mounted) toast(context, ok ? '신고했어요. 확인할게요' : (me == null ? '로그인하면 신고할 수 있어요' : '신고하지 못했어요'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = p.photos.isNotEmpty ? p.photos.length : p.thumbs.length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(catName(p.cat), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _menu, icon: const Icon(Icons.more_vert_rounded))],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 20), children: [
            Text(p.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.35)),
            const SizedBox(height: 6),
            Text('${p.name} · ${agoText(p.at)}${p.done ? ' · 나눔 완료' : ''}', style: T.small),
            const Divider(height: 26, color: kLine),
            if (p.body.isNotEmpty) Text(p.body, style: const TextStyle(fontSize: 15, height: 1.6)),
            for (var i = 0; i < n; i++)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(p.photo(i), fit: BoxFit.fitWidth, width: double.infinity)),
              ),
            const SizedBox(height: 24),
            Text('댓글 ${cms?.length ?? p.comments}', style: T.title),
            const SizedBox(height: 8),
            if (cms == null)
              const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: kBlue, strokeWidth: 2)))
            else
              for (final c in cms!)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5)))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.name}${c.uid == p.uid ? ' (글쓴이)' : ''} · ${agoText(c.at)}', style: T.tiny),
                        const SizedBox(height: 3),
                        Text(c.body, style: const TextStyle(fontSize: 14, height: 1.45)),
                      ]),
                    ),
                    if (c.uid != me?.uid && me != null)
                      InkWell(
                        onTap: () async {
                          await blockUser(c.uid);
                          if (mounted) toast(context, '차단했어요. 이 사람 댓글은 더 보이지 않아요');
                          _load();
                        },
                        child: const Padding(padding: EdgeInsets.all(4), child: Text('차단', style: TextStyle(fontSize: 11, color: kMute))),
                      ),
                    if (c.uid == me?.uid || isAdmin)
                      InkWell(
                        onTap: () async {
                          if (await deleteComment(p, c)) _load();
                        },
                        child: const Padding(padding: EdgeInsets.all(4), child: Text('지우기', style: TextStyle(fontSize: 11, color: kMute))),
                      ),
                  ]),
                ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: ctl,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: me == null ? '로그인하고 댓글 남기기' : '댓글을 남겨 주세요',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(onPressed: busy ? null : _send, icon: const Icon(Icons.send_rounded, color: kBlue)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------- 글쓰기 ----------------
const _photoCh = MethodChannel('dongne/photo');

class _PickedPhoto {
  final Uint8List full, thumb;
  _PickedPhoto(this.full, this.thumb);
}

class _WritePage extends StatefulWidget {
  final Complex c;
  final bool town;
  final String cat;
  const _WritePage({required this.c, this.town = false, required this.cat});
  @override
  State<_WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<_WritePage> {
  late String cat = widget.cat;
  final title = TextEditingController(), body = TextEditingController();
  final photos = <_PickedPhoto>[];
  bool busy = false;

  Future<void> _add() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (x == null) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final m = await _photoCh.invokeMapMethod<String, dynamic>('prep', {'path': x.path, 'full': 960, 'thumb': 320});
          if (m != null && m['full'] is Uint8List) {
            if (m['faceBig'] == true) {
              if (mounted) toast(context, '사람 얼굴이 크게 나온 사진은 올릴 수 없어요');
              return;
            }
            setState(() => photos.add(_PickedPhoto(m['full'] as Uint8List, m['thumb'] as Uint8List)));
            return;
          }
        } catch (_) {}
      }
      final b = await x.readAsBytes();
      if (b.length > 160 * 1024) {
        if (mounted) toast(context, '사진이 너무 커요. 다른 사진을 골라 주세요');
        return;
      }
      setState(() => photos.add(_PickedPhoto(b, b)));
    } catch (_) {}
  }

  Future<void> _send() async {
    if (title.text.trim().length < 2) return toast(context, '제목을 적어 주세요');
    setState(() => busy = true);
    final e = await writePost(c: widget.c, town: widget.town, cat: cat, title: title.text.trim(), body: body.text.trim(), photos: [for (final p in photos) p.full], thumbs: [for (final p in photos) p.thumb]);
    if (!mounted) return;
    setState(() => busy = false);
    if (e != null) return toast(context, e);
    Navigator.pop(context);
    toast(context, '올렸어요');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          title: Text(widget.town ? '글쓰기 · 우리 동네' : '글쓰기 · 우리 단지', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          actions: [
            TextButton(onPressed: busy ? null : _send, child: Text(busy ? '올리는 중' : '올리기', style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800, fontSize: 15))),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 40), children: [
          Row(children: [
            for (final (i, t) in kBoardCats.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: ChoiceChipBox(t.$2, on: cat == t.$1, onTap: () => setState(() => cat = t.$1))),
            ],
          ]),
          const SizedBox(height: 14),
          Field('제목', title, hint: cat == 'share' ? '예) 아기 의자 나눔해요' : (cat == 'rec' ? '예) 꼼꼼한 에어컨 청소 업체 추천해요' : '제목'), need: true, max: 60),
          Field('내용', body, hint: cat == 'share' ? '물건 상태, 받는 방법(문 앞·직접) 등을 적어 주세요' : '내용을 적어 주세요', lines: 7, max: 1000),
          const SizedBox(height: 4),
          Text('사진 (3장까지)', style: T.title),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(photos[i].thumb, width: 84, height: 84, fit: BoxFit.cover)),
                    Positioned(
                      right: 3,
                      top: 3,
                      child: InkWell(
                        onTap: () => setState(() => photos.removeAt(i)),
                        child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              if (photos.length < 3)
                InkWell(
                  onTap: _add,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDDE1E8))),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: kSub),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          Text('${widget.c.name} 주민에게만 보여요. 전화번호 같은 개인정보는 글에 적지 않는 게 좋아요.', style: T.tiny),
        ]),
      );
}
