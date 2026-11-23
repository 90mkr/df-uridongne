// 단지 고르기 (본부 방만 고침)
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'icons.dart';
import 'kk.dart';
import 'theme.dart';
import 'ui.dart';

Future<Complex?> pickComplex(BuildContext context, {bool first = false}) =>
    Navigator.of(context).push<Complex>(MaterialPageRoute(builder: (_) => ComplexPickPage(first: first)));

class ComplexPickPage extends StatefulWidget {
  final bool first;
  const ComplexPickPage({super.key, this.first = false});
  @override
  State<ComplexPickPage> createState() => _ComplexPickPageState();
}

class _ComplexPickPageState extends State<ComplexPickPage> {
  final q = TextEditingController();
  Area? area;
  List<Complex> apts = [];
  bool loading = true;
  LatLng? from;
  LatLng? liveAt; // 준비된 동네가 아닌 곳: 이 자리 둘레를 카카오에서 바로 찾음
  bool liveSearch = false; // 전국 이름 찾기 결과를 보여 주는 중

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await loadAreas();
    final c = complex.value;
    from = c?.pos ?? myPos.value;
    if (c != null && c.area == null) {
      liveAt = c.pos;
    } else {
      area = c?.area ?? areas.where((a) => a.ready).firstOrNull;
    }
    await _load();
  }

  Future<void> _load() async {
    final a = area;
    final at = liveAt ?? (a != null && !a.ready ? a.center : null);
    if (a == null && at == null) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      liveSearch = false;
    });
    final list = at != null ? await kkComplexes(near: at) : await complexesOf(a!);
    if (!mounted || area?.id != a?.id) return;
    setState(() {
      apts = list;
      loading = false;
    });
  }

  Future<void> _near() async {
    final p = await myLocation();
    if (!mounted) return;
    if (p == null) return toast(context, '위치를 알 수 없어요. 휴대폰 위치 사용을 켜 주세요');
    final a = areaAt(p);
    setState(() {
      from = p;
      q.clear();
      if (a != null && a.ready && a.contains(p)) {
        area = a;
        liveAt = null;
      } else {
        area = null;
        liveAt = p; // 전국 어디든: 내 둘레 단지를 바로 찾기
      }
    });
    await _load();
  }

  // 전국에서 이름으로 찾기
  Future<void> _searchAll() async {
    final t = q.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    final list = await kkComplexes(q: t, near: from);
    if (!mounted) return;
    setState(() {
      apts = list;
      liveSearch = true;
      loading = false;
    });
    if (list.isEmpty) toast(context, '「$t」 단지를 찾지 못했어요');
  }

  List<Complex> get shown {
    // 띄어쓰기·앞의 「인천」·뒤의 「아파트」와 상관없이 찾기
    String norm(String s) => s.replaceAll(' ', '').replaceAll('인천', '').replaceAll('아파트', '').toLowerCase();
    final t = norm(q.text);
    if (liveSearch) return apts;
    var l = t.isEmpty ? apts : apts.where((c) => norm('${c.name}${c.addr}').contains(t)).toList();
    final f = from;
    if (f != null && area != null && meters(f, area!.center) < 20000) {
      l = [...l]..sort((a, b) => meters(f, a.pos).compareTo(meters(f, b.pos)));
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final list = shown;
    return DetailPage(
      title: '우리 단지 고르기',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.first) ...[
              const MixTitle('사는 단지를', '골라 주세요', size: 19),
              const SizedBox(height: 4),
              const Text('단지 기준으로 쓰레기 배출일·버스·약국·동네 가게를 모아 보여 드려요', style: T.small),
              const SizedBox(height: 14),
            ],
            TextField(controller: q, onChanged: (_) => setState(() => liveSearch = false), onSubmitted: (_) => _searchAll(), textInputAction: TextInputAction.search, style: const TextStyle(fontSize: 14.5), decoration: inputDeco('단지 이름으로 찾기 (전국)')),
            const SizedBox(height: 10),
            Row(children: [
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: _near,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: kLine), color: Colors.white),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    LineIcon('loc', size: 17),
                    SizedBox(width: 5),
                    Text('내 위치 근처 단지', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _pickArea,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(children: [
                    Text(area == null ? (liveAt != null ? '내 위치 둘레' : '동네 고르기') : '${area!.sido} ${area!.name}', style: const TextStyle(fontSize: 13, color: kSub)),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kSub),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1.6, color: kBlue))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 30),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFF1F4)),
                  itemBuilder: (_, i) {
                    if (i == list.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(children: [
                          Text(list.isEmpty ? '찾는 단지가 없어요' : '목록에 없나요?', style: T.small),
                          const SizedBox(height: 8),
                          if (q.text.trim().isNotEmpty && !liveSearch) ...[
                            SizedBox(width: 220, child: Btn('전국에서 「${q.text.trim()}」 찾기', icon: 'search', primary: true, onTap: _searchAll)),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(width: 220, child: Btn('내 위치로 직접 넣기', icon: 'loc', onTap: _manual)),
                        ]),
                      );
                    }
                    final c = list[i];
                    final d = from != null ? meters(from!, c.pos) : null;
                    return InkWell(
                      onTap: () => _done(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          const LineIcon('apt', size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3)),
                              Text([if (d != null && d < 20000) distText(d), c.addr].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
                            ]),
                          ),
                          if (complex.value?.id == c.id) const Pill('지금 단지', color: kBlue, bg: Color(0xFFEEF3FF)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Future<void> _pickArea() async {
    final a = await showSheet<Area>(
      context,
      (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 20), children: [
        const Text('동네 고르기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        for (final sido in {for (final a in areas) a.sido}) ...[
          Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Text(sido, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kMute))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in areas.where((x) => x.sido == sido))
              ChoiceChipBox(a.name, on: a.id == area?.id, onTap: () => Navigator.pop(ctx, a)),
          ]),
        ],
      ]),
    );
    if (a == null) return;
    setState(() {
      area = a;
      liveAt = null;
      from = a.ready ? myPos.value : a.center;
    });
    await _load();
  }

  Future<void> _manual() async {
    final p = await myLocation();
    if (!mounted) return;
    if (p == null) return toast(context, '위치를 알 수 없어요');
    final name = TextEditingController();
    final ok = await showSheet<bool>(
      context,
      (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(kPad, 16, kPad, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('지금 있는 곳을 우리 단지로', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Field('단지 이름', name, hint: '예) 송도 ○○아파트', max: 30),
          Btn('이 위치로 정하기', primary: true, onTap: () => Navigator.pop(ctx, true)),
        ]),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    _done(Complex(id: 'my_${DateTime.now().millisecondsSinceEpoch}', name: name.text.trim(), addr: '', areaId: areaIdAt(p), lat: p.latitude, lng: p.longitude));
  }

  void _done(Complex c) {
    setComplex(c);
    Navigator.pop(context, c);
  }
}
