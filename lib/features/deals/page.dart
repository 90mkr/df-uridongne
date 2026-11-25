// 실거래가 상세 화면 (실거래가 방만 고침)
// 평형 고르기 → 매매 / 전월세 → 1년 흐름 → 거래 목록 → 같은 동네 다른 단지 비교
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'chart.dart';
import 'data.dart';
import 'info.dart';

class DealsPage extends StatefulWidget {
  final Complex c;
  final Matched? preset;
  final DealApt? other; // 옆 단지를 눌러 들어온 경우
  final SggDeals? all;
  const DealsPage({super.key, required this.c, this.preset, this.other, this.all});
  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> {
  Matched? m;
  SggDeals? all; // 못 찾았을 때 시군구 인기 단지 보여 주기
  bool loading = true;
  int mode = 0; // 0 매매 · 1 전월세
  int area = -1;
  AptInfo? info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Matched? mm;
    if (widget.other != null && widget.all != null) {
      mm = matchIn(widget.all!, name: widget.other!.name, addr: '${widget.other!.umd} ${widget.other!.jibun}');
    } else {
      mm = widget.preset ?? await matchComplex(widget.c);
    }
    final sg = sggOf(widget.c);
    final al = mm?.all ?? widget.all ?? (sg == null ? null : await loadSgg(sg));
    if (!mounted) return;
    setState(() {
      all = al;
      m = mm;
      loading = false;
      if (mm != null) {
        area = topArea(mm.apt);
        if (mm.apt.sales.isEmpty && mm.apt.rents.isNotEmpty) mode = 1;
      }
    });
    final k = widget.other != null ? (mm?.apt.kapt ?? '') : kaptOf(widget.c, mm);
    if (widget.other != null && k.isNotEmpty) {
      final inf = await aptInfo(k);
      if (mounted) setState(() => info = inf);
    }
  }

  List<int> get _months {
    final now = DateTime.now();
    return [
      for (var i = 12; i >= 0; i--)
        () {
          final d = DateTime(now.year, now.month - i);
          return d.year * 100 + d.month;
        }()
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mm = m;
    return DetailPage(
      title: widget.other != null ? widget.other!.name : '우리 단지 최근 거래',
      icon: 'deals',
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : mm == null
              ? _empty(all)
              : ListView(padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 32), children: _body(mm)),
    );
  }

  Widget _empty(SggDeals? al) {
    final top = [...?al?.apts.where((a) => a.sales.isNotEmpty)]..sort((a, b) => b.sales.length.compareTo(a.sales.length));
    return ListView(padding: const EdgeInsets.fromLTRB(kPad, 26, kPad, 30), children: [
      const Text('이 단지의 최근 1년 거래를 찾지 못했어요', style: T.h2, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(
          sggOf(widget.c) == null || al == null
              ? '이 동네 실거래 자료를 아직 모으지 못했어요. 곧 채워 넣을게요.'
              : '단지 이름이 국토교통부 자료와 달라 못 찾았거나, 1년 동안 거래가 없었을 수 있어요. 실거래 신고는 계약 후 30일 안에 올라와요.',
          textAlign: TextAlign.center,
          style: T.small),
      if (top.isNotEmpty) ...[
        const SizedBox(height: 26),
        const MixTitle('우리 동네', '거래 많은 단지', size: 15),
        const SizedBox(height: 3),
        const Text('최근 1년 매매 건수 순', style: T.tiny),
        const SizedBox(height: 8),
        for (final o in top.take(12)) _aptRow(o, o.sales.first, al!),
      ],
    ]);
  }

  Widget _aptRow(DealApt o, Sale b, SggDeals al) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DealsPage(c: widget.c, other: o, all: al))),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F4)))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                const SizedBox(height: 1),
                Text('${o.umd}${o.built > 0 ? ' · ${o.built}년' : ''} · ${sqm(b.area)} · ${b.floor}층 · ${monthText(b.ymd)}', style: T.tiny),
              ]),
            ),
            Text(won(b.price), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: kMute),
          ]),
        ),
      );

  List<Widget> _body(Matched mm) {
    final a = mm.apt;
    final areas = <int, int>{};
    for (final s in a.sales) {
      areas[areaGroup(s.area)] = (areas[areaGroup(s.area)] ?? 0) + 1;
    }
    for (final r in a.rents) {
      areas[areaGroup(r.area)] = (areas[areaGroup(r.area)] ?? 0) + 1;
    }
    final keys = areas.keys.toList()..sort();
    final sales = a.sales.where((s) => areaGroup(s.area) == area).toList();
    final rents = a.rents.where((r) => areaGroup(r.area) == area).toList();
    final sub = [
      if (a.built > 0) '${a.built}년 준공',
      '${a.umd} ${a.jibun}',
      if (a.officetel) '오피스텔',
    ].join(' · ');
    return [
      // 머리: 실거래 자료의 단지 이름
      MixTitle(a.umd, a.name, size: 18),
      const SizedBox(height: 3),
      Text(sub, style: T.tiny),
      if (widget.other != null && info != null) ...[const SizedBox(height: 12), AptInfoCard(info: info, built: a.built)],
      const SizedBox(height: 16),
      // 평형 (휴대폰에서 줄바꿈 대신 옆으로 밀기)
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final k in keys) ...[
            ChoiceChipBox('$k㎡ · ${pyeong(k.toDouble())}', on: k == area, onTap: () => setState(() => area = k)),
            const SizedBox(width: 6),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      _tabs(sales.length, rents.length),
      const SizedBox(height: 14),
      if (mode == 0) ..._saleView(sales) else ..._rentView(rents),
      if (mm.sameUmd.isNotEmpty) ...[
        const SizedBox(height: 26),
        MixTitle('같은 동네', '다른 단지', size: 15),
        const SizedBox(height: 3),
        Text('${a.umd} · 최근 매매 (비슷한 평형)', style: T.tiny),
        const SizedBox(height: 8),
        _neighbors(mm),
      ],
      const SizedBox(height: 22),
      Text('국토교통부 실거래가 공개시스템 · 계약일 기준 · 계약 후 30일 안에 신고되어 최근 거래는 늦게 보일 수 있어요. 해제된 거래는 뺐어요.${mm.all.updated.isNotEmpty ? ' (${mm.all.updated} 기준)' : ''}',
          style: T.tiny),
    ];
  }

  Widget _tabs(int ns, int nr) {
    Widget tab(int i, String t, int n) => Expanded(
          child: InkWell(
            onTap: () => setState(() => mode = i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: mode == i ? kInk : kLine, width: 1))),
              alignment: Alignment.center,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: t, style: TextStyle(fontWeight: mode == i ? FontWeight.w800 : FontWeight.w500)),
                TextSpan(text: ' $n', style: const TextStyle(color: kMute, fontWeight: FontWeight.w400)),
              ]), style: TextStyle(fontSize: 14, color: mode == i ? kInk : kSub)),
            ),
          ),
        );
    return Row(children: [tab(0, '매매', ns), tab(1, '전월세', nr)]);
  }

  Widget _stat(String label, String v, {bool hot = false}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: T.tiny),
          const SizedBox(height: 2),
          Text(v, style: TextStyle(fontSize: hot ? 18 : 14.5, fontWeight: hot ? FontWeight.w800 : FontWeight.w600, color: kInk, letterSpacing: -0.5)),
        ]),
      );

  List<Widget> _saleView(List<Sale> sales) {
    if (sales.isEmpty) return [const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('이 평형은 최근 1년 매매가 없어요', textAlign: TextAlign.center, style: T.small))];
    final prices = sales.map((s) => s.price).toList();
    final hi = prices.reduce((a, b) => a > b ? a : b), lo = prices.reduce((a, b) => a < b ? a : b);
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _stat('최근 거래 · ${ymdText(sales.first.ymd)}', won(sales.first.price), hot: true),
        _stat('1년 최고', won(hi)),
        _stat('1년 최저', won(lo)),
      ]),
      const SizedBox(height: 14),
      FlowChart(sales: sales, months: _months),
      const SizedBox(height: 14),
      for (final s in sales.take(40)) _row(ymdText(s.ymd), '${s.floor}층', won(s.price)),
      if (sales.length > 40) Padding(padding: const EdgeInsets.only(top: 8), child: Text('그 밖에 ${sales.length - 40}건', style: T.tiny)),
    ];
  }

  List<Widget> _rentView(List<Rent> rents) {
    if (rents.isEmpty) return [const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('이 평형은 최근 전월세 신고가 없어요', textAlign: TextAlign.center, style: T.small))];
    final js = rents.where((r) => r.jeonse).toList();
    final ws = rents.where((r) => !r.jeonse).toList();
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _stat('최근 전세', js.isEmpty ? '-' : won(js.first.deposit), hot: true),
        _stat('최근 월세', ws.isEmpty ? '-' : '${wonShort(ws.first.deposit)}/${ws.first.monthly}'),
        _stat('갱신 비율', '${(rents.where((r) => r.renew).length * 100 / rents.length).round()}%'),
      ]),
      if (js.length >= 2) ...[
        const SizedBox(height: 14),
        FlowChart(sales: [for (final r in js) Sale(r.ymd, r.area100, r.floor, r.deposit)], months: _months),
        const SizedBox(height: 2),
        const Text('전세 보증금 흐름', style: T.tiny),
      ],
      const SizedBox(height: 14),
      for (final r in rents.take(40)) _row(ymdText(r.ymd), '${r.floor}층', rentText(r), tag: r.renew ? '갱신' : '신규'),
    ];
  }

  Widget _row(String date, String floor, String price, {String? tag}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F4)))),
        child: Row(children: [
          SizedBox(width: 74, child: Text(date, style: const TextStyle(fontSize: 12.5, color: kSub))),
          SizedBox(width: 40, child: Text(floor, style: const TextStyle(fontSize: 12.5, color: kSub))),
          if (tag != null) ...[Pill(tag), const SizedBox(width: 6)],
          Expanded(child: Text(price, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
        ]),
      );

  Widget _neighbors(Matched mm) {
    final rows = <Widget>[];
    for (final o in mm.sameUmd.take(8)) {
      // 고른 평형과 가장 가까운 평형의 최근 매매
      Sale? best;
      for (final s in o.sales) {
        if (best == null || (areaGroup(s.area) - area).abs() < (areaGroup(best.area) - area).abs()) best = s;
      }
      if (best == null) continue;
      rows.add(_aptRow(o, best, mm.all));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
