// 우편번호 찾기 · 영문 주소 · 저장 주소 (이 폴더는 택배·우편 담당 방만 고침)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'look.dart';

void _copy(BuildContext context, String text, String what) {
  Clipboard.setData(ClipboardData(text: text));
  toast(context, '$what 복사했어요');
}

Widget _smallCopy(VoidCallback f, [String t = '복사']) => InkWell(
      onTap: f,
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.fromLTRB(8, 2, 2, 2), child: Text(t, style: const TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600))),
    );

Widget _line() => Container(height: 1, color: kLine);

// 우리 단지 주소 (우편번호 자료 + 동·호 기억)
Future<Addr> complexAddr(Complex c) async {
  final z = await complexZip(c);
  return Addr(
    name: '우리 집',
    zip: z?[0] ?? '',
    road: (z != null && z[1].isNotEmpty) ? z[1] : c.addr,
    jibun: z?[2] ?? '',
    bname: (z != null && z[3].isNotEmpty) ? z[3] : c.name,
    dong: await prefGet('postcode.${c.id}.dong') ?? '',
    ho: await prefGet('postcode.${c.id}.ho') ?? '',
  );
}

// =====================================================================
// 우편번호 찾기
// =====================================================================
class ZipPage extends StatefulWidget {
  final Complex c;
  const ZipPage(this.c, {super.key});
  @override
  State<ZipPage> createState() => _ZipPageState();
}

class _ZipPageState extends State<ZipPage> {
  final dong = TextEditingController();
  final ho = TextEditingController();
  final q = TextEditingController();
  Addr? a;

  String get _k => 'postcode.${widget.c.id}';

  @override
  void initState() {
    super.initState();
    complexAddr(widget.c).then((v) {
      if (!mounted) return;
      setState(() {
        a = v;
        dong.text = v.dong;
        ho.text = v.ho;
      });
    });
  }

  @override
  void dispose() {
    dong.dispose();
    ho.dispose();
    q.dispose();
    super.dispose();
  }

  void _search([String? t]) => openUrl(postcodeUrl(q: t ?? q.text), inApp: true);

  Future<void> _saveMine() async {
    final v = a;
    if (v == null) return;
    final l = await loadAddrs();
    if (l.any((x) => x.road == v.road && x.dong == v.dong && x.ho == v.ho)) {
      if (mounted) toast(context, '이미 저장해 둔 주소예요');
      return;
    }
    l.insert(0, v);
    await saveAddrs(l);
    if (mounted) toast(context, '「우리 집」으로 저장했어요');
  }

  @override
  Widget build(BuildContext context) => PostPage(
        title: '우편번호 찾기',
        art: 'envelope',
        sub: '동·호까지 넣어 택배 주소를 한 번에 복사하세요',
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30), children: [
          if (a == null) const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 1.6))) else _complexCard(a!),
          const SizedBox(height: 22),
          const MixTitle('다른 주소', '우편번호 찾기', size: 14.5),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: q,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                style: const TextStyle(fontSize: 14),
                decoration: inputDeco('도로명, 건물명, 동 이름'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Btn('찾기', h: 44, onTap: _search)),
          ]),
          const SizedBox(height: 22),
          const MixTitle('주소 쓸 때', '알아 두면 좋아요', size: 14.5),
          const SizedBox(height: 8),
          Container(
            decoration: postBox(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(children: [
              _tip('우편번호는 다섯 자리', '2015년부터 다섯 자리 국가기초구역번호를 써요. 여섯 자리 옛 번호는 쓰지 않아요.'),
              _line(),
              _tip('택배는 동·호까지', '아파트는 동·호가 빠지면 반송되기 쉬워요. 위에서 만든 전체 주소를 그대로 붙여 넣으세요.'),
              _line(),
              _tip('해외직구는 칸별로', '「영문 주소」에서 Address1·City·State·ZIP 을 한 칸씩 복사할 수 있어요.'),
            ]),
          ),
        ]),
      );

  Widget _complexCard(Addr v) => Container(
        decoration: postBox(grad: kGlowYellow),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Pill('우리 단지', color: Color(0xFFB45309), bg: Color(0xFFFDE9CF)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title)),
          ]),
          const SizedBox(height: 12),
          if (v.zip.isEmpty)
            Row(children: [
              const Expanded(child: Text('우편번호를 아직 모으지 못한 단지예요', style: T.body)),
              _smallCopy(() => _search(v.road), '바로 확인'),
            ])
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(v.zip, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, color: kBlue, letterSpacing: 1.5, height: 1.0)),
              const SizedBox(width: 10),
              const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('우편번호', style: T.tiny)),
              const Spacer(),
              _smallCopy(() => _copy(context, v.zip, '우편번호를')),
            ]),
          const SizedBox(height: 10),
          _row('도로명', v.road),
          if (v.jibun.isNotEmpty) _row('지번', v.jibun),
          const SizedBox(height: 12),
          _line(),
          const SizedBox(height: 12),
          const Text('동·호를 넣으면 택배에 쓰는 전체 주소를 만들어 드려요', style: T.small),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _unit(dong, '동', 'dong', (s) => v.dong = s)),
            const SizedBox(width: 8),
            Expanded(child: _unit(ho, '호', 'ho', (s) => v.ho = s)),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1E4D0))),
            child: Text(v.fullKo, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Btn('전체 주소 복사', primary: true, h: 42, onTap: () => _copy(context, v.fullKo, '전체 주소를'))),
            const SizedBox(width: 10),
            Expanded(child: Btn('저장 주소에 담기', h: 42, onTap: _saveMine)),
          ]),
        ]),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 40, child: Text(k, style: const TextStyle(fontSize: 11.5, color: kMute, height: 1.5))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.4))),
          _smallCopy(() => _copy(context, v, '$k 주소를')),
        ]),
      );

  Widget _unit(TextEditingController t, String suffix, String key, void Function(String) set) => TextField(
        controller: t,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(fontSize: 14),
        onChanged: (s) {
          prefSet('$_k.$key', s.trim());
          setState(() => set(s.trim()));
        },
        decoration: inputDeco(suffix == '동' ? '예: 103' : '예: 1204').copyWith(suffixText: suffix, suffixStyle: const TextStyle(fontSize: 13, color: kSub)),
      );

  Widget _tip(String t, String d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: T.title),
          const SizedBox(height: 3),
          Text(d, style: T.small),
        ]),
      );
}

// =====================================================================
// 검색 화면에서 「니즈콕에 저장」 → 앱으로 돌아오면 이름 붙여 저장
// (검색 화면이 클립보드에 주소를 담아 두면, 돌아올 때 그걸 읽는다)
// =====================================================================
mixin _ClipCatch<W extends StatefulWidget> on State<W>, WidgetsBindingObserver {
  bool _asking = false;
  void onAddrSaved();

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) catchClip();
  }

  Future<void> catchClip() async {
    if (_asking) return;
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final a = Addr.fromClip(d?.text);
    if (a == null || !mounted) return;
    _asking = true;
    // 같은 주소를 두 번 묻지 않게, 클립보드는 한글 전체 주소로 바꿔 둔다 (그대로 붙여 넣기에도 쓸 수 있게)
    await Clipboard.setData(ClipboardData(text: a.fullKo));
    if (!mounted) return;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _NameSheet(a: a),
    );
    _asking = false;
    if (name == null || !mounted) return;
    a.name = name;
    final l = await loadAddrs();
    l.removeWhere((x) => x.name == a.name);
    l.insert(0, a);
    await saveAddrs(l);
    if (!mounted) return;
    toast(context, '「${a.name}」 저장했어요');
    onAddrSaved();
  }
}

class _NameSheet extends StatefulWidget {
  final Addr a;
  const _NameSheet({required this.a});
  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final name = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(kPad, 18, kPad, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const MixTitle('이 주소', '저장하기', size: 16),
          const SizedBox(height: 6),
          Text(widget.a.fullKo, style: T.small),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in const ['우리 집', '부모님 댁', '회사', '처가', '시댁'])
              InkWell(
                onTap: () => setState(() => name.text = t),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
                  child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: name, maxLength: 14, style: const TextStyle(fontSize: 14), decoration: inputDeco('이름 붙이기 · 예: 부모님 댁')),
          const SizedBox(height: 10),
          Btn('저장', primary: true, onTap: () {
            final t = name.text.trim();
            Navigator.pop(context, t.isEmpty ? '저장한 주소' : t);
          }),
        ]),
      );
}

// 주소 하나를 칸별로 (영문 주소 화면 · 저장 주소 화면 공용)
class _EngBlock extends StatelessWidget {
  final Addr a;
  const _EngBlock(this.a);
  @override
  Widget build(BuildContext context) {
    final e = a.en;
    if (!e.ok) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('영문 주소가 없는 주소예요. 다시 찾아 저장하면 생겨요.', style: T.small));
    }
    Widget r(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 74, child: Text(k, style: const TextStyle(fontSize: 11, color: kMute, height: 1.5))),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 13, height: 1.4))),
            if (v.isNotEmpty) _smallCopy(() => _copy(context, v, '$k 칸을')),
          ]),
        );
    return Column(children: [
      r('Address 1', e.a1),
      r('Address 2', e.a2),
      r('City', e.city),
      r('State', e.state),
      r('ZIP', e.zip),
      r('Country', EngParts.country),
    ]);
  }
}

// =====================================================================
// 영문 주소
// =====================================================================
class EngPage extends StatefulWidget {
  final Complex c;
  const EngPage(this.c, {super.key});
  @override
  State<EngPage> createState() => _EngPageState();
}

class _EngPageState extends State<EngPage> with WidgetsBindingObserver, _ClipCatch<EngPage> {
  List<Addr> list = [];
  final q = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l = await loadAddrs();
    if (mounted) setState(() => list = l.where((a) => a.eng.isNotEmpty).toList());
  }

  @override
  void onAddrSaved() => _load();

  Future<void> _mine() async {
    final a = await complexAddr(widget.c);
    openUrl(postcodeUrl(q: a.road, save: true), inApp: true);
  }

  @override
  Widget build(BuildContext context) => PostPage(
        title: '영문 주소',
        art: 'globe',
        sub: '해외직구 주소 칸에 하나씩 붙여 넣으세요',
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30), children: [
          Container(
            decoration: postBox(grad: kGlowBlue),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MixTitle('해외직구', '영문 주소', size: 16),
              const SizedBox(height: 6),
              const Text('주소를 찾아 고르면 영문 주소가 나오고, 「니즈콕에 저장」을 누른 뒤 돌아오면 Address1·City·State·ZIP 을 한 칸씩 복사할 수 있어요.', style: T.small),
              const SizedBox(height: 12),
              Btn('우리 단지 영문 주소 찾기', primary: true, h: 42, onTap: _mine),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: q,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => openUrl(postcodeUrl(q: q.text, save: true), inApp: true),
                    style: const TextStyle(fontSize: 14),
                    decoration: inputDeco('다른 주소 · 도로명, 건물명'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 70, child: Btn('찾기', h: 44, onTap: () => openUrl(postcodeUrl(q: q.text, save: true), inApp: true))),
              ]),
            ]),
          ),
          for (final a in list) ...[
            const SizedBox(height: 12),
            Container(
              decoration: postBox(),
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(a.name.isEmpty ? a.road : a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title)),
                  _smallCopy(() => _copy(context, a.en.oneLine, '영문 주소 한 줄을'), '한 줄 복사'),
                ]),
                const SizedBox(height: 2),
                Text(a.fullKo, style: T.tiny),
                const SizedBox(height: 8),
                _line(),
                const SizedBox(height: 4),
                _EngBlock(a),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          const Text('영문 주소는 도로명주소 영문 표기를 따라요. 쇼핑몰마다 칸 이름이 조금씩 달라요 (Province = State, Postal code = ZIP).', style: T.tiny),
        ]),
      );
}

// =====================================================================
// 저장 주소
// =====================================================================
class SavedPage extends StatefulWidget {
  final Complex c;
  const SavedPage(this.c, {super.key});
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> with WidgetsBindingObserver, _ClipCatch<SavedPage> {
  List<Addr>? list;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final l = await loadAddrs();
    if (mounted) setState(() => list = l);
  }

  @override
  void onAddrSaved() => _load();

  Future<void> _remove(Addr a) async {
    final l = list ?? [];
    setState(() => l.remove(a));
    await saveAddrs(l);
  }

  Future<void> _addMine() async {
    final a = await complexAddr(widget.c);
    final l = list ?? [];
    if (l.any((x) => x.road == a.road && x.dong == a.dong && x.ho == a.ho)) {
      if (mounted) toast(context, '이미 저장해 둔 주소예요');
      return;
    }
    l.insert(0, a);
    await saveAddrs(l);
    _load();
    if (mounted) toast(context, '「우리 집」으로 저장했어요');
  }

  @override
  Widget build(BuildContext context) {
    final l = list;
    return PostPage(
      title: '저장 주소',
      art: 'housestar',
      sub: '누르면 우편번호와 주소가 한 번에 복사돼요',
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30), children: [
        Row(children: [
          Expanded(child: Btn('주소 찾아서 저장', primary: true, h: 44, onTap: () => openUrl(postcodeUrl(save: true), inApp: true))),
          const SizedBox(width: 10),
          Expanded(child: Btn('우리 단지 저장', h: 44, onTap: _addMine)),
        ]),
        const SizedBox(height: 14),
        if (l == null)
          const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 1.6)))
        else if (l.isEmpty)
          Container(
            decoration: postBox(grad: kGlowMint),
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(children: [
              postArt('housestar', 60),
              const SizedBox(height: 10),
              const Text('아직 저장한 주소가 없어요', style: T.title),
              const SizedBox(height: 4),
              const Text('부모님 댁, 회사처럼 자주 보내는 주소를 담아 두세요', style: T.small, textAlign: TextAlign.center),
            ]),
          )
        else
          Container(
            decoration: postBox(),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(children: [
              for (var i = 0; i < l.length; i++) ...[
                if (i > 0) _line(),
                _item(l[i]),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _item(Addr a) => InkWell(
        onTap: () => _copy(context, a.fullKo, '「${a.name}」 주소를'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(a.name.isEmpty ? '저장한 주소' : a.name, style: T.title)),
              if (a.zip.isNotEmpty) Text(a.zip, style: const TextStyle(fontSize: 12.5, color: kSub, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 3),
            Text(a.fullKo, style: const TextStyle(fontSize: 12.5, height: 1.4)),
            if (a.eng.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(a.en.oneLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
            ],
            const SizedBox(height: 6),
            Row(children: [
              _smallCopy(() => _copy(context, a.fullKo, '한글 주소를'), '한글 복사'),
              if (a.eng.isNotEmpty) _smallCopy(() => _copy(context, a.en.oneLine, '영문 주소를'), '영문 복사'),
              const Spacer(),
              _smallCopy(() => _remove(a), '삭제'),
            ]),
          ]),
        ),
      );
}
