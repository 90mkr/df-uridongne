// 사용 방법 · 처음 안내 (본부 방만 고침, 대표님 11-27)
// - 사용 방법(GuidePage): 생활 도구 맨 아래 「앱 설정」·내 정보에서 연다. 단계마다 작은 휴대폰 그림 + 「바로 해 보기」.
// - 처음 안내(IntroPage): 처음 설치하고 켜면 1·2·3단계로 한 번 보여 준다 (prefs 'intro.seen'). 사용 방법에서 다시 볼 수 있다.
// - 영상 안내는 나중에 유튜브 짧은 영상이 생기면 각 단계에 붙인다 (youtube_player_iframe 이미 들어 있음).
import 'package:flutter/material.dart';

import '../features/board/noti.dart';
import 'complex_pick.dart';
import 'data.dart';
import 'home.dart';
import 'icons.dart';
import 'me.dart';
import 'theme.dart';
import 'ui.dart';

const kIntroKey = 'intro.seen';

// ─────────────────────────────── 처음 안내 ───────────────────────────────
// 아직 안 봤으면 보여 주고 true (shell 이 부른다)
Future<bool> showIntroIfNew(BuildContext context) async {
  if (await prefGet(kIntroKey) == '1') return false;
  if (!context.mounted) return false;
  await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const IntroPage()));
  return true;
}

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});
  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final pc = PageController();
  int i = 0;

  static final _steps = <(String, String, String, Widget Function(double))>[
    ('우리 동네,', '필요한 것만 콕', '버스·분리수거·문 연 약국·주유소 최저가까지\n우리 동네 생활 정보를 한 앱에 모았어요.', (w) => _Phone(w: w, child: const _HomeMock())),
    ('먼저', '우리 단지를 골라 주세요', '단지를 고르면 버스·날씨·분리수거가\n우리 단지 기준으로 바로 맞춰져요.', (w) => _Phone(w: w, child: const _PickMock())),
    ('홈은', '내 마음대로', '자주 보는 건 크게, 가끔 쓰는 건 아이콘으로.\n카드를 꾹 누르면 바로 바꿀 수 있어요.', (w) => _Phone(w: w, child: const _PressMock())),
  ];

  Future<void> _done() async {
    await prefSet(kIntroKey, '1');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = i == _steps.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 48,
            child: Row(children: [
              const SizedBox(width: kPad),
              Text('${i + 1} / ${_steps.length}', style: const TextStyle(fontSize: 12.5, color: kMute, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!last) TextButton(onPressed: _done, child: const Text('건너뛰기', style: TextStyle(fontSize: 13.5, color: kSub))),
              const SizedBox(width: 8),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: pc,
              itemCount: _steps.length,
              onPageChanged: (v) => setState(() => i = v),
              itemBuilder: (context, k) {
                final s = _steps[k];
                return LayoutBuilder(builder: (context, box) {
                  final pw = (box.maxHeight * 0.52).clamp(150.0, 230.0);
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          // 그림 뒤 옅은 빛
                          Stack(alignment: Alignment.center, children: [
                            Container(
                              width: pw * 1.7,
                              height: pw * 1.7,
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFE3ECFF), Color(0x00E3ECFF)])),
                            ),
                            s.$4(pw),
                          ]),
                          const SizedBox(height: 18),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${s.$1} ', style: const TextStyle(fontWeight: FontWeight.w300)),
                              TextSpan(text: s.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                            ]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 23, letterSpacing: -0.8, height: 1.25, color: kInk),
                          ),
                          const SizedBox(height: 10),
                          Text(s.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: kSub, height: 1.45, letterSpacing: -0.2)),
                        ]),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
          // 점 + 단추
          Padding(
            padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < _steps.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: k == i ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: k == i ? kBlue : const Color(0xFFD6DCE6), borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Btn(last ? '시작하기' : '다음', primary: true, h: 50, onTap: () {
                    if (last) {
                      _done();
                    } else {
                      pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
                    }
                  }),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────── 사용 방법 ───────────────────────────────
void openGuide(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidePage()));

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = complex.value;
    void back(VoidCallback f) {
      Navigator.pop(context);
      f();
    }

    final steps = <_Step>[
      _Step('우리 단지 고르기', '처음 한 번만 고르면 버스·날씨·분리수거가 우리 단지 기준으로 맞춰져요.', const _PickMock(), [
        '홈 맨 위 단지 이름을 누르거나',
        '「내 정보」 → 「우리 단지」에서 바꿀 수 있어요',
      ], '우리 단지 고르기', () => pickComplex(context)),
      _Step('홈 꾸미기', '위에는 오늘 바뀌는 정보가 큰 카드로, 아래에는 바로가기 아이콘이 한 줄로 있어요.', const _PressMock(), [
        '카드를 꾹 누르면 「아이콘으로 내리기 · 크게 보기로 올리기 · 홈에서 빼기」',
        '「홈 편집」에서는 순서를 바꾸고 칸을 켜고 끌 수 있어요',
      ], '홈 편집 열기', c == null ? null : () => back(() => openHomeEditFor(context, c))),
      _Step('생활 도구', '우동콕의 모든 기능이 한곳에 모여 있어요.', const _ToolsMock(), [
        '아래 메뉴 「생활 도구」 또는 홈 아이콘 줄 끝 「전체 보기」',
        '자주 쓰는 건 홈에 꺼내 두면 더 빨라요',
      ], null, null),
      _Step('지금 내 위치로 찾기', '화장실·약국·주유소처럼 가까운 곳을 찾을 때, 밖에 나와 있으면 내 위치 기준으로 바꿀 수 있어요.', const _HereMock(), [
        '찾기 화면 아래 「우리 단지 기준 | 내 위치로」를 누르세요',
        '단지에서 1.5km 넘게 나와 있으면 저절로 내 위치 기준이 돼요',
      ], null, null),
      _Step('로그인하면 그대로 저장', '앱을 다시 깔거나 휴대폰을 바꿔도 우리 단지·홈 배치·내 기록이 그대로 돌아와요.', const _LoginMock(), [
        '카카오·구글·이메일 중 편한 것으로',
        '콕플 계정이 있으면 그대로 쓸 수 있어요',
      ], '로그인하기', () => openLogin(context)),
      _Step('알림 받기', '게시판 새 글, 내 글에 달린 댓글을 알림으로 받아요.', const _NotiMock(), [
        '「내 정보」 → 「알림 설정」에서 받을 것만 고르세요',
      ], '알림 설정', c == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardNotiPage(c: c)))),
      _Step('급할 때 바로가기', '휴대폰 바탕화면의 우동콕 아이콘을 꾹 누르면 「가까운 화장실」이 바로 떠요.', const _ShortcutMock(), [
        '앱을 열지 않고도 한 번에 찾을 수 있어요',
      ], null, null),
    ];

    return DetailPage(
      title: '사용 방법',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 34), children: [
        // 머리
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E6BF2), Color(0xFF1E4FD8)]),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$kAppName, ', style: TextStyle(fontWeight: FontWeight.w300)),
                    TextSpan(text: '이렇게 쓰세요', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  style: TextStyle(fontSize: 19, color: Colors.white, letterSpacing: -0.6, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text('${steps.length}가지만 알면 충분해요', style: const TextStyle(fontSize: 12.5, color: Color(0xFFDCE6FF))),
                const SizedBox(height: 12),
                Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const IntroPage())),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Text('처음 안내 다시 보기', style: TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
            ),
            const LineIcon('apt', size: 64),
          ]),
        ),
        const SizedBox(height: 14),
        for (final (n, s) in steps.indexed) ...[_StepCard(n: n + 1, s: s), const SizedBox(height: 12)],
        const SizedBox(height: 6),
        const Center(child: Text('더 궁금한 점은 「단지 이야기」에 남겨 주시면 답해 드려요', style: T.tiny)),
      ]),
    );
  }
}

class _Step {
  final String title, lead;
  final Widget mock;
  final List<String> how;
  final String? go;
  final VoidCallback? onGo;
  const _Step(this.title, this.lead, this.mock, this.how, this.go, this.onGo);
}

class _StepCard extends StatelessWidget {
  final int n;
  final _Step s;
  const _StepCard({required this.n, required this.s});

  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('STEP ${n.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: 0.6)),
              const SizedBox(height: 3),
              Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(s.lead, style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
              const SizedBox(height: 8),
              for (final h in s.how)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 6, right: 6), child: SizedBox(width: 4, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: kMute, shape: BoxShape.circle)))),
                    Expanded(child: Text(h, style: const TextStyle(fontSize: 12.5, height: 1.4))),
                  ]),
                ),
              if (s.go != null && s.onGo != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: s.onGo,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9D8FB)), borderRadius: BorderRadius.circular(18)),
                    child: Text('${s.go} ›', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kBlue)),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          _Phone(w: 92, child: s.mock),
        ]),
      );
}

// ─────────────────────────────── 작은 휴대폰 그림 ───────────────────────────────
// 두꺼운 검은 테두리 (대표님 휴대폰 미리보기 취향) · 안은 실제 화면을 단순하게 줄인 그림
class _Phone extends StatelessWidget {
  final double w;
  final Widget child;
  const _Phone({required this.w, required this.child});
  @override
  Widget build(BuildContext context) {
    final b = w * 0.055;
    return Container(
      width: w,
      height: w * 2.0,
      padding: EdgeInsets.all(b),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2130),
        borderRadius: BorderRadius.circular(w * 0.17),
        boxShadow: const [BoxShadow(color: Color(0x261C3A6E), blurRadius: 14)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.13),
        child: ColoredBox(
          color: kBg,
          // 그림은 180폭 기준으로 그리고 크기만 맞춘다
          child: FittedBox(fit: BoxFit.cover, alignment: Alignment.topCenter, child: SizedBox(width: 180, height: 360, child: child)),
        ),
      ),
    );
  }
}

Widget _bar(double w, {double h = 7, Color c = const Color(0xFFDCE2EC)}) => Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h / 2)));

BoxDecoration _box({Color c = Colors.white}) => BoxDecoration(color: c, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE3E8F0)));

Widget _top(String t) => Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      color: Colors.white,
      child: Row(children: [
        const LineIcon('apt', size: 18),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ]),
    );

class _HomeMock extends StatelessWidget {
  const _HomeMock();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top('우리 단지 홈'),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (ic, t) in [('bus', '단지 앞 버스  3분'), ('trash', '오늘은 플라스틱'), ('gas', '최저가 1,598원')]) ...[
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: _box(),
                child: Row(children: [
                  LineIcon(ic, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      const SizedBox(height: 5),
                      _bar(70, h: 5),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 4),
            const Text('생활 바로가기', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final ic in ['weather', 'toilet', 'pharm', 'parking'])
                Container(width: 36, height: 36, decoration: _box(), alignment: Alignment.center, child: LineIcon(ic, size: 24)),
            ]),
          ]),
        ),
      ]);
}

class _PickMock extends StatelessWidget {
  const _PickMock();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top('우리 단지 고르기'),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: kBlue)),
              child: const Row(children: [
                Icon(Icons.search_rounded, size: 14, color: kBlue),
                SizedBox(width: 4),
                Text('단지 이름으로 찾기', style: TextStyle(fontSize: 9.5, color: kSub)),
              ]),
            ),
            const SizedBox(height: 10),
            for (final (k, t) in [(false, '푸른마을 1단지'), (true, '더테라스'), (false, '해돋이 아파트')]) ...[
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: k ? const Color(0xFFEEF3FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: k ? kBlue : const Color(0xFFE3E8F0)),
                ),
                child: Row(children: [
                  const LineIcon('apt', size: 22),
                  const SizedBox(width: 6),
                  Text(t, style: TextStyle(fontSize: 10, fontWeight: k ? FontWeight.w800 : FontWeight.w500)),
                  const Spacer(),
                  if (k) const Icon(Icons.check_circle_rounded, size: 15, color: kBlue),
                ]),
              ),
              const SizedBox(height: 6),
            ],
          ]),
        ),
      ]);
}

class _PressMock extends StatelessWidget {
  const _PressMock();
  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(child: _HomeMock()),
        Positioned.fill(child: ColoredBox(color: const Color(0xFF1C2130).withValues(alpha: 0.28))),
        Positioned(
          left: 14,
          right: 14,
          top: 118,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x331C3A6E), blurRadius: 12)]),
            child: Column(children: [
              for (final (ic, t) in [(Icons.south_rounded, '아이콘으로 내리기'), (Icons.north_rounded, '크게 보기로 올리기'), (Icons.close_rounded, '홈에서 빼기')])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(children: [
                    Icon(ic, size: 13, color: kBlue),
                    const SizedBox(width: 6),
                    Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ),
        const Positioned(left: 96, top: 84, child: Icon(Icons.touch_app_rounded, size: 34, color: Colors.white)),
      ]);
}

class _ToolsMock extends StatelessWidget {
  const _ToolsMock();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top('생활 도구'),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final ic in ['toilet', 'weather', 'bus', 'trash', 'pharm', 'gas', 'charger', 'parking', 'post', 'subway', 'pet', 'school', 'event', 'alarm', 'lotto', 'public'])
              Container(width: 35, height: 40, decoration: _box(), alignment: Alignment.center, child: LineIcon(ic, size: 24)),
          ]),
        ),
      ]);
}

class _HereMock extends StatelessWidget {
  const _HereMock();
  @override
  Widget build(BuildContext context) => Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _top('가까운 화장실'),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              for (final d in ['120m', '340m', '510m', '780m'])
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: _box(),
                  child: Row(children: [
                    const LineIcon('toilet', size: 22),
                    const SizedBox(width: 6),
                    _bar(60, h: 6),
                    const Spacer(),
                    Text(d, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kBlue)),
                  ]),
                ),
            ]),
          ),
        ]),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFF1C2130), borderRadius: BorderRadius.circular(16)),
              child: const Text.rich(
                TextSpan(children: [
                  TextSpan(text: '우리 단지 기준  |  ', style: TextStyle(color: Color(0xFFB8C0D0))),
                  TextSpan(text: '내 위치로', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
                style: TextStyle(fontSize: 9.5),
              ),
            ),
          ),
        ),
      ]);
}

class _LoginMock extends StatelessWidget {
  const _LoginMock();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top('로그인'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('한 번 로그인하면\n어디서나 그대로', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.3, letterSpacing: -0.4)),
            const SizedBox(height: 16),
            Container(height: 32, decoration: BoxDecoration(color: const Color(0xFFFEE500), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('카카오로 계속하기', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700))),
            const SizedBox(height: 6),
            Container(height: 32, decoration: _box(), alignment: Alignment.center, child: const Text('구글로 계속하기', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            Container(height: 32, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('이메일로 로그인', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ),
      ]);
}

class _NotiMock extends StatelessWidget {
  const _NotiMock();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top('알림 설정'),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: _box(),
            child: Column(children: [
              for (final (t, on) in [('게시판 새 글', true), ('내 글 댓글', true), ('분실물', false), ('나눔·장터', true)])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(children: [
                    Text(t, style: const TextStyle(fontSize: 10)),
                    const Spacer(),
                    Container(
                      width: 26,
                      height: 15,
                      padding: const EdgeInsets.all(2),
                      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                      decoration: BoxDecoration(color: on ? kBlue : const Color(0xFFD6DCE6), borderRadius: BorderRadius.circular(8)),
                      child: const SizedBox(width: 11, height: 11, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ]);
}

class _ShortcutMock extends StatelessWidget {
  const _ShortcutMock();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8FB4F5), Color(0xFFC8D9FA)])),
        child: Stack(children: [
          Positioned(
            left: 30,
            top: 120,
            child: Container(
              width: 120,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x331C3A6E), blurRadius: 10)]),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  LineIcon('toilet', size: 20),
                  SizedBox(width: 6),
                  Text('가까운 화장실', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 176,
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFF015DFD), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('콕', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              const Text(kAppName, style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Positioned(left: 56, top: 196, child: Icon(Icons.touch_app_rounded, size: 30, color: Colors.white)),
        ]),
      );
}
