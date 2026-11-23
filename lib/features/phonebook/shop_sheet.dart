// 동네 전화번호부 — 가게 창 · 정보 수정 신고 · 사장님 등록 (이 폴더는 전화번호부 담당 방만 고침)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/fb.dart';
import '../../core/icons.dart';
import '../../core/me.dart' show openLogin;
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

Future<void> showShop(BuildContext context, Shop s, Complex c) => showSheet(context, (ctx) => ShopSheet(shop: s, complex: c));

void openOwnerForm(BuildContext context, Complex c, {Shop? shop, String? cat}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OwnerForm(complex: c, shop: shop, cat: cat)));

class ShopSheet extends StatelessWidget {
  final Shop shop;
  final Complex complex;
  const ShopSheet({super.key, required this.shop, required this.complex});

  @override
  Widget build(BuildContext context) {
    final s = shop;
    final cats = s.cats.map((c) => catOf(c).name).join(' · ');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.25)),
              const SizedBox(height: 4),
              Text([if (s.sub.isNotEmpty) s.sub, cats, '${complex.name}에서 ${distText(meters(complex.pos, s.pos))}'].join('  ·  '), style: T.small),
            ]),
          ),
          LineIcon(s.cats.isEmpty ? 'pin' : s.cats.first, size: 40),
        ]),
        if (s.kok != null) ...[const SizedBox(height: 14), _kok(s.kok!)],
        const SizedBox(height: 14),
        RecBox(shop: s, complex: complex),
        const SizedBox(height: 14),
        _row(context, '주소', s.addr.isEmpty ? '-' : s.addr, copy: s.addr),
        _row(context, '전화', s.tel.isEmpty ? '등록된 번호가 없어요' : s.tel, copy: s.tel),
        const SizedBox(height: 14),
        Row(children: [
          if (s.tel.isNotEmpty) ...[Expanded(child: Btn('전화하기', icon: 'phone', primary: true, onTap: () => callTel(s.tel))), const SizedBox(width: 10)],
          Expanded(child: Btn('길안내', icon: 'route', primary: s.tel.isEmpty, onTap: () => startNav(context, name: s.name, lat: s.lat, lng: s.lng))),
          const SizedBox(width: 10),
          Expanded(child: Btn('카카오맵', icon: 'map', onTap: () => openUrl(s.kakaoUrl))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _link('정보 수정 신고', () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute(builder: (_) => FixForm(shop: s, complex: complex)));
          }),
          Container(width: 1, height: 11, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 10)),
          _link('이 가게 사장님이세요?', () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute(builder: (_) => OwnerForm(complex: complex, shop: s)));
          }),
        ]),
      ]),
    );
  }

  Widget _kok(Kok k) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openUrl(kKokpleWeb),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
          decoration: BoxDecoration(color: const Color(0xFFFFF6F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE2D0))),
          child: Row(children: [
            const LineIcon('kokple', size: 24, line: Color(0xFFE8540F), fill: Color(0xFFFFD9C2)),
            const SizedBox(width: 9),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '콕플 맛집  ', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE8540F))),
                  if (k.grate > 0) TextSpan(text: '구글 ★${k.grate.toStringAsFixed(1)} (${k.greviews})'),
                  if (k.yt > 0) TextSpan(text: '  ·  유튜브 ${k.yt}편'),
                ]),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 19, color: kMute),
          ]),
        ),
      );

  Widget _row(BuildContext context, String k, String v, {String copy = ''}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 42, child: Text(k, style: const TextStyle(fontSize: 13, color: kMute, height: 1.4))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 14, height: 1.4))),
          if (copy.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copy));
                toast(context, '복사했어요');
              },
              child: const Padding(padding: EdgeInsets.only(left: 8, top: 1), child: Text('복사', style: TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600))),
            ),
        ]),
      );

  Widget _link(String t, VoidCallback f) => InkWell(
        onTap: f,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(t, style: const TextStyle(fontSize: 12.5, color: kSub, decoration: TextDecoration.underline, decorationColor: kLine)),
        ),
      );
}

// ---------------- 이웃 추천 (한 사람 한 표 + 스티커 3개까지) ----------------
class RecBox extends StatefulWidget {
  final Shop shop;
  final Complex complex;
  const RecBox({super.key, required this.shop, required this.complex});
  @override
  State<RecBox> createState() => _RecBoxState();
}

class _RecBoxState extends State<RecBox> {
  bool editing = false, busy = false;
  final picked = <String>{};

  @override
  void initState() {
    super.initState();
    recTick.addListener(_re);
    authTick.addListener(_re);
  }

  @override
  void dispose() {
    recTick.removeListener(_re);
    authTick.removeListener(_re);
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (me == null) {
      await openLogin(context);
      if (me == null) return;
      await loadRecs(widget.complex.areaId);
    }
    final r = recsOf(widget.complex.areaId)[widget.shop.id];
    setState(() {
      picked
        ..clear()
        ..addAll(r?.myStickers ?? const []);
      editing = true;
    });
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final e = await saveRec(widget.shop, widget.complex.areaId, picked.toList());
    if (!mounted) return;
    setState(() {
      busy = false;
      if (e == null) editing = false;
    });
    toast(context, e ?? '추천했어요. 고마워요!');
  }

  Future<void> _remove() async {
    setState(() => busy = true);
    final e = await removeRec(widget.shop, widget.complex.areaId);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (e == null) editing = false;
    });
    toast(context, e ?? '추천을 거뒀어요');
  }

  @override
  Widget build(BuildContext context) {
    final r = recsOf(widget.complex.areaId)[widget.shop.id];
    final n = r?.n ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: '이웃 추천 ', style: TextStyle(fontWeight: FontWeight.w400)),
            TextSpan(text: '$n', style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
          ]), style: const TextStyle(fontSize: 14.5)),
          const Spacer(),
          if (!editing)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _start,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(color: r?.mine == true ? Colors.white : kBlue, borderRadius: BorderRadius.circular(16), border: Border.all(color: r?.mine == true ? kLine : kBlue)),
                child: Text(r?.mine == true ? '내 추천 고치기' : '추천하기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: r?.mine == true ? kSub : Colors.white)),
              ),
            ),
        ]),
        if (!editing && r != null && r.st.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in r.topStickers) Pill('${stickerText(id)} ${r.st[id]}'),
          ]),
        ],
        if (!editing && n == 0)
          const Padding(padding: EdgeInsets.only(top: 4), child: Text('단골이라면 이웃들에게 알려 주세요', style: TextStyle(fontSize: 12, color: kMute))),
        if (editing) ...[
          const SizedBox(height: 10),
          const Text('어떤 점이 좋았나요? (3개까지)', style: TextStyle(fontSize: 12, color: kSub)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final st in kStickers)
              ChoiceChipBox(st.text, on: picked.contains(st.id), onTap: () {
                setState(() {
                  if (picked.contains(st.id)) {
                    picked.remove(st.id);
                  } else if (picked.length < 3) {
                    picked.add(st.id);
                  } else {
                    toast(context, '3개까지 고를 수 있어요');
                  }
                });
              }),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (r?.mine == true) ...[Expanded(child: Btn('추천 거두기', h: 40, onTap: busy ? null : _remove)), const SizedBox(width: 8)],
            Expanded(child: Btn(busy ? '저장하는 중' : '추천 남기기', primary: true, h: 40, onTap: busy ? null : _save)),
          ]),
        ],
      ]),
    );
  }
}

// ---------------- 정보 수정 신고 ----------------
class FixForm extends StatefulWidget {
  final Shop shop;
  final Complex complex;
  const FixForm({super.key, required this.shop, required this.complex});
  @override
  State<FixForm> createState() => _FixFormState();
}

class _FixFormState extends State<FixForm> {
  static const kinds = ['문을 닫았어요', '전화번호가 달라요', '주소·위치가 달라요', '이름이 바뀌었어요', '업종이 맞지 않아요', '기타'];
  final picked = <String>{};
  final text = TextEditingController();
  final contact = TextEditingController();
  bool sending = false;

  Future<void> _send() async {
    if (picked.isEmpty) return toast(context, '무엇이 다른지 하나 이상 골라 주세요');
    setState(() => sending = true);
    final ok = await sendRequest({
      'kind': 'fix',
      'sid': widget.shop.id,
      'sname': widget.shop.name,
      'area': widget.complex.areaId,
      'items': picked.toList(),
      'text': text.text.trim(),
      'contact': contact.text.trim(),
    });
    if (!mounted) return;
    setState(() => sending = false);
    toast(context, ok ? '알려 주셔서 고마워요. 확인 후 고칠게요' : '보내지 못했어요. 잠시 뒤 다시 해 주세요');
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => FormPage(
        title: '정보 수정 신고',
        lead: '「${widget.shop.name}」 정보 중 다른 것을 알려 주세요.',
        button: '신고 보내기',
        sending: sending,
        onSend: _send,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in kinds) ChoiceChipBox(k, on: picked.contains(k), onTap: () => setState(() => picked.contains(k) ? picked.remove(k) : picked.add(k))),
          ]),
          const SizedBox(height: 18),
          Field('바른 정보', text, hint: '예) 전화번호는 032-000-0000 이에요', lines: 3, max: 300),
          Field('연락처 (선택)', contact, hint: '확인이 필요할 때만 연락드려요', max: 60),
        ],
      );
}

// ---------------- 사장님 등록 ----------------
class OwnerForm extends StatefulWidget {
  final Complex complex;
  final Shop? shop;
  final String? cat;
  const OwnerForm({super.key, required this.complex, this.shop, this.cat});
  @override
  State<OwnerForm> createState() => _OwnerFormState();
}

class _OwnerFormState extends State<OwnerForm> {
  late final name = TextEditingController(text: widget.shop?.name ?? '');
  late final tel = TextEditingController(text: widget.shop?.tel ?? '');
  late final addr = TextEditingController(text: widget.shop?.addr ?? '');
  final hours = TextEditingController();
  final intro = TextEditingController();
  final owner = TextEditingController();
  final contact = TextEditingController();
  late String cat = widget.cat ?? (widget.shop?.cats.firstOrNull ?? '');
  bool sending = false;

  Future<void> _send() async {
    if (name.text.trim().isEmpty || tel.text.trim().isEmpty || addr.text.trim().isEmpty || cat.isEmpty) {
      return toast(context, '가게 이름·업종·전화·주소는 꼭 적어 주세요');
    }
    if (contact.text.trim().isEmpty) return toast(context, '확인 연락을 받을 번호를 적어 주세요');
    setState(() => sending = true);
    final ok = await sendRequest({
      'kind': 'owner',
      'sid': widget.shop?.id ?? '',
      'sname': name.text.trim(),
      'area': widget.complex.areaId,
      'cat': cat,
      'tel': tel.text.trim(),
      'addr': addr.text.trim(),
      'hours': hours.text.trim(),
      'text': intro.text.trim(),
      'owner': owner.text.trim(),
      'contact': contact.text.trim(),
    });
    if (!mounted) return;
    setState(() => sending = false);
    toast(context, ok ? '등록 신청을 받았어요. 확인 전화를 드린 뒤 올려 드릴게요' : '보내지 못했어요. 잠시 뒤 다시 해 주세요');
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => FormPage(
        title: widget.shop == null ? '우리 가게 등록' : '사장님 정보 등록',
        lead: widget.shop == null ? '인터넷에 아직 없는 동네 가게도 이웃이 찾을 수 있게 올려 드려요.\n등록은 무료예요.' : '영업시간·소개를 적어 주시면 가게 화면에 함께 보여 드려요.\n등록은 무료예요.',
        button: '등록 신청하기',
        sending: sending,
        onSend: _send,
        children: [
          Field('가게 이름', name, need: true, max: 40),
          const Text.rich(TextSpan(children: [TextSpan(text: '업종'), TextSpan(text: ' *', style: TextStyle(color: kBlue))]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final c in kCats) ChoiceChipBox(c.name, on: cat == c.id, onTap: () => setState(() => cat = c.id))]),
          const SizedBox(height: 16),
          Field('가게 전화', tel, need: true, type: TextInputType.phone, max: 20),
          Field('주소', addr, need: true, hint: '도로명 주소', max: 80),
          Field('영업시간', hours, hint: '예) 평일 9시~8시, 일요일 휴무', max: 80),
          Field('한 줄 소개', intro, hint: '예) 30년 된 동네 떡집, 주문 떡 가능', lines: 2, max: 120),
          Field('대표자 이름', owner, max: 20),
          Field('확인 연락처', contact, need: true, hint: '사장님 확인 전화를 드릴 번호 (공개 안 됨)', type: TextInputType.phone, max: 30),
        ],
      );
}
