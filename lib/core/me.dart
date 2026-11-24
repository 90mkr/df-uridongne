// 내 정보 탭 (본부 방만 고침): 로그인 · 우리 단지 · 정책 · 관리자
import 'package:flutter/material.dart';

import 'complex_pick.dart';
import 'data.dart';
import 'fb.dart';
import 'home.dart';
import 'icons.dart';
import 'theme.dart';
import 'ui.dart';

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
                                  Text(myName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
                      if (c != null) _row('홈 화면 꾸미기', '순서 · 보일 카드', () => openHomeEditFor(context, c)),
                      _row('개인정보처리방침', '', () => openUrl('${kSiteUrl}policy/privacy.html', inApp: true)),
                      _row('이용약관', '', () => openUrl('${kSiteUrl}policy/terms.html', inApp: true)),
                      if (u != null) _row('회원 탈퇴', '', () => openUrl('${kSiteUrl}policy/delete.html', inApp: true)),
                    ]),
                    const SizedBox(height: 20),
                    const Text('우리동네 · 디자인필', style: T.tiny),
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
  bool busy = false;
  bool join = false;

  Future<void> run(Future<String?> Function() f) async {
    setState(() => busy = true);
    final err = await f();
    if (!mounted) return;
    setState(() => busy = false);
    if (err == null) {
      Navigator.pop(context);
      toast(context, join ? '가입했어요. 메일의 인증 링크를 눌러 주세요' : '로그인했어요');
    } else {
      toast(context, err);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(kPad, 16, kPad, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const MixTitle('우리동네', '로그인', size: 17),
          const SizedBox(height: 4),
          const Text('콕플 계정이 있으면 그대로 쓸 수 있어요', style: T.small),
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
          Field('', email, hint: '이메일', type: TextInputType.emailAddress, max: 80),
          Field('', pass, hint: '비밀번호 (6자 넘게)', secret: true, max: 40),
          Btn(join ? '이메일로 가입하기' : '이메일로 로그인', primary: true, onTap: busy ? null : () => run(() => signInEmail(email.text.trim(), pass.text, join: join))),
          TextButton(
            onPressed: () => setState(() => join = !join),
            child: Text(join ? '이미 가입했어요 · 로그인' : '처음이에요 · 이메일로 가입', style: const TextStyle(fontSize: 13, color: kSub)),
          ),
        ]),
      );
}
