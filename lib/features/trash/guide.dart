// 「이건 어떻게 버려요?」 품목 사전 (전국 공통 분리배출 기준, 지자체마다 조금 다를 수 있음)
// 종류: g 종량제(일반) · f 음식물 · r 재활용 · b 대형폐기물 · s 전용 수거함·기타
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import 'trash_icons.dart';

class GuideItem {
  final String name, where, how, kind;
  final List<String> also; // 찾을 때 쓰는 다른 이름
  const GuideItem(this.name, this.kind, this.where, this.how, [this.also = const []]);
}

const kGuide = <GuideItem>[
  GuideItem('투명 페트병', 'r', '투명 페트병 칸', '내용물을 비우고 라벨을 뗀 뒤 찌그러뜨려 뚜껑을 닫아 내요.', ['생수병', '음료수병', '페트']),
  GuideItem('플라스틱 용기', 'r', '플라스틱', '내용물을 비우고 물로 헹궈요. 다른 재질 뚜껑·라벨은 떼요.', ['배달용기', '샴푸통', '요구르트병']),
  GuideItem('비닐', 'r', '비닐', '과자 봉지·라면 봉지·랩도 비닐로. 이물질은 털어 내고, 씻어도 안 지워지면 종량제 봉투에.', ['봉지', '뽁뽁이', '에어캡', '랩']),
  GuideItem('스티로폼', 'r', '스티로폼', '테이프·운송장을 떼고 깨끗한 흰색만. 색이 있거나 음식이 밴 것은 종량제 봉투에.', ['스티로폴', '아이스박스']),
  GuideItem('택배 상자', 'r', '종이', '테이프와 운송장을 떼고 펼쳐서 묶어 내요.', ['박스', '골판지', '상자']),
  GuideItem('종이', 'r', '종이', '신문·책·노트는 스프링·비닐 표지를 떼고 묶어서. 영수증·코팅지·사진은 종량제 봉투에.', ['신문', '책', '노트', '전단지']),
  GuideItem('우유팩·두유팩', 'r', '종이팩', '헹궈서 펼쳐 말린 뒤 종이팩 칸에. 칸이 없으면 주민센터에서 휴지로 바꿔 주기도 해요.', ['종이팩', '멸균팩']),
  GuideItem('유리병', 'r', '유리병', '뚜껑을 떼고 비워서. 소주·맥주병은 마트에 돌려주면 보증금을 받아요.', ['소주병', '맥주병', '음료병']),
  GuideItem('캔', 'r', '캔·고철', '내용물을 비우고 납작하게. 부탄가스·스프레이는 다 쓴 뒤 구멍을 뚫어 가스를 빼요.', ['알루미늄캔', '부탄가스', '스프레이', '통조림']),
  GuideItem('프라이팬·냄비', 'r', '캔·고철', '손잡이 등 다른 재질은 떼고 고철로 내요.', ['냄비', '고철', '후라이팬']),
  GuideItem('깨진 유리·거울', 'g', '종량제 봉투', '신문지에 싸서 「깨진 유리」라고 적어 종량제 봉투에. 많으면 불연성 마대(특수규격 봉투)에.', ['유리조각', '거울']),
  GuideItem('도자기·뚝배기', 'g', '불연성 마대', '깨진 그릇·도자기는 재활용이 안 돼요. 불연성 마대(특수규격 봉투)에 담아요.', ['그릇', '사기그릇', '화분']),
  GuideItem('달걀·조개 껍데기', 'g', '종량제 봉투', '음식물이 아니라 일반쓰레기예요.', ['계란껍질', '조개껍질', '굴껍데기']),
  GuideItem('닭뼈·생선뼈', 'g', '종량제 봉투', '뼈는 음식물로 내지 않아요.', ['치킨뼈', '갈비뼈', '족발뼈']),
  GuideItem('단단한 씨앗·껍질', 'g', '종량제 봉투', '복숭아·자두 씨, 호두·밤 껍데기, 파인애플 껍질은 일반쓰레기.', ['복숭아씨', '호두껍질', '밤껍질']),
  GuideItem('양파·마늘 껍질', 'g', '종량제 봉투', '대부분 지자체는 일반쓰레기로 받아요. 지자체 안내를 함께 확인하세요.', ['파뿌리', '옥수수껍질']),
  GuideItem('티백·커피 찌꺼기', 'g', '종량제 봉투', '찻잎·원두 찌꺼기·한약 찌꺼기는 물기를 빼서 종량제 봉투에.', ['원두', '한약찌꺼기']),
  GuideItem('남은 음식', 'f', '음식물', '물기를 꼭 짜고 비닐·이쑤시개 같은 이물질을 빼서 내요.', ['음식물', '과일껍질', '채소']),
  GuideItem('식용유', 'g', '종량제 봉투', '휴지·신문지에 적시거나 굳혀서 종량제 봉투에. 폐식용유 수거함이 있으면 그쪽으로.', ['기름', '폐식용유']),
  GuideItem('아이스팩', 's', '수거함·종량제', '물만 든 것은 물을 버리고 비닐로. 젤이 든 것은 주민센터 수거함이나 종량제 봉투에.', ['아이스박스팩']),
  GuideItem('건전지', 's', '폐건전지 수거함', '주민센터·아파트의 폐건전지 수거함에 넣어요.', ['배터리', '건전지']),
  GuideItem('형광등', 's', '형광등 수거함', '깨지지 않게 그대로 형광등 수거함에. 깨진 것은 신문지에 싸서 종량제 봉투에.', ['전구', 'LED']),
  GuideItem('약', 's', '폐의약품 수거함', '약국·보건소·주민센터 수거함에. 알약은 껍질에서 빼서 모아요.', ['폐의약품', '알약', '물약']),
  GuideItem('헌 옷', 's', '의류 수거함', '깨끗한 옷·신발·가방은 의류 수거함에. 솜이불·베개는 종량제나 대형폐기물로.', ['옷', '신발', '가방', '의류']),
  GuideItem('작은 가전', 's', '무상 방문수거', '드라이기·밥솥 같은 작은 가전은 5개 이상 모으면 폐가전 무상 방문수거(1599-0903)로. 적으면 주민센터 수거함에.', ['드라이기', '전기밥솥', '선풍기', '청소기']),
  GuideItem('큰 가전', 's', '무상 방문수거', '냉장고·세탁기·TV는 폐가전 무상 방문수거(1599-0903)에 예약하면 한 개도 무료로 가져가요.', ['냉장고', '세탁기', '에어컨', '티비', 'TV']),
  GuideItem('가구·매트리스', 'b', '대형폐기물 신고', '구청·주민센터나 지자체 신청 사이트에 신고하고 수수료를 낸 뒤 스티커(신고번호)를 붙여 내요.', ['침대', '소파', '책상', '장롱', '의자', '매트리스']),
  GuideItem('칫솔·볼펜·고무장갑', 'g', '종량제 봉투', '여러 재질이 섞인 작은 물건은 일반쓰레기.', ['칫솔', '볼펜', '고무장갑', '빨대', '수세미']),
  GuideItem('기저귀·물티슈', 'g', '종량제 봉투', '물티슈는 플라스틱이 섞여 있어 종량제 봉투에.', ['물티슈', '기저귀', '휴지']),
  GuideItem('우산', 'g', '종량제·고철', '천과 살을 나눌 수 있으면 살은 고철, 천은 종량제. 어려우면 통째로 종량제.', ['장우산', '양산']),
];

class GuideBox extends StatefulWidget {
  const GuideBox({super.key});
  @override
  State<GuideBox> createState() => _GuideBoxState();
}

class _GuideBoxState extends State<GuideBox> {
  final q = TextEditingController();
  String t = '';

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String norm(String s) => s.replaceAll(' ', '').toLowerCase();
    final w = norm(t);
    final list = w.isEmpty ? kGuide.take(8).toList() : kGuide.where((g) => norm('${g.name}${g.where}${g.also.join()}').contains(w)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: q,
        onChanged: (v) => setState(() => t = v),
        style: const TextStyle(fontSize: 14),
        decoration: inputDeco('예: 아이스팩, 치킨뼈, 깨진 유리').copyWith(
          prefixIcon: const Padding(padding: EdgeInsets.all(11), child: TrashIcon('search', size: 18)),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
        ),
      ),
      const SizedBox(height: 6),
      if (list.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('찾는 품목이 없어요. 담당 부서에 물어보시는 게 가장 정확해요.', style: T.small)),
      for (var i = 0; i < list.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: kLine),
        _row(list[i]),
      ],
      if (w.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('품목 ${kGuide.length}개 중 일부예요. 위 칸에 찾아보세요.', style: T.tiny),
        ),
    ]);
  }

  Widget _row(GuideItem g) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: TrashIcon(g.kind, size: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(g.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                const SizedBox(width: 6),
                Pill(g.where),
              ]),
              const SizedBox(height: 3),
              Text(g.how, style: const TextStyle(fontSize: 12, color: kSub, height: 1.4)),
            ]),
          ),
        ]),
      );
}
