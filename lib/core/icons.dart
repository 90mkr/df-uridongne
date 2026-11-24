import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

// ---------------- 아이콘: 가는 선 + 옅은 면 (원 안에 넣지 않음) ----------------
// 48×48 칸에 그린다. 선 색(L)·면 색(F)은 그릴 때 바꿔 끼운다.

const _svgHead = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="L" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';

const Map<String, String> kIconBody = {
  // 음식점: 그릇과 김
  'food': '<path d="M8 25h32c0 8-7 14-16 14S8 33 8 25z" fill="F"/><path d="M8 25h32"/><path d="M18 39h12"/><path d="M18 19c-2-2 2-4 0-7M24 19c-2-2 2-4 0-7M30 19c-2-2 2-4 0-7"/>',
  // 카페: 잔과 받침
  'cafe': '<path d="M11 17h22v10c0 6-5 10-11 10s-11-4-11-10z" fill="F"/><path d="M33 20h3a4 4 0 0 1 0 8h-3"/><path d="M8 41h28"/><path d="M18 12c-1-1 1-3 0-5M24 12c-1-1 1-3 0-5"/>',
  // 마트·편의점: 장바구니 수레
  'mart': '<path d="M6 9h5l4 21h22l4-15H13" /><path d="M14 15h27l-4 15H15z" fill="F" stroke="none"/><circle cx="18" cy="37" r="2.6"/><circle cx="33" cy="37" r="2.6"/>',
  // 병원: 건물과 십자
  'hosp': '<rect x="9" y="12" width="30" height="28" rx="2" fill="F"/><path d="M24 18v10M19 23h10"/><path d="M20 40v-6h8v6"/><path d="M17 12V8h14v4"/>',
  // 약국: 알약
  'pharm': '<rect x="8" y="18" width="32" height="13" rx="6.5" transform="rotate(-35 24 24.5)" fill="F"/><path d="M19 15l10 15" /><rect x="8" y="18" width="32" height="13" rx="6.5" transform="rotate(-35 24 24.5)"/>',
  // 어린이집·유치원: 쌓기 나무
  'kids': '<rect x="9" y="27" width="13" height="13" rx="1.5" fill="F"/><rect x="26" y="27" width="13" height="13" rx="1.5"/><path d="M24 9l7.5 13h-15z" fill="F"/><path d="M24 9l7.5 13h-15z"/>',
  // 학원: 펼친 책
  'acad': '<path d="M24 14c-4-3-10-4-16-3v25c6-1 12 0 16 3" fill="F"/><path d="M24 14c4-3 10-4 16-3v25c-6-1-12 0-16 3z"/><path d="M24 14c-4-3-10-4-16-3v25c6-1 12 0 16 3z"/>',
  // 세탁소: 세탁기
  'laundry': '<rect x="10" y="7" width="28" height="34" rx="3"/><circle cx="24" cy="26" r="8.5" fill="F"/><circle cx="24" cy="26" r="8.5"/><path d="M19 27c2 2 5 2 7 0"/><path d="M15 13h5M30 13h2"/>',
  // 떡집·반찬: 접시 위 떡
  'ricecake': '<path d="M7 33h34" /><path d="M10 33c1 4 6 6 14 6s13-2 14-6"/><rect x="12" y="23" width="11" height="9" rx="3" fill="F"/><rect x="25" y="23" width="11" height="9" rx="3"/><rect x="18" y="14" width="12" height="9" rx="3" fill="F"/>',
  // 미용실: 가위
  'hair': '<circle cx="14" cy="34" r="5" fill="F"/><circle cx="14" cy="34" r="5"/><circle cx="34" cy="34" r="5"/><path d="M17.5 30.5L36 9M30.5 30.5L12 9"/>',
  // 꽃집: 꽃
  'flower': '<circle cx="24" cy="17" r="4"/><path d="M24 13c-3-6 3-6 0 0M28 17c6-3 6 3 0 0M24 21c3 6-3 6 0 0M20 17c-6 3-6-3 0 0" fill="F"/><path d="M24 21v19"/><path d="M24 33c-6 0-9-4-9-7 4 0 9 3 9 7zM24 30c5 0 8-3 8-6-4 0-8 2-8 6z" fill="F"/>',
  // 수선·열쇠: 열쇠
  'repair': '<circle cx="15" cy="20" r="7" fill="F"/><circle cx="15" cy="20" r="7"/><circle cx="15" cy="20" r="2"/><path d="M21 24l17 13M31 31.5l3-4M35 34.5l3-4"/>',
  // 철물·인테리어: 망치
  'hardware': '<path d="M12 12l9-4 6 6-4 3z" fill="F"/><path d="M12 12l9-4 6 6-4 3-8-2z"/><path d="M22 16l18 22-3 3-19-21"/>',
  // 부동산: 집
  'realty': '<path d="M8 22L24 9l16 13" /><path d="M12 19v21h24V19" fill="F"/><path d="M12 19v21h24V19"/><path d="M21 40V29h6v11"/>',
  // 은행: 기둥 건물
  'bank': '<path d="M7 18L24 9l17 9z" fill="F"/><path d="M7 18L24 9l17 9z"/><path d="M11 22v13M19 22v13M29 22v13M37 22v13"/><path d="M7 39h34"/>',
  // 주유소·세차·정비: 자동차
  'car': '<path d="M9 27l3-9c1-2 2-3 4-3h16c2 0 3 1 4 3l3 9" /><rect x="7" y="27" width="34" height="9" rx="3" fill="F"/><rect x="7" y="27" width="34" height="9" rx="3"/><path d="M11 36v3h5v-3M32 36v3h5v-3"/><circle cx="14" cy="31.5" r="1.4"/><circle cx="34" cy="31.5" r="1.4"/>',
  // 동물병원·애견: 발자국
  'pet': '<ellipse cx="24" cy="32" rx="8" ry="6.5" fill="F"/><ellipse cx="24" cy="32" rx="8" ry="6.5"/><ellipse cx="13" cy="22" rx="3" ry="4"/><ellipse cx="20" cy="15" rx="3" ry="4"/><ellipse cx="28" cy="15" rx="3" ry="4"/><ellipse cx="35" cy="22" rx="3" ry="4"/>',
  // 주민센터·공공기관: 깃발 건물
  'public': '<rect x="10" y="22" width="28" height="18" rx="1.5" fill="F"/><rect x="10" y="22" width="28" height="18" rx="1.5"/><path d="M24 22V8"/><path d="M24 8h9l-2 3 2 3h-9" /><path d="M21 40v-8h6v8"/>',
  // ---- 기능 ----
  'trash': '<path d="M15 18l5-8.5a3 3 0 0 1 5.2 0l3 5" /><path d="M28 14.5l.8-4.6M28 14.5l-4.4-1.3"/><path d="M34 22l4.6 8a3 3 0 0 1-2.6 4.5H30"/><path d="M30 34.5l3.4 3.1M30 34.5l3.2-3.4"/><path d="M20 34.5h-8a3 3 0 0 1-2.6-4.5l3.2-5.5"/><path d="M12.6 24.5l-4.4 1.2M12.6 24.5l1 4.5"/><circle cx="24" cy="26" r="5" fill="F" stroke="none"/>',
  'bus': '<rect x="10" y="7" width="28" height="28" rx="6" fill="F"/><rect x="10" y="7" width="28" height="28" rx="6"/><path d="M10 22h28"/><circle cx="17" cy="28.5" r="1.6"/><circle cx="31" cy="28.5" r="1.6"/><path d="M14 35v4M34 35v4"/>',
  'weather': '<circle cx="24" cy="24" r="8" fill="F"/><circle cx="24" cy="24" r="8"/><path d="M24 7v4M24 37v4M7 24h4M37 24h4M12 12l3 3M33 33l3 3M12 36l3-3M33 15l3-3"/>',
  'deals': '<path d="M7 36l9-8 7 5 9-11 9-6"/><circle cx="41" cy="16" r="2.4" fill="F"/><path d="M7 41h34"/>',
  'gas': '<rect x="8" y="8" width="20" height="32" rx="3" fill="F"/><rect x="8" y="8" width="20" height="32" rx="3"/><path d="M13 16h10"/><path d="M28 18l6 4v12a3 3 0 0 0 6 0V18l-4-5"/>',
  'charger': '<rect x="10" y="7" width="22" height="34" rx="3" fill="F"/><rect x="10" y="7" width="22" height="34" rx="3"/><path d="M23 14l-6 10h6l-3 9"/><path d="M32 20h4a3 3 0 0 1 3 3v8"/>',
  'parking': '<rect x="8" y="8" width="32" height="32" rx="6" fill="F"/><rect x="8" y="8" width="32" height="32" rx="6"/><path d="M20 33V16h6.5a5.2 5.2 0 0 1 0 10.4H20"/>',
  'book': '<rect x="10" y="7" width="28" height="34" rx="3" fill="F"/><rect x="10" y="7" width="28" height="34" rx="3"/><path d="M18 16h12M18 24h12M18 32h6"/>',
  'home': '<path d="M8 21L24 8l16 13v19H30V30H18v10H8z" fill="F"/><path d="M8 21L24 8l16 13v19H30V30H18v10H8z"/>',
  'grid': '<rect x="8" y="8" width="14" height="14" rx="3"/><rect x="26" y="8" width="14" height="14" rx="3" fill="F"/><rect x="26" y="8" width="14" height="14" rx="3"/><rect x="8" y="26" width="14" height="14" rx="3"/><rect x="26" y="26" width="14" height="14" rx="3"/>',
  'me': '<circle cx="24" cy="17" r="7" fill="F"/><circle cx="24" cy="17" r="7"/><path d="M10 40c2.4-7 7.6-11 14-11s11.6 4 14 11"/>',
  'bell': '<path d="M12 32V22a12 12 0 0 1 24 0v10l3 4H9z"/><path d="M20 40a4 4 0 0 0 8 0"/>',
  'apt': '<rect x="9" y="10" width="14" height="30" rx="1.5" fill="F"/><rect x="9" y="10" width="14" height="30" rx="1.5"/><rect x="25" y="18" width="14" height="22" rx="1.5"/><path d="M13 16h6M13 22h6M13 28h6M29 24h6M29 30h6"/><path d="M6 40h36"/>',
  'lotto': '<circle cx="18" cy="20" r="9" fill="F"/><circle cx="18" cy="20" r="9"/><circle cx="31" cy="29" r="9"/><path d="M15 20h6M18 17v6"/><path d="M28 29h6"/>',
  // ---- 생활 도구 ----
  'post': '<rect x="7" y="12" width="34" height="24" rx="2.5" fill="F"/><rect x="7" y="12" width="34" height="24" rx="2.5"/><path d="M8 14l16 12 16-12"/>',
  'night': '<path d="M30 9a13 13 0 1 0 9 22A15 15 0 0 1 30 9z" fill="F"/><path d="M30 9a13 13 0 1 0 9 22A15 15 0 0 1 30 9z"/><path d="M20 21v8M16 25h8"/>',
  'kokple': '<path d="M24 41s-12-11-12-20a12 12 0 0 1 24 0c0 9-12 20-12 20z" fill="F"/><path d="M24 41s-12-11-12-20a12 12 0 0 1 24 0c0 9-12 20-12 20z"/><path d="M24 26c-4-3-6-5-6-7a3 3 0 0 1 6-1 3 3 0 0 1 6 1c0 2-2 4-6 7z"/>',
  'owner': '<path d="M8 18l3-9h26l3 9" /><path d="M8 18c0 3 2.5 5 5.3 5s5.3-2 5.3-5c0 3 2.5 5 5.4 5s5.3-2 5.3-5c0 3 2.5 5 5.4 5S40 21 40 18z" fill="F"/><path d="M8 18c0 3 2.5 5 5.3 5s5.3-2 5.3-5c0 3 2.5 5 5.4 5s5.3-2 5.3-5c0 3 2.5 5 5.4 5S40 21 40 18z"/><path d="M11 23v17h26V23"/><path d="M20 40v-9h8v9"/>',
  'pin': '<path d="M24 41s-11-10-11-19a11 11 0 0 1 22 0c0 9-11 19-11 19z" fill="F"/><path d="M24 41s-11-10-11-19a11 11 0 0 1 22 0c0 9-11 19-11 19z"/><circle cx="24" cy="22" r="4"/>',
  'search': '<circle cx="21" cy="21" r="12"/><path d="M30 30l10 10"/>',
  'phone': '<path d="M15 8l5 9-3.5 3c2 4.5 6 8.5 10.5 10.5l3-3.5 9 5-2 6c-14 1-27-12-26-26z" fill="F"/><path d="M15 8l5 9-3.5 3c2 4.5 6 8.5 10.5 10.5l3-3.5 9 5-2 6c-14 1-27-12-26-26z"/>',
  'event': '<path d="M12 41V9"/><path d="M12 10c6-3 10 3 16 0s8-1 10 1v14c-2-2-4-3-10 0s-10-3-16 0z" fill="F"/><path d="M33 31l1.5 3 3 .5-2.2 2 .6 3.1-2.9-1.5-2.9 1.5.6-3.1-2.2-2 3-.5z"/>',
  'route': '<circle cx="12" cy="36" r="4"/><circle cx="36" cy="12" r="4" fill="F"/><circle cx="36" cy="12" r="4"/><path d="M15 33l6-6c3-3 2-7 6-9l5-3"/>',
  'map': '<path d="M7 12l11-4 12 4 11-4v28l-11 4-12-4-11 4z" fill="F"/><path d="M7 12l11-4 12 4 11-4v28l-11 4-12-4-11 4z"/><path d="M18 8v28M30 12v28"/>',
  'list': '<path d="M16 13h24M16 24h24M16 35h24"/><circle cx="9" cy="13" r="1.6"/><circle cx="9" cy="24" r="1.6"/><circle cx="9" cy="35" r="1.6"/>',
  'loc': '<circle cx="24" cy="24" r="12"/><circle cx="24" cy="24" r="4" fill="F"/><path d="M24 6v6M24 36v6M6 24h6M36 24h6"/>',
};

class LineIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color line;
  final Color fill;
  const LineIcon(this.name, {super.key, this.size = 28, this.line = kInk, this.fill = kSoft});

  @override
  Widget build(BuildContext context) {
    // 기본 색으로 부르면 색 아이콘(대표님 시안 11-23)을 쓴다. 색을 따로 준 곳(파랑 카드 위 흰 아이콘 등)은 선 아이콘 그대로.
    if (line == kInk && fill == kSoft) {
      if (kColorPng.contains(name)) {
        return SizedBox(
          width: size,
          height: size,
          child: OverflowBox(
            maxWidth: size * 1.18,
            maxHeight: size * 1.18,
            child: Image.asset('assets/icons/$name.png', width: size * 1.18, height: size * 1.18, filterQuality: FilterQuality.medium),
          ),
        );
      }
      final c = kColorSvg[name];
      if (c != null) return SvgPicture.string(c, width: size, height: size);
    }
    final body = kIconBody[name] ?? kIconBody['pin']!;
    // 반투명 면은 fill-opacity 로 (예: 파랑 카드 위 흰 면)
    final fo = fill.a < 0.99 && fill.a >= 0.02 ? ' fill-opacity="${fill.a.toStringAsFixed(2)}"' : '';
    final svg = ('$_svgHead$body</svg>').replaceAll('"L"', '"${_hex(line)}"').replaceAll('fill="F"', 'fill="${_hex(fill)}"$fo');
    return SvgPicture.string(svg, width: size, height: size);
  }
}

String _hex(Color c) {
  if (c.a < 0.02) return 'none';
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}


// ---------------- 색 아이콘 (단지 홈 시안 11-23) ----------------
// 업종 18개: 그림 파일 assets/icons/<이름>.png (시안 그림에서 오려 냄)
const kColorPng = {
  'laundry', 'repair', 'ricecake', 'hair', 'acad', 'kids', 'hosp', 'realty', 'food',
  'cafe', 'mart', 'pharm', 'flower', 'hardware', 'bank', 'car', 'pet', 'public',
  // 기능·생활 도구 (시안 11-23 둘째 그림)
  'weather', 'trash', 'bus', 'book', 'deals', 'gas', 'charger', 'parking', 'post', 'lotto',
  // 대표님 그림 11-24: 행사·기념일·알람·학교·지하철도 그림 파일로
  'event', 'anniv', 'alarm', 'school', 'subway',
  'apt', // 우리 단지: 웃는 집 (대표님 11-24)
};

// 기능·도구: 남색 선 + 색 면 (시안 느낌으로 직접 그림)
const _n = '#24539F'; // 남색 선
const Map<String, String> kColorSvg = {
  // 기념일: 케이크 (11-24)
  'event': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M12 42V8" stroke="$_n" stroke-width="2" stroke-linecap="round"/><path d="M12 9c6-3 10 3 16 0s8-1 10 1v15c-2-2-4-3-10 0s-10-3-16 0z" fill="#FF9A7A" stroke="$_n" stroke-width="2" stroke-linejoin="round"/><path d="M33 30l1.6 3.2 3.4.5-2.5 2.3.6 3.4-3.1-1.6-3.1 1.6.6-3.4-2.5-2.3 3.4-.5z" fill="#FFE27A" stroke="$_n" stroke-width="1.6" stroke-linejoin="round"/></svg>',
  'board': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M6 10a5 5 0 0 1 5-5h20a5 5 0 0 1 5 5v12a5 5 0 0 1-5 5H17l-7 6v-6.3A5 5 0 0 1 6 22z" fill="#4C8DF6" stroke="$_n" stroke-width="2.4" stroke-linejoin="round"/><path d="M13 13h16M13 19h10" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/><path d="M40 18a4 4 0 0 1 4 4v11a4 4 0 0 1-4 4h-1v5l-6-5h-9a4 4 0 0 1-4-4v-3" fill="#FFD84D" stroke="$_n" stroke-width="2.4" stroke-linejoin="round"/></svg>',
  'anniv': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="8" y="24" width="32" height="16" rx="4" fill="#FF9FB3" stroke="$_n" stroke-width="2"/><path d="M8 31c4 3 8 3 12 0s8-3 12 0 6 2 8 0" fill="none" stroke="#fff" stroke-width="2.4"/><rect x="12" y="16" width="24" height="9" rx="3" fill="#FFE27A" stroke="$_n" stroke-width="2"/><path d="M24 8v8" stroke="$_n" stroke-width="2"/><path d="M24 4c2 2 2 4 0 5-2-1-2-3 0-5z" fill="#FF7A59"/><path d="M6 40h36" stroke="$_n" stroke-width="2" stroke-linecap="round"/></svg>',
  // 학교: 깃발 건물 (11-24)
  'school': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M6 20L24 11l18 9" fill="#FFB547" stroke="$_n" stroke-width="2" stroke-linejoin="round"/><rect x="9" y="20" width="30" height="20" rx="2" fill="#FFE9B8" stroke="$_n" stroke-width="2"/><rect x="20" y="29" width="8" height="11" rx="1.5" fill="#4C8DF6" stroke="$_n" stroke-width="1.8"/><rect x="12" y="24" width="5" height="5" rx="1" fill="#fff" stroke="$_n" stroke-width="1.6"/><rect x="31" y="24" width="5" height="5" rx="1" fill="#fff" stroke="$_n" stroke-width="1.6"/><path d="M24 11V4" stroke="$_n" stroke-width="2"/><path d="M24 4h7l-2 2.5 2 2.5h-7" fill="#FF7A59" stroke="$_n" stroke-width="1.4"/><path d="M5 40h38" stroke="$_n" stroke-width="2" stroke-linecap="round"/></svg>',
  // 알람: 자명종 (11-24)
  'alarm': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="26" r="14" fill="#4C8DF6" stroke="$_n" stroke-width="2"/><circle cx="24" cy="26" r="10" fill="#fff"/><path d="M24 19v7l5 3" fill="none" stroke="$_n" stroke-width="2.2" stroke-linecap="round"/><path d="M8 13l6-5M40 13l-6-5" stroke="$_n" stroke-width="2.4" stroke-linecap="round"/><path d="M14 39l-3 4M34 39l3 4" stroke="$_n" stroke-width="2.2" stroke-linecap="round"/><circle cx="10" cy="10" r="3" fill="#FFE27A"/><circle cx="38" cy="10" r="3" fill="#FFE27A"/></svg>',
  // 지하철: 앞모습 전동차 (11-24)
  'subway': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="10" y="5" width="28" height="31" rx="9" fill="#7B6CF0" stroke="$_n" stroke-width="2"/><rect x="14" y="10" width="20" height="11" rx="3" fill="#fff"/><path d="M24 10v11" stroke="#CFC8FB" stroke-width="2"/><circle cx="17.5" cy="28" r="2.2" fill="#FFE27A"/><circle cx="30.5" cy="28" r="2.2" fill="#FFE27A"/><path d="M15 36l-4 7M33 36l4 7M13 41h22" stroke="$_n" stroke-width="2.2" stroke-linecap="round"/></svg>',
  'bus': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="9" y="7" width="30" height="30" rx="7" fill="#4C8DF6" stroke="$_n" stroke-width="2"/><rect x="13" y="12" width="22" height="10" rx="2.5" fill="#fff"/><rect x="15" y="9" width="18" height="2" rx="1" fill="#CFE0FD"/><circle cx="17" cy="29" r="2.2" fill="#FFE27A"/><circle cx="31" cy="29" r="2.2" fill="#FFE27A"/><rect x="13" y="36" width="5" height="5" rx="1.5" fill="$_n"/><rect x="30" y="36" width="5" height="5" rx="1.5" fill="$_n"/></svg>',
  'book': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="8" y="6" width="32" height="36" rx="8" fill="#3D7FF3"/><path d="M19 15l3 5-2 2c1.4 2.8 3.4 4.8 6 6l2-2 5 3-1 3.6c-8 .6-15.6-7-15-15z" fill="#fff"/><path d="M31 15h3M31 20h3" stroke="#BFD6FF" stroke-width="2.2" stroke-linecap="round"/></svg>',
  'gas': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="8" y="7" width="22" height="34" rx="4" fill="#FF8A3D"/><rect x="12" y="11" width="14" height="10" rx="2" fill="#fff"/><rect x="6" y="39" width="26" height="4" rx="2" fill="#E2641E"/><path d="M30 17l6 4v12.5a2.75 2.75 0 0 0 5.5 0V19l-4-5" fill="none" stroke="#E2641E" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  'charger': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="8" y="6" width="24" height="36" rx="4" fill="#31C065"/><path d="M22 12l-7 12h6l-3 11 9-14h-6l3-9z" fill="#fff"/><path d="M32 18h4a3 3 0 0 1 3 3v9" fill="none" stroke="#1E9B4E" stroke-width="2.6" stroke-linecap="round"/><circle cx="39" cy="33" r="2.6" fill="#1E9B4E"/></svg>',
  'parking': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="7" y="7" width="34" height="34" rx="8" fill="#2F7BF5"/><path d="M19 34V14h7.5a6 6 0 0 1 0 12H19" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  'post': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="6" y="11" width="36" height="26" rx="5" fill="#8C6CF2"/><path d="M8 14l16 12 16-12" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  'deals': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M6 38l10-10 7 5 12-14 7-4v23H6z" fill="#D6E6FE"/><path d="M6 36l10-10 7 5 12-14" fill="none" stroke="#2F7BF5" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M30 15h7v7" fill="none" stroke="#2F7BF5" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  'lotto': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="18" cy="21" r="10" fill="#FFC531"/><circle cx="31" cy="29" r="10" fill="#4C8DF6"/><circle cx="18" cy="21" r="4.5" fill="#fff"/><circle cx="31" cy="29" r="4.5" fill="#fff"/></svg>',
};
