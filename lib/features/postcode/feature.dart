// 우편번호 찾기 (이 폴더는 우편번호 담당 방만 고침)
// - 우리 단지 우편번호: 자동 제작이 미리 모은 web/data/postcode/<동네>.json
// - 동·호를 넣으면 택배용 전체 주소를 바로 복사
// - 다른 주소·영문 주소는 카카오(다음) 우편번호 화면(web/postcode.html)으로 — 열쇠값 필요 없음
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class PostcodeFeature extends Feature {
  @override
  String get id => 'postcode';
  @override
  String get name => '우편번호';
  @override
  String get icon => 'post';
  @override
  Slot get slot => Slot.tool;
  @override
  int get order => 40;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftYellow;

  static String searchUrl([String q = '']) {
    final base = kIsWeb && Uri.base.host.endsWith('github.io') ? 'postcode.html' : '${kSiteUrl}postcode.html';
    return q.trim().isEmpty ? base : '$base?q=${Uri.encodeQueryComponent(q.trim())}';
  }

  @override
  Widget page(BuildContext context, Complex c) => _PostcodePage(c);
}

// 우리 단지 우편번호 자료 (동네별로 한 번만 받음)
final Map<String, Map<String, dynamic>> _zips = {};

Future<List<String>?> _complexZip(Complex c) async {
  if (c.areaId.isEmpty) return null;
  var m = _zips[c.areaId];
  if (m == null) {
    final j = await getJson('${dataBase}postcode/${c.areaId}.json');
    m = j is Map && j['z'] is Map ? Map<String, dynamic>.from(j['z'] as Map) : <String, dynamic>{};
    _zips[c.areaId] = m;
  }
  final v = m[c.id];
  if (v is List && v.isNotEmpty && '${v[0]}'.isNotEmpty) return [for (final x in v) '$x'];
  return null;
}

class _PostcodePage extends StatefulWidget {
  final Complex c;
  const _PostcodePage(this.c);
  @override
  State<_PostcodePage> createState() => _PostcodePageState();
}

class _PostcodePageState extends State<_PostcodePage> {
  final dong = TextEditingController();
  final ho = TextEditingController();
  final q = TextEditingController();
  List<String>? zip; // [우편번호, 도로명, 지번, 건물 이름]
  bool loading = true;

  String get _k => 'postcode.${widget.c.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _complexZip(widget.c);
    final d = await prefGet('$_k.dong') ?? '';
    final h = await prefGet('$_k.ho') ?? '';
    if (!mounted) return;
    setState(() {
      zip = r;
      dong.text = d;
      ho.text = h;
      loading = false;
    });
  }

  @override
  void dispose() {
    dong.dispose();
    ho.dispose();
    q.dispose();
    super.dispose();
  }

  String get _road => (zip != null && zip![1].isNotEmpty) ? zip![1] : widget.c.addr;

  // 「103동 1204호」
  String get _unit {
    final d = dong.text.trim(), h = ho.text.trim();
    return [if (d.isNotEmpty) '$d동', if (h.isNotEmpty) '$h호'].join(' ');
  }

  // 택배에 쓰는 전체 주소: 도로명, 동·호 (건물 이름)
  String get _full {
    final b = (zip != null && zip![3].isNotEmpty) ? zip![3] : widget.c.name;
    final u = _unit;
    return '$_road${u.isEmpty ? '' : ', $u'} ($b)';
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    toast(context, '$what 복사했어요');
  }

  void _search([String? text]) {
    final t = (text ?? q.text).trim();
    openUrl(PostcodeFeature.searchUrl(t), inApp: true);
  }

  @override
  Widget build(BuildContext context) => DetailPage(
        title: '우편번호 찾기',
        icon: 'post',
        white: false,
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 18, kPad, 30), children: [
          _complexCard(),
          const SizedBox(height: 22),
          const MixTitle('다른 주소', '우편번호 찾기', size: 14.5),
          const SizedBox(height: 8),
          _searchRow(),
          const SizedBox(height: 22),
          const MixTitle('주소 쓸 때', '알아 두면 좋아요', size: 14.5),
          const SizedBox(height: 8),
          _tips(),
        ]),
      );

  // ---- 우리 단지 우편번호 ----
  Widget _complexCard() => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const LineIcon('post', size: 19, fill: kSoftYellow),
            const SizedBox(width: 6),
            Expanded(child: Text('우리 단지 · ${widget.c.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title)),
          ]),
          const SizedBox(height: 12),
          if (loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.6))))
          else ...[
            _zipLine(),
            const SizedBox(height: 10),
            _addrLine('도로명', _road),
            if (zip != null && zip![2].isNotEmpty) _addrLine('지번', zip![2]),
            const SizedBox(height: 12),
            Container(height: 1, color: kLine),
            const SizedBox(height: 12),
            const Text('동·호를 넣으면 택배에 쓰는 전체 주소를 만들어 드려요', style: T.small),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _unitField(dong, '동', 'dong')),
              const SizedBox(width: 8),
              Expanded(child: _unitField(ho, '호', 'ho')),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
              child: Text(
                zip == null ? _full : '(${zip![0]}) $_full',
                style: const TextStyle(fontSize: 13, height: 1.4, color: kInk),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Btn('전체 주소 복사', primary: true, h: 42, onTap: () => _copy(zip == null ? _full : '(${zip![0]}) $_full', '전체 주소를'))),
              const SizedBox(width: 8),
              Expanded(child: Btn('영문 주소 보기', h: 42, onTap: () => _search(_road))),
            ]),
          ],
        ]),
      );

  Widget _zipLine() {
    if (zip == null) {
      return Row(children: [
        const Expanded(child: Text('우편번호를 아직 모으지 못한 단지예요', style: T.body)),
        InkWell(
          onTap: () => _search(_road),
          child: const Padding(padding: EdgeInsets.all(4), child: Text('바로 확인', style: TextStyle(fontSize: 12.5, color: kBlue, fontWeight: FontWeight.w600))),
        ),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(zip![0], style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, color: kBlue, letterSpacing: 1.5, height: 1.0)),
      const SizedBox(width: 10),
      const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('우편번호', style: T.tiny)),
      const Spacer(),
      _smallCopy(() => _copy(zip![0], '우편번호를')),
    ]);
  }

  Widget _addrLine(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 40, child: Text(k, style: const TextStyle(fontSize: 11.5, color: kMute, height: 1.5))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.4))),
          _smallCopy(() => _copy(v, '$k 주소를')),
        ]),
      );

  Widget _smallCopy(VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(padding: EdgeInsets.fromLTRB(8, 2, 2, 2), child: Text('복사', style: TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600))),
      );

  Widget _unitField(TextEditingController t, String suffix, String key) => TextField(
        controller: t,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(fontSize: 14),
        onChanged: (v) {
          prefSet('$_k.$key', v.trim());
          setState(() {});
        },
        decoration: inputDeco(suffix == '동' ? '예: 103' : '예: 1204').copyWith(
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 13, color: kSub),
        ),
      );

  // ---- 다른 주소 찾기 ----
  Widget _searchRow() => Row(children: [
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
        SizedBox(width: 76, child: Btn('찾기', h: 44, onTap: _search)),
      ]);

  // ---- 안내 ----
  Widget _tips() => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          _tip('우편번호는 5자리', '2015년부터 다섯 자리 우편번호(국가기초구역번호)를 써요. 여섯 자리 옛 번호는 쓰지 않아요.'),
          Container(height: 1, color: kLine),
          _tip('택배는 동·호까지', '아파트는 동·호가 빠지면 반송되기 쉬워요. 위에서 만든 전체 주소를 그대로 붙여 넣으세요.'),
          Container(height: 1, color: kLine),
          _tip('해외직구 영문 주소', '「영문 주소 보기」에서 주소를 고르면 영문 주소와 우편번호를 함께 복사할 수 있어요.'),
        ]),
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
