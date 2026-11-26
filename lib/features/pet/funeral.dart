// 반려동물 장례·추모 — 반려동물 테마 방 (대표님 11-26, 껍데기 먼저)
// 자료: 행정안전부 동물장묘업 인허가(15155065) → collector 가 web/data/pet/funeral.json 으로
//   {"updated", "items": [{"name","addr","tel","y","x","kind"}]}  (kind: 장례식장·화장·납골 등)
// 활용신청 전에는 파일이 없어 「준비 중」. 맨 아래 온라인 추모관 배너는 서버 promo.json 의 memorial 로 연결 (대표님 별도 서비스)
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class PetFuneralPage extends StatefulWidget {
  final Complex complex;
  const PetFuneralPage({super.key, required this.complex});
  @override
  State<PetFuneralPage> createState() => _PetFuneralPageState();
}

class _PetFuneralPageState extends State<PetFuneralPage> {
  List<(Map, double)>? items;
  Map? memorial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Future.wait([getJson('${dataBase}pet/funeral.json'), getJson('${dataBase}pet/promo.json')]);
    final j = r[0], p = r[1];
    final here = widget.complex.pos;
    List<(Map, double)>? v;
    if (j is Map) {
      v = [
        for (final x in (j['items'] as List? ?? const []))
          if (x is Map && x['y'] is num && x['x'] is num) (x, meters(here, LatLng((x['y'] as num).toDouble(), (x['x'] as num).toDouble())))
      ]..sort((a, b) => a.$2.compareTo(b.$2));
    }
    if (!mounted) return;
    setState(() {
      items = v;
      memorial = p is Map && p['memorial'] is Map ? p['memorial'] as Map : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = items;
    return DetailPage(
      title: '장례·추모',
      icon: 'pet',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const MixTitle('무지개다리를 건넜을 때', '', size: 15.5),
            const SizedBox(height: 8),
            for (final s in const [
              '반려동물 사체는 동물장묘업 허가를 받은 곳에서 장례·화장할 수 있어요. 허가 없는 곳은 불법이에요.',
              '집 마당이나 산에 묻는 것은 법으로 금지돼 있어요.',
              '동물등록이 된 아이는 30일 안에 사망 신고를 해 주세요 (정부24·동물등록 대행 병원).',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 7), child: SizedBox(width: 4, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: kSub, shape: BoxShape.circle)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13, height: 1.45))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        const MixTitle('허가받은', ' 장례식장', size: 15),
        const SizedBox(height: 10),
        if (v == null)
          Container(
            decoration: cardBox(),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            child: Column(children: [
              const LineIcon('pet', size: 50),
              const SizedBox(height: 10),
              const Text('자료를 준비하고 있어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('행정안전부 동물장묘업 허가 자료로 가까운 곳부터 보여 드릴게요.', textAlign: TextAlign.center, style: T.small),
            ]),
          )
        else
          Container(
            decoration: cardBox(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (var i = 0; i < v.length && i < 20; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: i == v.length - 1 || i == 19 ? null : const Border(bottom: BorderSide(color: kLine))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${v[i].$1['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${distText(v[i].$2)} · ${v[i].$1['addr'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
                      ]),
                    ),
                    if ('${v[i].$1['tel'] ?? ''}'.isNotEmpty)
                      IconButton(onPressed: () => openUrl('tel:${v[i].$1['tel']}'), icon: const Icon(Icons.call_outlined, size: 20, color: kBlue)),
                  ]),
                ),
            ]),
          ),
        const SizedBox(height: 18),
        // 온라인 추모관 (대표님 별도 서비스 — 서버에서 주소가 오면 열림)
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: memorial?['url'] == null ? () => toast(context, '온라인 추모관은 곧 열려요') : () => openUrl('${memorial!['url']}'),
            child: Ink(
              decoration: cardBox(),
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(children: [
                const LineIcon('flower', size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${memorial?['title'] ?? '온라인 추모관'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${memorial?['sub'] ?? '사진과 이야기를 남기고, 가족·친구가 함께 기억하는 공간 · 준비 중'}', maxLines: 2, style: T.small),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: kMute),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
