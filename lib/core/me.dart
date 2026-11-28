// 내 정보 탭 (본부 방만 고침): 로그인 · 우리 단지 · 정책 · 관리자
import 'package:flutter/material.dart';

import 'account.dart';
import 'complex_pick.dart';
import 'feedback.dart';
import 'data.dart';
import 'fb.dart';
import 'guide.dart';
import 'home.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';
import '../features/board/noti.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: authTick,
      builder: (context, _, __) => ValueListenableBuilder(
        valueListenable: complex,
        builder: (context, c, _) {
          final u = me;
          return Scaffold(
            backgroundColor: kBg,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 28), children: [
                    const MixTitle('내', '정보', size: 19),
                    const SizedBox(height: 14),
                    Container(
                      decoration: cardBox(),
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        const LineIcon('me', size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: u == null
                              ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('로그인하면 이웃 추천을 남길 수 있어요', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 2),
                                  Text('콕플과 같은 계정으로 쓸 수 있어요', style: T.small),
                                ])
                              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  // 닉네임 누르면 바꾸기 (대표님 11-28)
                                  InkWell(
                                    onTap: () => _editNick(context),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Flexible(child: Text(myName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_outlined, size: 15, color: kSub),
                                    ]),
                                  ),
                                  Text(u.email ?? '', style: T.small),
                                ]),
                        ),
                        if (u == null)
                          SizedBox(width: 88, child: Btn('로그인', primary: true, h: 38, onTap: () => openLogin(context)))
                        else
                          TextButton(onPressed: signOut, child: const Text('로그아웃', style: TextStyle(color: kSub))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _group([
                      _row('우리 단지', c?.name ?? '고르기', () => pickComplex(context)),
                      if (c != null) _row('홈 편집', '순서 · 보일 카드', () => openHomeEditFor(context, c)),
                      if (c != null) _row('알림 설정', '게시판 · 댓글', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardNotiPage(c: c)))),
                      _row('사용 방법', '처음 안내 · 기능 설명', () => openGuide(context)),
                      _row('오류 신고 · 개선 제안', '적극 반영해 드려요', () => openFeedback(context, area: c?.areaId ?? '')),
                      if (isAdmin) _row('받은 의견 (관리자)', '', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackAdminPage()))),
                      _row('개인정보처리방침', '', () => openUrl('${kSiteUrl}policy/privacy.html', inApp: true)),
                      _row('이용약관', '', () => openUrl('${kSiteUrl}policy/terms.html', inApp: true)),
                      if (u != null) _row('회원 탈퇴', '', () => _leave(context)), // 앱 안에서 바로 (대표님 11-28 플레이 출시)
                    ]),
                    const SizedBox(height: 20),
                    const Text('우동콕 · 디자인필', style: T.tiny),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _group(List<Widget> rows) => Container(
        decoration: cardBox(),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1, color: Color(0xFFEFF1F4)), rows[i]],
        ]),
      );

  Widget _row(String k, String v, VoidCallback f) => InkWell(
        onTap: f,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Text(k, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            if (v.isNotEmpty) Text(v, style: T.small),
            const Icon(Icons.chevron_right_rounded, size: 19, color: kMute),
          ]),
        ),
      );
}

// 회원 탈퇴: 무엇이 지워지는지 보여 주고 → 최근 로그인 확인 → 지우기 → 끝 안내
Future<void> _leave(BuildContext context) async {
  const red = Color(0xFFE5484D);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('회원 탈퇴', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('탈퇴하면 아래 정보가 바로 지워지고 되살릴 수 없어요.', style: TextStyle(fontSize: 13.5, height: 1.45)),
        SizedBox(height: 10),
        Text('· 계정(이메일·닉네임)\n· 동네 이야기에 쓴 글·댓글·사진\n· 이웃 추천, 행사 알리기\n· 반려동물 수첩, 설정 백업', style: TextStyle(fontSize: 13, height: 1.55, color: kSub)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('닫기', style: TextStyle(color: kSub))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('탈퇴하기', style: TextStyle(color: red, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  if (needFreshLogin) {
    toast(context, '안전을 위해 한 번 더 로그인해 주세요. 로그인 뒤 탈퇴가 이어져요');
    await openLogin(context);
    if (!context.mounted || me == null || needFreshLogin) return;
  }
  final err = await deleteAccount();
  if (!context.mounted) return;
  if (err == 'relogin') return toast(context, '로그인 시간이 지나 탈퇴하지 못했어요. 다시 로그인한 뒤 눌러 주세요');
  if (err != null) return toast(context, err);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('탈퇴되었습니다', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: const Text('그동안 우동콕을 써 주셔서 고맙습니다.\n고른 단지와 홈 설정은 이 휴대폰에만 남아 있어요.', style: TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800)))],
    ),
  );
}

// 닉네임 바꾸기 창
Future<void> _editNick(BuildContext context) async {
  final ctl = TextEditingController(text: myName);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('닉네임 바꾸기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('동네 이야기 글·댓글에 보이는 이름이에요', style: T.small),
        const SizedBox(height: 10),
        TextField(controller: ctl, autofocus: true, maxLength: 12, decoration: inputDeco('2~12자')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기', style: TextStyle(color: kSub))),
        TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('바꾸기', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (r == null || !context.mounted) return;
  if (r.length < 2) return toast(context, '닉네임을 2자 넘게 넣어 주세요');
  final err = await setNick(r);
  if (context.mounted) toast(context, err ?? '닉네임을 바꿨어요');
}

// 가입 축하 창
Future<void> showWelcome(BuildContext context, {bool mail = false}) => showDialog(
      context: context,
      barrierColor: const Color(0x55101828),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: Color(0xFFE8F0FF), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 38, color: kBlue),
            ),
            const SizedBox(height: 16),
            const Text('가입되었습니다', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: kInk)),
            const SizedBox(height: 8),
            Text(
              '${myName.isNotEmpty ? '$myName님, ' : ''}우동콕 회원이 되신 걸 환영해요.\n자동으로 로그인되었어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.45, color: kSub, letterSpacing: -0.3),
            ),
            if (mail) ...[
              const SizedBox(height: 10),
              const Text('보내 드린 메일의 인증 링크도 눌러 주세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: kMute)),
            ],
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: Btn('확인', primary: true, onTap: () => Navigator.pop(ctx))),
          ]),
        ),
      ),
    );

// 로그인 창: 카카오 · 구글 · 이메일 (콕플과 같은 계정)
Future<void> openLogin(BuildContext context) => showSheet(context, (ctx) => const _Login());

class _Login extends StatefulWidget {
  const _Login();
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final nick = TextEditingController();
  bool busy = false;
  bool join = false;
  String? error;

  Future<void> run(Future<String?> Function() f) async {
    setState(() {
      busy = true;
      error = null;
    });
    final err = await f();
    if (!mounted) return;
    setState(() => busy = false);
    if (err == null) {
      final nav = Navigator.of(context);
      final mail = join;
      nav.pop();
      // 처음 가입이면 확인 창 — 「가입되었습니다 + 자동으로 로그인되었어요」 (대표님 11-28: 갑자기 로그인으로 바뀌면 허술해 보임)
      if (lastLoginNew) {
        showWelcome(nav.context, mail: mail);
      } else {
        toast(nav.context, '로그인했어요');
      }
    } else {
      // 아래 창 뒤로 알림이 가려져 「반응 없음」처럼 보이던 것 → 창 안에 빨간 글로 (대표님 11-28)
      setState(() => error = err);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(kPad, 16, kPad, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const MixTitle('우동콕', '로그인', size: 17),
          const SizedBox(height: 4),
          const Text('콕플 계정이 있으면 그대로 쓸 수 있어요. 로그인하면 우리 단지·홈 배치·내 기록이 저장돼 다시 깔아도 그대로예요', style: T.small),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFFFEE500),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: busy ? null : () => run(signInKakao),
              child: const SizedBox(height: 46, child: Center(child: Text('카카오로 계속하기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF191919))))),
            ),
          ),
          const SizedBox(height: 8),
          Btn('구글로 계속하기', onTap: busy ? null : () => run(signInGoogle)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Row(children: [Expanded(child: Divider(color: kLine)), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('또는 이메일', style: T.tiny)), Expanded(child: Divider(color: kLine))])),
          if (join) Field('', nick, hint: '닉네임 (동네 이야기에 보이는 이름, 2~12자)', max: 12),
          Field('', email, hint: '이메일', type: TextInputType.emailAddress, max: 80),
          Field('', pass, hint: '비밀번호 (6자 넘게)', secret: true, max: 40),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF5C2C2))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE5484D)),
                const SizedBox(width: 7),
                Expanded(child: Text(error!, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFC62F33), fontWeight: FontWeight.w600))),
              ]),
            ),
          Btn(busy ? '잠시만요…' : (join ? '이메일로 가입하기' : '이메일로 로그인'), primary: true, onTap: busy
              ? null
              : () {
                  final e = email.text.trim(), p = pass.text;
                  if (e.isEmpty || p.isEmpty) return setState(() => error = '이메일과 비밀번호를 넣어 주세요');
                  final n = nick.text.trim();
                  if (join && n.length < 2) return setState(() => error = '닉네임을 2자 넘게 넣어 주세요');
                  if (join && p.length < 6) return setState(() => error = '비밀번호는 6자 넘게 넣어 주세요');
                  run(() => signInEmail(e, p, join: join, nick: n));
                }),
          TextButton(
            onPressed: () => setState(() {
              join = !join;
              error = null;
            }),
            child: Text(join ? '이미 가입했어요 · 로그인' : '처음이에요 · 이메일로 가입', style: const TextStyle(fontSize: 13, color: kSub)),
          ),
          // 약관 동의 (플레이 정책: 글을 올리기 전 약관 동의, 대표님 11-28)
          Wrap(alignment: WrapAlignment.center, children: [
            const Text('로그인·가입하면 ', style: T.tiny),
            InkWell(onTap: () => openUrl('${kSiteUrl}policy/terms.html', inApp: true), child: const Text('이용약관', style: TextStyle(fontSize: 11.5, color: kSub, decoration: TextDecoration.underline))),
            const Text('과 ', style: T.tiny),
            InkWell(onTap: () => openUrl('${kSiteUrl}policy/privacy.html', inApp: true), child: const Text('개인정보처리방침', style: TextStyle(fontSize: 11.5, color: kSub, decoration: TextDecoration.underline))),
            const Text('에 동의하는 것으로 봐요.', style: T.tiny),
          ]),
          const SizedBox(height: 4),
          const Text('만 14세 미만은 가입할 수 없어요. 욕설·비방·광고 글은 지워지고 이용이 제한될 수 있어요.', textAlign: TextAlign.center, style: T.tiny),
        ]),
      );
}
