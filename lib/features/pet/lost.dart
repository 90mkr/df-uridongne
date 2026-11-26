// 우리 동네 실종·구조 동물 — 반려동물 테마 방 (대표님 11-26, 껍데기 먼저)
// 자료: 농림축산검역본부 분실동물 조회(15141910)·구조동물 조회(15098931) → collector 가 web/data/pet/lost.json 으로
//   {"updated", "items": [{"t":"lost"|"found", "kind","breed","color","sex","age","date","place","sido","gu","care","tel","img","notice"}]}
// 활용신청 전에는 파일이 없어 「준비 중」. 실종 알림 받기는 설정만 먼저 저장('pet.lost.alert') — 알림 보내기는 본부와 연결 후
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class LostItem {
  final String t, kind, breed, color, sex, age, date, place, sido, gu, care, tel, img, notice;
  LostItem(Map j)
      : t = '${j['t'] ?? 'found'}',
        kind = '${j['kind'] ?? ''}',
        breed = '${j['breed'] ?? ''}',
        color = '${j['color'] ?? ''}',
        sex = '${j['sex'] ?? ''}',
        age = '${j['age'] ?? ''}',
        date = '${j['date'] ?? ''}',
        place = '${j['place'] ?? ''}',
        sido = '${j['sido'] ?? ''}',
        gu = '${j['gu'] ?? ''}',
        care = '${j['care'] ?? ''}',
        tel = '${j['tel'] ?? ''}',
        img = '${j['img'] ?? ''}',
        notice = '${j['notice'] ?? ''}';
  bool get lost => t == 'lost';
}

class PetLostPage extends StatefulWidget {
  final Complex complex;
  const PetLostPage({super.key, required this.complex});
  @override
  State<PetLostPage> createState() => _PetLostPageState();
}

class _PetLostPageState extends State<PetLostPage> {
  List<LostItem>? items;
  bool tabLost = true;
  bool alert = false;
  bool wide = false; // 우리 구 → 우리 시도

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await prefGet('pet.lost.alert');
    final j = await getJson('${dataBase}pet/lost.json');
    if (!mounted) return;
    setState(() {
      alert = a == '1';
      items = j is Map ? [for (final x in (j['items'] as List? ?? const [])) if (x is Map) LostItem(x)] : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.complex.area;
    final gu = area?.gu ?? '';
    final sido = area?.sido ?? '';
    final all = items;
    final v = (all ?? const <LostItem>[]).where((x) => x.lost == tabLost && (wide ? x.sido.contains(sido.isEmpty ? x.sido : sido.substring(0, 2)) : (gu.isEmpty || x.gu.contains(gu)))).toList();
    return DetailPage(
      title: '실종·구조 동물',
      icon: 'pet',
      white: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30), children: [
        // 알림 받기
        Container(
          decoration: cardBox(),
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(children: [
            const LineIcon('bell', size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('우리 동네 실종 알림', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${gu.isEmpty ? '우리 동네' : gu}에서 잃어버린 아이·구조된 아이가 올라오면 알려 드려요', style: T.small),
              ]),
            ),
            Switch.adaptive(
              value: alert,
              onChanged: (b) async {
                setState(() => alert = b);
                await prefSet('pet.lost.alert', b ? '1' : '0');
                if (context.mounted) toast(context, b ? '알림을 켰어요 (곧 보내 드려요)' : '알림을 껐어요');
              },
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          ChoiceChipBox('잃어버렸어요', on: tabLost, onTap: () => setState(() => tabLost = true)),
          const SizedBox(width: 6),
          ChoiceChipBox('구조됐어요·입양', on: !tabLost, onTap: () => setState(() => tabLost = false)),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => wide = !wide),
            child: Padding(padding: const EdgeInsets.all(6), child: Text(wide ? '${sido.isEmpty ? '시도' : sido} 전체' : '${gu.isEmpty ? '우리 구' : gu}만', style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w600))),
          ),
        ]),
        const SizedBox(height: 10),
        if (all == null)
          _empty('자료를 준비하고 있어요', '농림축산검역본부 국가동물보호정보시스템의 실종·구조 소식을 곧 우리 동네 기준으로 모아 보여 드려요.')
        else if (v.isEmpty)
          _empty(tabLost ? '지금 올라온 실종 신고가 없어요' : '지금 보호 중인 아이가 없어요', '범위를 넓혀 보거나, 알림을 켜 두면 새로 올라올 때 알려 드려요.')
        else
          for (final x in v.take(60)) ...[_Card(x), const SizedBox(height: 10)],
        const SizedBox(height: 6),
        Text('자료: 농림축산식품부 농림축산검역본부 국가동물보호정보시스템. 아이를 찾았거나 보셨다면 보호소·신고자 연락처로 바로 알려 주세요.', style: T.tiny),
      ]),
    );
  }

  Widget _empty(String t, String s) => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(children: [
          const LineIcon('pet', size: 54),
          const SizedBox(height: 10),
          Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(s, textAlign: TextAlign.center, style: T.small),
        ]),
      );
}

class _Card extends StatelessWidget {
  final LostItem x;
  const _Card(this.x);
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(),
        clipBehavior: Clip.antiAlias,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 104,
            height: 116,
            child: x.img.isEmpty
                ? const ColoredBox(color: Color(0xFFF1F4F8), child: Center(child: LineIcon('pet', size: 40)))
                : Image.network(x.img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF1F4F8))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Pill(x.lost ? '실종' : '보호 중', color: x.lost ? const Color(0xFFE5484D) : kBlue, bg: x.lost ? const Color(0xFFFDEEF0) : const Color(0xFFEAF2FF)),
                  const SizedBox(width: 6),
                  Text(x.date, style: T.tiny),
                ]),
                const SizedBox(height: 6),
                Text([x.breed.isEmpty ? x.kind : x.breed, x.sex, x.age].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                if (x.color.isNotEmpty) Text(x.color, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
                const SizedBox(height: 4),
                Text(x.place, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                if (x.care.isNotEmpty || x.tel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text([x.care, x.tel].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
        ]),
      );
}
