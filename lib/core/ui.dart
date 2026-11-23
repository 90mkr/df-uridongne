// 공용 부품 (본부 방만 고침): 단추·알약 표시·입력 칸·양식 화면·제목·카드 틀·안내
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'icons.dart';
import 'theme.dart';

Future<void> openUrl(String url, {bool inApp = false}) async {
  try {
    await launchUrl(Uri.parse(url), mode: inApp && !kIsWeb ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> callTel(String tel) async {
  final t = tel.replaceAll(RegExp(r'[^0-9+]'), '');
  if (t.isEmpty) return;
  try {
    await launchUrl(Uri.parse('tel:$t'));
  } catch (_) {}
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13.5)), duration: const Duration(milliseconds: 1700)));
}

// 굵은 말 + 가는 말 제목 (예: 「동네」 「전화번호부」)
class MixTitle extends StatelessWidget {
  final String bold, thin;
  final double size;
  final Color color;
  const MixTitle(this.bold, this.thin, {super.key, this.size = 15, this.color = kInk});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (thin.isNotEmpty) TextSpan(text: ' $thin', style: const TextStyle(fontWeight: FontWeight.w300)),
        ]),
        style: TextStyle(fontSize: size, letterSpacing: -0.4, color: color, height: 1.25),
      );
}

// 카드 틀: 기능이 단지 홈에 붙이는 카드는 모두 이 틀 안에 내용만 넣는다
// 아이콘 이름에 맞는 그림(assets/art)이 있으면 오른쪽 위에 깔고 바탕을 그 그림 색으로 옅게 물들인다 (시안 11-23)
const _art = <String, (String, Color)>{
  'bus': ('assets/art/bus.png', Color(0xFFD6E9FD)),
  'pharm': ('assets/art/pharm.png', Color(0xFFDDF5F1)),
  'deals': ('assets/art/deals.png', Color(0xFFE6F1FD)),
};

class HomeCardBox extends StatelessWidget {
  final String icon;
  final String title;
  final Widget child;
  final String? foot;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const HomeCardBox({super.key, required this.icon, required this.title, required this.child, this.foot, this.onTap, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final art = _art[icon];
    final deco = art == null
        ? cardBox()
        : BoxDecoration(
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.white, Color.lerp(Colors.white, art.$2, 0.75)!]),
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kLine, width: 1),
            boxShadow: kShadow,
          );
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        LineIcon(icon, size: 24),
        const SizedBox(width: 7),
        Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title)),
      ]),
      const SizedBox(height: 10),
      child,
      if (foot != null) ...[
        const SizedBox(height: 8),
        Text(foot!, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
      ],
    ]);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Ink(
          decoration: deco,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Stack(children: [
              if (art != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0x99000000), Color(0xFF000000)], stops: [0, 0.5, 1]).createShader(r),
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF000000), Color(0x00000000)], stops: [0.55, 1]).createShader(r),
                      child: Image.asset(art.$1, height: icon == 'deals' ? 64 : 40, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                    ),
                  ),
                ),
              Padding(padding: padding, child: body),
            ]),
          ),
        ),
      ),
    );
  }
}

// 아직 만들지 않은 기능 카드에 들어가는 안내
class ComingSoon extends StatelessWidget {
  final String text;
  const ComingSoon([this.text = '준비하고 있어요', Key? key]) : super(key: key);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 12, color: kMute, height: 1.35));
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const Pill(this.text, {super.key, this.color = kSub, this.bg = const Color(0xFFF1F3F6)});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, height: 1.2)),
      );
}

class Btn extends StatelessWidget {
  final String text;
  final String? icon;
  final VoidCallback? onTap;
  final bool primary;
  final double h;
  const Btn(this.text, {super.key, this.icon, this.onTap, this.primary = false, this.h = 46});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : kInk;
    return Material(
      color: primary ? kBlue : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: h,
          decoration: primary ? null : BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD5D9E0))),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              LineIcon(icon!, size: 19, line: fg, fill: primary ? Colors.white.withValues(alpha: 0.25) : kSoft),
              const SizedBox(width: 6),
            ],
            Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      ),
    );
  }
}

// 기능 상세 화면의 기본 틀 (위 제목 줄 + 흰 바탕 + 가운데 정렬 최대 폭)
class DetailPage extends StatelessWidget {
  final String title;
  final String? icon;
  final List<Widget> actions;
  final Widget body;
  final bool white;
  const DetailPage({super.key, required this.title, this.icon, this.actions = const [], required this.body, this.white = true});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: white ? Colors.white : kBg,
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(children: [
            if (icon != null) ...[LineIcon(icon!, size: 24), const SizedBox(width: 8)],
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          ]),
          actions: [...actions, const SizedBox(width: 6)],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: kLine)),
        ),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body)),
      );
}

// ---- 입력 양식 ----
class FormPage extends StatelessWidget {
  final String title, lead;
  final List<Widget> children;
  final String button;
  final bool sending;
  final VoidCallback onSend;
  const FormPage({super.key, required this.title, required this.lead, required this.children, required this.button, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) => DetailPage(
        title: title,
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 30), children: [
          Text(lead, style: const TextStyle(fontSize: 13.5, color: kSub, height: 1.45)),
          const SizedBox(height: 18),
          ...children,
          const SizedBox(height: 22),
          Btn(sending ? '보내는 중…' : button, primary: true, onTap: sending ? null : onSend),
          const SizedBox(height: 10),
          const Text('보내 주신 내용은 디자인필 담당자가 확인한 뒤 반영해요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: kMute)),
        ]),
      );
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController ctl;
  final String hint;
  final int lines;
  final int max;
  final TextInputType? type;
  final bool need;
  final bool secret;
  const Field(this.label, this.ctl, {super.key, this.hint = '', this.lines = 1, this.max = 60, this.type, this.need = false, this.secret = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label.isNotEmpty) ...[
            Text.rich(TextSpan(children: [
              TextSpan(text: label),
              if (need) const TextSpan(text: ' *', style: TextStyle(color: kBlue)),
            ]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: ctl,
            maxLines: secret ? 1 : lines,
            minLines: secret ? 1 : lines,
            maxLength: max,
            obscureText: secret,
            keyboardType: type,
            style: const TextStyle(fontSize: 14.5),
            decoration: inputDeco(hint),
          ),
        ]),
      );
}

InputDecoration inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kMute, fontSize: 14),
      counterText: '',
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue)),
    );

// 고르기 칩 (네모에 가까운 둥근 칸)
class ChoiceChipBox extends StatelessWidget {
  final String text;
  final bool on;
  final VoidCallback onTap;
  const ChoiceChipBox(this.text, {super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: on ? const Color(0xFFEEF3FF) : Colors.white,
            border: Border.all(color: on ? kBlue : kLine),
          ),
          child: Text(text, style: TextStyle(fontSize: 13, color: on ? kBlue : kInk, fontWeight: FontWeight.w500)),
        ),
      );
}

// 아래에서 올라오는 창의 공통 틀
Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
            Flexible(child: builder(ctx)),
          ]),
        ),
      ),
    );


// 단지 홈 본문 한 줄 카드 (「내 차 어디 댔지」·「충전소 찾기」·「제일 싼 주유소」 같은 모양)
// 왼쪽 아이콘 · 굵은+얇은 제목 · 작은 설명 · 오른쪽(단추나 큰 숫자)
class MainRowCard extends StatelessWidget {
  final String icon, bold, thin, sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int subLines;
  const MainRowCard({super.key, required this.icon, required this.bold, required this.thin, this.sub = '', this.trailing, this.onTap, this.subLines = 2});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Ink(
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(children: [
              LineIcon(icon, size: 34),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  MixTitle(bold, thin, size: 15),
                  if (sub.isNotEmpty) ...[const SizedBox(height: 3), Text(sub, style: T.tiny, maxLines: subLines, overflow: TextOverflow.ellipsis)],
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ]),
          ),
        ),
      );
}

// 오른쪽 큰 값 (예: 「1,598원」 + 「휘발유」)
class MainValue extends StatelessWidget {
  final String value, label;
  const MainValue(this.value, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: -0.5, height: 1.15)),
        if (label.isNotEmpty) Text(label, style: T.tiny),
      ]);
}
