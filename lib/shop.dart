part of 'main.dart';

// ---------------- 가게 화면 (아래에서 올라오는 창) ----------------

Future<void> showShop(BuildContext context, Shop s, Area area) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (_) => ShopSheet(shop: s, area: area),
    );

class ShopSheet extends StatelessWidget {
  final Shop shop;
  final Area area;
  const ShopSheet({super.key, required this.shop, required this.area});

  @override
  Widget build(BuildContext context) {
    final s = shop;
    final p = myPos.value;
    final dist = p != null && meters(p, s.pos) < 20000 ? distText(meters(p, s.pos)) : null;
    final cats = s.cats.map((c) => catOf(c).name).join(' · ');
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.25)),
                  const SizedBox(height: 4),
                  Text([if (s.sub.isNotEmpty) s.sub, cats, if (dist != null) dist].join('  ·  '),
                      style: const TextStyle(fontSize: 12.5, color: kSub)),
                ]),
              ),
              LineIcon(s.cats.isEmpty ? 'pin' : s.cats.first, size: 40),
            ]),
            if (s.kok != null) ...[
              const SizedBox(height: 14),
              _kokBox(s.kok!),
            ],
            const SizedBox(height: 16),
            _row('주소', s.addr.isEmpty ? '-' : s.addr, onCopy: s.addr.isEmpty ? null : () => _copy(context, s.addr)),
            _row('전화', s.tel.isEmpty ? '등록된 번호가 없어요' : s.tel, onCopy: s.tel.isEmpty ? null : () => _copy(context, s.tel)),
            const SizedBox(height: 16),
            Row(children: [
              if (s.tel.isNotEmpty) ...[
                Expanded(child: Btn('전화하기', icon: 'phone', primary: true, onTap: () => callTel(s.tel))),
                const SizedBox(width: 10),
              ],
              Expanded(child: Btn('길안내', icon: 'route', primary: s.tel.isEmpty, onTap: () => startNav(context, s))),
              const SizedBox(width: 10),
              Expanded(child: Btn('카카오맵', icon: 'map', onTap: () => openUrl(s.kakaoUrl))),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _link('정보 수정 신고', () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(MaterialPageRoute(builder: (_) => FixForm(shop: s, area: area)));
              }),
              Container(width: 1, height: 11, color: kLine, margin: const EdgeInsets.symmetric(horizontal: 10)),
              _link('이 가게 사장님이세요?', () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(MaterialPageRoute(builder: (_) => OwnerForm(area: area, shop: s)));
              }),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _kokBox(Kok k) => InkWell(
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
                style: const TextStyle(fontSize: 12.5, color: kInk),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 19, color: kMute),
          ]),
        ),
      );

  Widget _row(String k, String v, {VoidCallback? onCopy}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 42, child: Text(k, style: const TextStyle(fontSize: 13, color: kMute, height: 1.4))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 14, height: 1.4))),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 1),
                child: Text('복사', style: TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
              ),
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

  void _copy(BuildContext context, String t) {
    Clipboard.setData(ClipboardData(text: t));
    toast(context, '복사했어요');
  }
}

// ---------------- 길안내 (카카오맵 · 네이버 · 티맵) ----------------

Future<void> startNav(BuildContext context, Shop s) async {
  final saved = await _navPref();
  if (!context.mounted) return;
  if (saved.isNotEmpty) return _launchNav(saved, s);
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.12),
    builder: (ctx) {
      var keep = false;
      return StatefulBuilder(
        builder: (ctx, set) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('어느 앱으로 안내할까요', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final a in const [('kakao', '카카오맵'), ('naver', '네이버'), ('tmap', '티맵')])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Btn('${a.$2}으로 길안내', onTap: () {
                      if (keep) _setNavPref(a.$1);
                      Navigator.pop(ctx);
                      _launchNav(a.$1, s);
                    }),
                  ),
                InkWell(
                  onTap: () => set(() => keep = !keep),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(keep ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 19, color: keep ? kBlue : kMute),
                      const SizedBox(width: 6),
                      const Text('다음부터 이 앱으로 바로 열기', style: TextStyle(fontSize: 13, color: kSub)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    },
  );
}

Future<String> _navPref() async {
  try {
    return (await SharedPreferences.getInstance()).getString('navApp') ?? '';
  } catch (_) {
    return '';
  }
}

Future<void> _setNavPref(String id) async {
  try {
    await (await SharedPreferences.getInstance()).setString('navApp', id);
  } catch (_) {}
}

Future<void> _launchNav(String app, Shop s) async {
  final n = Uri.encodeComponent(s.name);
  final lat = s.lat, lng = s.lng;
  final web = switch (app) {
    'kakao' => 'https://map.kakao.com/link/to/$n,$lat,$lng',
    'naver' => 'https://map.naver.com/p/search/$n',
    _ => 'https://map.kakao.com/link/to/$n,$lat,$lng',
  };
  if (kIsWeb) return openUrl(web);
  final scheme = switch (app) {
    'kakao' => 'kakaomap://route?ep=$lat,$lng&by=CAR',
    'naver' => 'nmap://route/car?dlat=$lat&dlng=$lng&dname=$n&appname=kr.designfeel.dongne',
    _ => 'tmap://route?goalname=$n&goalx=$lng&goaly=$lat',
  };
  try {
    if (await launchUrl(Uri.parse(scheme), mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  await openUrl(web);
}

// ---------------- 신청 양식 공용 ----------------

class FormPage extends StatelessWidget {
  final String title, lead;
  final List<Widget> children;
  final String button;
  final bool sending;
  final VoidCallback onSend;
  const FormPage({super.key, required this.title, required this.lead, required this.children, required this.button, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: kLine))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
            Text(lead, style: const TextStyle(fontSize: 13.5, color: kSub, height: 1.45)),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 22),
            Btn(sending ? '보내는 중…' : button, primary: true, onTap: sending ? null : onSend),
            const SizedBox(height: 10),
            const Text('보내 주신 내용은 디자인필 담당자가 확인한 뒤 반영해요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: kMute)),
          ]),
        ),
      ),
    );
  }
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController ctl;
  final String hint;
  final int lines;
  final int max;
  final TextInputType? type;
  final bool need;
  const Field(this.label, this.ctl, {super.key, this.hint = '', this.lines = 1, this.max = 60, this.type, this.need = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: label),
            if (need) const TextSpan(text: ' *', style: TextStyle(color: kBlue)),
          ]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctl,
            maxLines: lines,
            minLines: lines,
            maxLength: max,
            keyboardType: type,
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: kMute, fontSize: 14),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue)),
            ),
          ),
        ]),
      );
}

// ---------------- 정보 수정 신고 ----------------

class FixForm extends StatefulWidget {
  final Shop shop;
  final Area area;
  const FixForm({super.key, required this.shop, required this.area});
  @override
  State<FixForm> createState() => _FixFormState();
}

class _FixFormState extends State<FixForm> {
  static const kinds = ['문을 닫았어요', '전화번호가 달라요', '주소·위치가 달라요', '이름이 바뀌었어요', '분야가 맞지 않아요', '기타'];
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
      'area': widget.area.id,
      'items': picked.toList(),
      'text': text.text.trim(),
      'contact': contact.text.trim(),
    });
    if (!mounted) return;
    setState(() => sending = false);
    if (ok) {
      toast(context, '알려 주셔서 고마워요. 확인 후 고칠게요');
      Navigator.pop(context);
    } else {
      toast(context, '보내지 못했어요. 잠시 뒤 다시 해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: '정보 수정 신고',
      lead: '「${widget.shop.name}」 정보 중 다른 것을 알려 주세요.',
      button: '신고 보내기',
      sending: sending,
      onSend: _send,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in kinds)
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => setState(() => picked.contains(k) ? picked.remove(k) : picked.add(k)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: picked.contains(k) ? const Color(0xFFEEF3FF) : Colors.white,
                  border: Border.all(color: picked.contains(k) ? kBlue : kLine),
                ),
                child: Text(k, style: TextStyle(fontSize: 13.5, color: picked.contains(k) ? kBlue : kInk, fontWeight: FontWeight.w500)),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        Field('바른 정보', text, hint: '예) 전화번호는 032-000-0000 이에요', lines: 3, max: 300),
        Field('연락처 (선택)', contact, hint: '확인이 필요할 때만 연락드려요', max: 60),
      ],
    );
  }
}

// ---------------- 사장님 직접 등록 ----------------

class OwnerForm extends StatefulWidget {
  final Area? area;
  final Shop? shop;
  final Cat? cat;
  const OwnerForm({super.key, this.area, this.shop, this.cat});
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
  late String cat = widget.cat?.id ?? (widget.shop?.cats.firstOrNull ?? '');
  bool sending = false;

  Future<void> _send() async {
    if (name.text.trim().isEmpty || tel.text.trim().isEmpty || addr.text.trim().isEmpty || cat.isEmpty) {
      return toast(context, '가게 이름·분야·전화·주소는 꼭 적어 주세요');
    }
    if (contact.text.trim().isEmpty) return toast(context, '확인 연락을 받을 번호를 적어 주세요');
    setState(() => sending = true);
    final ok = await sendRequest({
      'kind': 'owner',
      'sid': widget.shop?.id ?? '',
      'sname': name.text.trim(),
      'area': widget.area?.id ?? '',
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
    if (ok) {
      toast(context, '등록 신청을 받았어요. 확인 전화를 드린 뒤 올려 드릴게요');
      Navigator.pop(context);
    } else {
      toast(context, '보내지 못했어요. 잠시 뒤 다시 해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.shop == null ? '우리 가게 등록' : '사장님 정보 등록',
      lead: widget.shop == null
          ? '인터넷에 아직 없는 동네 가게도 이웃이 찾을 수 있게 올려 드려요.\n등록은 무료예요.'
          : '영업시간·소개를 직접 적어 주시면 가게 화면에 함께 보여 드려요.\n등록은 무료예요.',
      button: '등록 신청하기',
      sending: sending,
      onSend: _send,
      children: [
        Field('가게 이름', name, need: true, max: 40),
        const Text.rich(TextSpan(children: [TextSpan(text: '분야'), TextSpan(text: ' *', style: TextStyle(color: kBlue))]),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in kCats)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => cat = c.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: cat == c.id ? const Color(0xFFEEF3FF) : Colors.white,
                  border: Border.all(color: cat == c.id ? kBlue : kLine),
                ),
                child: Text(c.name, style: TextStyle(fontSize: 12.5, color: cat == c.id ? kBlue : kInk, fontWeight: FontWeight.w500)),
              ),
            ),
        ]),
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
}
