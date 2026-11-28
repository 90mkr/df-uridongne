// 오류·개선 의견 보내기 + 글쓰기 자격(이메일 인증) + 이웃 차단 (본부 방만 고침, 대표님 11-28 출시 준비)
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'fb.dart';
import 'me.dart' show openLogin;
import 'theme.dart';
import 'ui.dart';

const kAppVersionText = '0.1.0';

// ---------------- 글쓰기 자격 ----------------
/// 이메일로 가입한 사람은 메일 인증을 마쳐야 글·댓글을 쓸 수 있다 (카카오·구글은 이미 확인된 계정이라 바로)
bool get needMailCheck {
  final u = me;
  if (u == null) return false;
  final mail = u.providerData.any((p) => p.providerId == 'password');
  return mail && !u.emailVerified;
}

/// 글쓰기 전에 부름: 로그인 + (이메일 가입이면) 인증 확인. 쓸 수 있으면 true
Future<bool> canWrite(BuildContext context) async {
  if (me == null) {
    toast(context, '로그인하면 글을 쓸 수 있어요');
    await openLogin(context);
    if (me == null || !context.mounted) return false;
  }
  if (!needMailCheck) return true;
  try {
    await me!.reload();
  } catch (_) {}
  if (!needMailCheck) return true;
  if (!context.mounted) return false;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('이메일 인증이 필요해요', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Text('${me?.email ?? '가입한 메일'}로 보낸 인증 링크를 눌러 주세요.\n인증을 마치면 바로 글과 댓글을 쓸 수 있어요.', style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await me?.sendEmailVerification();
              if (ctx.mounted) toast(ctx, '인증 메일을 다시 보냈어요');
            } catch (_) {
              if (ctx.mounted) toast(ctx, '잠시 뒤에 다시 눌러 주세요');
            }
          },
          child: const Text('인증 메일 다시 보내기', style: TextStyle(color: kSub)),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return false;
}

// ---------------- 이웃 차단 (이 휴대폰 안에만) ----------------
final blockTick = ValueNotifier<int>(0);
Set<String> _blocked = {};
bool _blockLoaded = false;

Future<Set<String>> blockedUids() async {
  if (!_blockLoaded) {
    final s = await prefGet('board.blocked') ?? '';
    _blocked = s.split(',').where((e) => e.isNotEmpty).toSet();
    _blockLoaded = true;
  }
  return _blocked;
}

bool isBlocked(String uid) => _blocked.contains(uid);

Future<void> blockUser(String uid) async {
  await blockedUids();
  _blocked.add(uid);
  await prefSet('board.blocked', _blocked.join(','));
  blockTick.value++;
}

Future<void> unblockAll() async {
  _blocked = {};
  _blockLoaded = true;
  await prefSet('board.blocked', '');
  blockTick.value++;
}

// ---------------- 오류·개선 의견 ----------------
Future<void> openFeedback(BuildContext context, {String area = ''}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FeedbackSheet(area: area),
    );

class _FeedbackSheet extends StatefulWidget {
  final String area;
  const _FeedbackSheet({required this.area});
  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  String kind = 'bug';
  final text = TextEditingController();
  late final contact = TextEditingController(text: me?.email ?? '');
  bool busy = false;
  String? error;

  Future<void> _send() async {
    final t = text.text.trim();
    if (t.length < 5) return setState(() => error = '내용을 조금 더 적어 주세요 (5자 넘게)');
    setState(() {
      busy = true;
      error = null;
    });
    var ok = false;
    if (await fbReady()) {
      try {
        await db.collection('dn_feedback').add({
          'kind': kind,
          'text': t,
          'contact': contact.text.trim(),
          'uid': me?.uid ?? '',
          'name': myName,
          'area': widget.area,
          'ver': kAppVersionText,
          'os': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'st': 'new',
          'at': fs.FieldValue.serverTimestamp(),
        });
        ok = true;
      } catch (e) {
        debugPrint('의견 보내기: $e');
      }
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return setState(() => error = '보내지 못했어요. 인터넷을 확인하고 다시 눌러 주세요');
    final nav = Navigator.of(context);
    nav.pop();
    await showDialog(
      context: nav.context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('잘 받았습니다', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(kind == 'bug' ? '알려 주셔서 고맙습니다.\n확인하고 빠르게 고치겠습니다.' : '좋은 의견 고맙습니다.\n적극 반영해 더 좋은 우동콕을 만들겠습니다.', style: const TextStyle(fontSize: 13.5, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800)))],
      ),
    );
  }

  Widget _kind(String id, String label, IconData ic) {
    final on = kind == id;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => kind = id),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEEF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? kBlue : kLine),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, size: 18, color: on ? kBlue : kSub),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? kBlue : kInk)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(kPad, 18, kPad, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const MixTitle('오류·개선', '의견 보내기', size: 18),
          const SizedBox(height: 4),
          const Text('보내 주신 의견은 대표가 직접 읽고 적극 반영해 드리겠습니다.', style: T.small),
          const SizedBox(height: 16),
          Row(children: [
            _kind('bug', '오류 신고', Icons.error_outline_rounded),
            const SizedBox(width: 10),
            _kind('idea', '개선 제안', Icons.lightbulb_outline_rounded),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: text,
            minLines: 5,
            maxLines: 8,
            maxLength: 1000,
            decoration: inputDeco(kind == 'bug' ? '어느 화면에서 무엇이 안 되는지 적어 주세요\n예) 주차장 화면에서 지도로 보기를 누르면 멈춰요' : '이런 기능이 있으면 좋겠어요, 여기가 불편해요 등 편하게 적어 주세요'),
          ),
          Field('', contact, hint: '답을 받을 이메일·연락처 (적지 않아도 돼요)', max: 80),
          if (error != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: const TextStyle(fontSize: 13, color: Color(0xFFC62F33), fontWeight: FontWeight.w600))),
          Btn(busy ? '보내는 중…' : '보내기', primary: true, onTap: busy ? null : _send),
        ]),
      );
}

/// 게시판 맨 아래 강조 칸
class FeedbackBanner extends StatelessWidget {
  final String area;
  const FeedbackBanner({super.key, this.area = ''});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => openFeedback(context, area: area),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                boxShadow: const [BoxShadow(color: Color(0x332563EB), blurRadius: 16)],
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '오류 신고 ', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: '· 개선 제안', style: TextStyle(fontWeight: FontWeight.w300)),
                      ]),
                      style: TextStyle(fontSize: 17, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text('보내 주신 의견, 적극 반영해 드리겠습니다', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), letterSpacing: -0.3)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text('의견 보내기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlue)),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ---------------- 관리자: 받은 의견 ----------------
class FeedbackAdminPage extends StatefulWidget {
  const FeedbackAdminPage({super.key});
  @override
  State<FeedbackAdminPage> createState() => _FeedbackAdminPageState();
}

class _FeedbackAdminPageState extends State<FeedbackAdminPage> {
  List<fs.QueryDocumentSnapshot<Map<String, dynamic>>>? l;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await db.collection('dn_feedback').orderBy('at', descending: true).limit(200).get();
      if (mounted) setState(() => l = q.docs);
    } catch (e) {
      if (mounted) setState(() => l = []);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kBg, elevation: 0, title: const Text('받은 의견', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        body: l == null
            ? const Center(child: CircularProgressIndicator(color: kBlue))
            : l!.isEmpty
                ? const Center(child: Text('아직 받은 의견이 없어요', style: T.small))
                : ListView.separated(
                    padding: const EdgeInsets.all(kPad),
                    itemCount: l!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = l![i].data();
                      final at = (d['at'] as fs.Timestamp?)?.toDate();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: cardBox(),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(d['kind'] == 'bug' ? '오류' : '개선', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: d['kind'] == 'bug' ? const Color(0xFFE5484D) : kBlue)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${d['name'] ?? ''} · ${d['area'] ?? ''} · ${at == null ? '' : '${at.month}/${at.day} ${at.hour}:${at.minute.toString().padLeft(2, '0')}'}', style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            InkWell(
                              onTap: () async {
                                await l![i].reference.delete();
                                _load();
                              },
                              child: const Padding(padding: EdgeInsets.all(4), child: Text('지우기', style: TextStyle(fontSize: 11.5, color: kMute))),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Text('${d['text'] ?? ''}', style: const TextStyle(fontSize: 14, height: 1.5)),
                          if ('${d['contact'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('연락처 ${d['contact']}', style: T.small)),
                        ]),
                      );
                    },
                  ),
      );
}
