// 「단지 정보」 화면에 들어가는 카드 두 장 (실거래가 방만 고침)
//  ① 우리 단지 정보: 세대수 · 동 수 · 최고 층 · 입주 · 난방 · 분양/임대 · 관리 · 주차 · 관리사무소 전화 (K-apt)
//  ② 우리 단지 최근 거래: 가장 많이 거래된 평형의 최근 매매가 + 1년 흐름선 + 전월세 한 줄
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'chart.dart';
import 'data.dart';
import 'page.dart';

class DealsInfoCards extends StatefulWidget {
  final Complex c;
  final Feature f;
  const DealsInfoCards({super.key, required this.c, required this.f});
  @override
  State<DealsInfoCards> createState() => _DealsInfoCardsState();
}

class _DealsInfoCardsState extends State<DealsInfoCards> {
  Matched? m;
  AptInfo? info;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mm = await matchComplex(widget.c);
    if (!mounted) return;
    setState(() => m = mm);
    final k = kaptOf(widget.c, mm);
    final inf = k.isEmpty ? null : await aptInfo(k);
    if (!mounted) return;
    setState(() {
      info = inf;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      AptInfoCard(info: info, built: m?.apt.built ?? 0, loading: loading),
      const SizedBox(height: 12),
      HomeCardBox(
        icon: 'deals',
        title: '우리 단지 최근 거래',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DealsPage(c: widget.c, preset: m))),
        child: _summary(),
      ),
    ]);
  }

  Widget _summary() {
    final mm = m;
    if (mm == null) {
      return Text(loading ? '거래 자료를 찾고 있어요…' : '아직 이 단지의 최근 거래를 찾지 못했어요.\n눌러서 동네 다른 단지 거래를 볼 수 있어요.', style: T.small);
    }
    final a = mm.apt;
    final top = topArea(a);
    final ss = a.sales.where((s) => areaGroup(s.area) == top).toList();
    final last = ss.isNotEmpty ? ss.first : (a.sales.isNotEmpty ? a.sales.first : null);
    final rent = a.rents.where((r) => areaGroup(r.area) == top).firstOrNull ?? a.rents.firstOrNull;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (last != null) ...[
            Text.rich(TextSpan(children: [
              TextSpan(text: '${sqm(last.area)} ', style: const TextStyle(fontWeight: FontWeight.w400, color: kSub)),
              TextSpan(text: won(last.price), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]), style: const TextStyle(fontSize: 19, letterSpacing: -0.6, height: 1.2)),
            const SizedBox(height: 3),
            Text('${ymdText(last.ymd)} 계약 · ${last.floor}층 · ${pyeong(last.area)}', style: T.tiny),
          ] else
            const Text('최근 1년 매매가 없어요', style: T.small),
          if (rent != null) ...[
            const SizedBox(height: 6),
            Text('${rentText(rent)} · ${monthText(rent.ymd)}${rent.renew ? ' 갱신' : ''}', style: const TextStyle(fontSize: 12, color: kInk, height: 1.3)),
          ],
        ]),
      ),
      if (ss.length >= 2) SizedBox(width: 92, height: 40, child: Spark(sales: ss)),
    ]);
  }
}

// 가장 많이 거래된 평형 (전용 ㎡ 정수)
int topArea(DealApt a) {
  final cnt = <int, int>{};
  for (final s in a.sales) {
    cnt[areaGroup(s.area)] = (cnt[areaGroup(s.area)] ?? 0) + 2;
  }
  for (final r in a.rents) {
    cnt[areaGroup(r.area)] = (cnt[areaGroup(r.area)] ?? 0) + 1;
  }
  if (cnt.isEmpty) return 0;
  return (cnt.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).first.key;
}

// ① 단지 정보 카드
class AptInfoCard extends StatelessWidget {
  final AptInfo? info;
  final int built;
  final bool loading;
  const AptInfoCard({super.key, required this.info, this.built = 0, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final i = info;
    final cells = <(String, String)>[];
    String? tel;
    if (i != null) {
      final hh = i.n('kaptdaCnt');
      if (hh > 0) cells.add(('세대', '${_comma(hh)}세대'));
      final dong = i.n('kaptDongCnt');
      if (dong > 0) cells.add(('동 수', '$dong개 동'));
      final top = i.n('kaptTopFloor') > 0 ? i.n('kaptTopFloor') : i.n('ktownFlrNo');
      if (top > 0) cells.add(('최고 층', '$top층'));
      final use = i.s('kaptUsedate');
      if (use.length >= 4) cells.add(('입주', '${use.substring(0, 4)}년${use.length >= 6 ? ' ${int.tryParse(use.substring(4, 6)) ?? ''}월' : ''}'));
      final heat = i.s('codeHeatNm');
      if (heat.isNotEmpty) cells.add(('난방', heat));
      final sale = i.s('codeSaleNm');
      if (sale.isNotEmpty) cells.add(('분양·임대', sale));
      final mgr = i.s('codeMgrNm');
      if (mgr.isNotEmpty) cells.add(('관리', mgr));
      final park = i.n('kaptdPcnt') + i.n('kaptdPcntu');
      if (park > 0) cells.add(('주차', '${_comma(park)}대${hh > 0 ? ' (세대당 ${(park / hh).toStringAsFixed(1)})' : ''}'));
      final ev = i.n('kaptdEcnt');
      if (ev > 0) cells.add(('승강기', '$ev대'));
      final bc = i.s('kaptBcompany');
      if (bc.isNotEmpty) cells.add(('시공', bc));
      tel = i.s('kaptTel');
    } else if (built > 0) {
      cells.add(('준공', '$built년'));
    }
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const Row(children: [
          LineIcon('apt', size: 24),
          SizedBox(width: 7),
          MixTitle('우리 단지', '정보', size: 14.5),
        ]),
        const SizedBox(height: 10),
        if (cells.isEmpty)
          Text(loading ? '단지 정보를 불러오고 있어요…' : '공동주택관리정보시스템(K-apt)에 등록된 정보를 찾지 못했어요.', style: T.small)
        else
          LayoutBuilder(builder: (ctx, bc) {
            final cols = bc.maxWidth > 460 ? 4 : 3;
            final w = (bc.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(spacing: 8, runSpacing: 10, children: [
              for (final c in cells)
                SizedBox(
                  width: w,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(c.$1, style: T.tiny),
                    const SizedBox(height: 1),
                    Text(c.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.3)),
                  ]),
                ),
            ]);
          }),
        if (tel != null && tel.replaceAll(RegExp(r'[^0-9]'), '').length >= 7) ...[
          const SizedBox(height: 12),
          Btn('관리사무소 전화  $tel', h: 40, onTap: () => callTel(tel!)),
        ],
      ]),
    );
  }
}

String _comma(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
