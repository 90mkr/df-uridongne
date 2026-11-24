// 「오늘 뭐 먹지?」 룰렛 원판 (룰렛 담당: 본부, 대표님 요청 11-24)
// 칸: 파스텔 색 + 얇은 선 음식 그림 + 짧은 이름. 위쪽 가운데에 바늘(삼각형).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _n = '#24539F'; // 남색 선

class Food {
  final String id, name;
  final String svg; // 48×48 안쪽 그림 (선 + 연한 채움)
  final List<String> subs; // 카카오 분류 끝 이름 (예: 「중국요리」)
  final List<String> words; // 가게 이름에 들어가면 이 종류
  const Food(this.id, this.name, this.svg, {this.subs = const [], this.words = const []});
}

String _s(String inner) => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="$_n" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';

final kFoods = <Food>[
  Food('kor', '한식', _s('<path d="M8 24h32a16 16 0 0 1-32 0z" fill="#FFE3D3"/><path d="M13 24c2-6 20-6 22 0" fill="#fff"/><path d="M30 6l-6 15M36 8l-8 13"/>'), subs: ['한식', '한정식', '한식뷔페', '찌개,전골', '쌈밥', '두부전문점', '추어', '삼계탕', '비빔밥', '본죽&비빔밥cafe', '죽'], words: ['한식', '백반', '찌개']),
  Food('chi', '중식', _s('<path d="M8 22h32a16 16 0 0 1-32 0z" fill="#FFD8D8"/><path d="M14 22c3-5 5 3 8-2s6 3 8-1 4 2 5 3" fill="none"/><path d="M28 4l-3 15M34 5l-5 14"/>'), subs: ['중국요리', '중식', '양꼬치', '마라탕'], words: ['반점', '짜장', '마라', '중화']),
  Food('jpn', '일식', _s('<rect x="9" y="22" width="30" height="10" rx="5" fill="#fff"/><path d="M11 22c4-7 22-7 26 0" fill="#FFC9B5"/><path d="M9 36h30"/>'), subs: ['일식', '초밥,롤', '돈까스,우동', '일본식라면'], words: ['스시', '초밥', '돈까스', '라멘']),
  Food('snack', '분식', _s('<path d="M14 10l20 28" /><ellipse cx="20" cy="18" rx="5" ry="3" transform="rotate(55 20 18)" fill="#FFB8B8"/><ellipse cx="25" cy="25" rx="5" ry="3" transform="rotate(55 25 25)" fill="#FFB8B8"/><ellipse cx="30" cy="32" rx="5" ry="3" transform="rotate(55 30 32)" fill="#FFB8B8"/>'), subs: ['분식', '떡볶이', '순대', '김밥', '간식'], words: ['분식', '떡볶이', '김밥']),
  Food('chicken', '치킨', _s('<path d="M30 10a10 10 0 0 0-14 14l-5 5a3 3 0 1 0 4 4l1 3a3 3 0 1 0 4-4l-3-1 5-5a10 10 0 0 0 8-16z" fill="#FFE2A8"/>'), subs: ['치킨', 'BHC치킨', 'BBQ', '교촌치킨', '굽네치킨', '닭강정', '처갓집양념치킨', '네네치킨', '푸라닭'], words: ['치킨', '통닭']),
  Food('pizza', '피자', _s('<path d="M10 12c9-5 19-5 28 0L24 40z" fill="#FFE7A6"/><path d="M10 12c9-5 19-5 28 0" stroke-width="3"/><circle cx="20" cy="18" r="2" fill="#FF9D8A"/><circle cx="28" cy="20" r="2" fill="#FF9D8A"/><circle cx="24" cy="28" r="2" fill="#FF9D8A"/>'), subs: ['피자', '도미노피자', '피자헛', '피자스쿨'], words: ['피자']),
  Food('meat', '고기', _s('<path d="M8 30h32" /><path d="M10 36h28"/><path d="M14 24c0-6 6-9 11-8s9 5 8 10-8 6-13 4-6-3-6-6z" fill="#FFC4C4"/><path d="M19 21c3 1 6 3 8 6"/>'), subs: ['육류,고기', '삼겹살', '갈비', '곱창,막창', '오리', '소고기구이', '돼지고기구이'], words: ['고기', '갈비', '삼겹', '한우']),
  Food('gukbap', '국밥', _s('<path d="M8 22h32l-3 14a4 4 0 0 1-4 3H15a4 4 0 0 1-4-3z" fill="#FFF0C9"/><path d="M18 8c-2 3 2 5 0 9M25 7c-2 3 2 5 0 9M32 8c-2 3 2 5 0 9"/>'), subs: ['국밥', '해장국', '곰탕', '감자탕', '설렁탕', '순대국'], words: ['국밥', '해장국', '곰탕', '설렁탕']),
  Food('bread', '빵·카페', _s('<path d="M10 28c0-8 6-12 14-12s14 4 14 12z" fill="#FBD9A6"/><path d="M17 18l2 10M24 16v12M31 18l-2 10"/><path d="M8 32h32"/>'), subs: ['제과,베이커리', '파리바게뜨', '뚜레쥬르', '카페', '커피전문점', '디저트카페'], words: ['베이커리', '제과', '카페']),
  Food('noodle', '면', _s('<path d="M8 22h32a16 16 0 0 1-32 0z" fill="#E7F0FF"/><path d="M13 22c2-4 4 2 6-2s4 2 6-2 4 2 6-2 3 2 4 2"/><path d="M30 4l-3 16M36 5l-5 15"/>'), subs: ['칼국수', '국수', '냉면', '우동', '쌀국수', '라면'], words: ['칼국수', '국수', '냉면', '면옥']),
  Food('jokbal', '족발·보쌈', _s('<path d="M12 30c-2-8 4-16 12-16s14 8 12 16z" fill="#F7D2B6"/><path d="M8 34h32"/><path d="M18 22c2 2 4 3 6 3"/>'), subs: ['족발,보쌈'], words: ['족발', '보쌈']),
  Food('sashimi', '회', _s('<path d="M8 24c6-8 18-10 26-4l6-5v18l-6-5c-8 6-20 4-26-4z" fill="#D9ECFF"/><circle cx="15" cy="23" r="1.5" fill="$_n"/>'), subs: ['회', '해물,생선', '참치회', '게,대게', '조개', '횟집'], words: ['횟집', '수산', '회센터']),
  Food('western', '양식', _s('<ellipse cx="24" cy="30" rx="15" ry="7" fill="#FFF1D6"/><path d="M17 28c3-4 11-4 14 0" /><path d="M30 6v14M27 6v6a3 3 0 0 0 6 0V6"/>'), subs: ['양식', '이탈리안', '스테이크,립', '패밀리레스토랑', '멕시칸,브라질'], words: ['파스타', '스테이크', '비스트로']),
  Food('burger', '버거', _s('<path d="M10 22c0-7 6-11 14-11s14 4 14 11z" fill="#FFD9A0"/><rect x="9" y="25" width="30" height="5" rx="2.5" fill="#B9E2B0"/><path d="M10 33h28a4 4 0 0 1-4 4H14a4 4 0 0 1-4-4z" fill="#FFD9A0"/>'), subs: ['햄버거', '맘스터치', '롯데리아', '버거킹', '맥도날드', '패스트푸드'], words: ['버거']),
  Food('asian', '아시아', _s('<path d="M8 22h32a16 16 0 0 1-32 0z" fill="#E3F6E0"/><path d="M18 14c4-4 8-4 12 0" /><path d="M24 10v6"/>'), subs: ['아시아음식', '베트남음식', '태국음식', '인도음식'], words: ['쌀국수', '포', '타이']),
];

const kDefaultFoods = ['kor', 'chi', 'jpn', 'snack', 'chicken', 'pizza', 'meat', 'gukbap'];
const _pastel = [Color(0xFFFFE4E1), Color(0xFFE3EEFF), Color(0xFFFFF3D1), Color(0xFFE5F6EC), Color(0xFFF1E6FF), Color(0xFFFFE9D6), Color(0xFFDDF3F8), Color(0xFFFCE4F1)];

Food foodById(String id) => kFoods.firstWhere((f) => f.id == id, orElse: () => kFoods.first);

/// 원판 (angle: 라디안, 바늘은 위쪽 가운데 고정)
class Wheel extends StatelessWidget {
  final List<Food> foods;
  final double size, angle;
  final bool labels;
  const Wheel({super.key, required this.foods, required this.size, this.angle = 0, this.labels = true});

  @override
  Widget build(BuildContext context) {
    final n = foods.length;
    final r = size / 2;
    final seg = 2 * math.pi / n;
    final icon = (size * (n > 8 ? 0.13 : 0.15)).clamp(16.0, 46.0);
    return SizedBox(
      width: size,
      height: size + size * 0.08,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Positioned(
          top: size * 0.06,
          child: Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(children: [
                CustomPaint(size: Size(size, size), painter: _Pie(n)),
                for (var i = 0; i < n; i++)
                  Positioned.fill(
                    child: Transform.rotate(
                      angle: seg * i + seg / 2, // 칸 가운데
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: r * 0.16),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            SvgPicture.string(foods[i].svg, width: icon, height: icon),
                            if (labels) ...[
                              SizedBox(height: size * 0.012),
                              Text(foods[i].name,
                                  style: TextStyle(fontSize: (size * 0.052).clamp(9.0, 15.0), fontWeight: FontWeight.w800, color: const Color(0xFF24324A), letterSpacing: -0.3, height: 1.1)),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                // 가운데 꼭지
                Center(
                  child: Container(
                    width: size * 0.16,
                    height: size * 0.16,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF24539F), width: 1.6), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)]),
                    child: Center(child: Container(width: size * 0.05, height: size * 0.05, decoration: const BoxDecoration(color: Color(0xFFFF7A59), shape: BoxShape.circle))),
                  ),
                ),
              ]),
            ),
          ),
        ),
        // 바늘
        Positioned(top: 0, child: CustomPaint(size: Size(size * 0.11, size * 0.13), painter: _Pin())),
      ]),
    );
  }
}

class _Pie extends CustomPainter {
  final int n;
  _Pie(this.n);
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    final rect = Rect.fromCircle(center: o, radius: r);
    final seg = 2 * math.pi / n;
    for (var i = 0; i < n; i++) {
      c.drawArc(rect, -math.pi / 2 + seg * i, seg, true, Paint()..color = _pastel[i % _pastel.length]);
    }
    final line = Paint()
      ..color = const Color(0x2224539F)
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + seg * i;
      c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * r, line);
    }
    c.drawCircle(o, r - 1.5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white);
    c.drawCircle(o, r - 0.5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x5524539F));
  }

  @override
  bool shouldRepaint(covariant _Pie old) => old.n != n;
}

class _Pin extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawShadow(p, Colors.black, 2, false);
    c.drawPath(p, Paint()..color = const Color(0xFFFF7A59));
    c.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF24539F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 바늘(위쪽)이 가리키는 칸 번호
int pointed(double angle, int n) {
  final seg = 2 * math.pi / n;
  var a = (-angle) % (2 * math.pi);
  if (a < 0) a += 2 * math.pi;
  return (a / seg).floor() % n;
}
