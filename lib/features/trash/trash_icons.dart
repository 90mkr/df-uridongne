// 쓰레기 종류 아이콘 (가는 선 + 옅은 면, 이 폴더 안에서만 씀)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';

const _head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="L" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';

const _body = <String, String>{
  // 일반(종량제 봉투)
  'g': '<path d="M14 18h20l-2 20a3 3 0 0 1-3 3H19a3 3 0 0 1-3-3z" fill="F"/><path d="M14 18h20l-2 20a3 3 0 0 1-3 3H19a3 3 0 0 1-3-3z"/><path d="M18 18c0-4 2-8 6-8s6 4 6 8"/><path d="M20 27h8"/>',
  // 음식물 (사과)
  'f': '<path d="M24 16c-4-3-12-2-12 7 0 8 5 16 9 16 1.5 0 2-1 3-1s1.5 1 3 1c4 0 9-8 9-16 0-9-8-10-12-7z" fill="F"/><path d="M24 16c-4-3-12-2-12 7 0 8 5 16 9 16 1.5 0 2-1 3-1s1.5 1 3 1c4 0 9-8 9-16 0-9-8-10-12-7z"/><path d="M24 16c0-3 1-6 3-8"/><path d="M26 11c3-2 6-1 7 0-2 2-5 2-7 0z"/>',
  // 재활용 (돌아가는 화살표)
  'r': '<path d="M15 18l5-8.5a3 3 0 0 1 5.2 0l3 5"/><path d="M28 14.5l.8-4.6M28 14.5l-4.4-1.3"/><path d="M34 22l4.6 8a3 3 0 0 1-2.6 4.5H30"/><path d="M30 34.5l3.4 3.1M30 34.5l3.2-3.4"/><path d="M20 34.5h-8a3 3 0 0 1-2.6-4.5l3.2-5.5"/><path d="M12.6 24.5l-4.4 1.2M12.6 24.5l1 4.5"/><circle cx="24" cy="26" r="5" fill="F" stroke="none"/>',
  // 대형 (소파)
  'b': '<path d="M12 24v-5a4 4 0 0 1 4-4h16a4 4 0 0 1 4 4v5" fill="F"/><path d="M12 24v-5a4 4 0 0 1 4-4h16a4 4 0 0 1 4 4v5"/><path d="M8 26a3 3 0 0 1 6 0v3h20v-3a3 3 0 0 1 6 0v8H8z" fill="F"/><path d="M8 26a3 3 0 0 1 6 0v3h20v-3a3 3 0 0 1 6 0v8H8z"/><path d="M11 34v4M37 34v4"/>',
  // 전용 수거함 (상자)
  's': '<rect x="11" y="17" width="26" height="22" rx="2" fill="F"/><rect x="11" y="17" width="26" height="22" rx="2"/><path d="M9 12h30v5H9z"/><path d="M19 12v-3h10v3"/><path d="M20 26h8"/>',
  // 휴지통 (일반쓰레기 표)
  'bin': '<path d="M14 15h20l-1.6 23a3 3 0 0 1-3 2.8H18.6a3 3 0 0 1-3-2.8z" fill="F"/><path d="M14 15h20l-1.6 23a3 3 0 0 1-3 2.8H18.6a3 3 0 0 1-3-2.8z"/><path d="M10 15h28"/><path d="M19 15v-3a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v3"/><path d="M21 21v13M27 21v13"/>',
  // 확성기
  'mega': '<path d="M8 20h7l16-9v26l-16-9H8z" fill="F"/><path d="M8 20h7l16-9v26l-16-9H8z"/><path d="M15 28l3 10h5l-2-9"/><path d="M36 18l4-3M37 24h5M36 30l4 3"/>',
  // 바꾸기 화살표
  'swap': '<path d="M10 17h28M31 10l7 7-7 7"/><path d="M38 31H10M17 24l-7 7 7 7"/>',
  // 달력
  'cal': '<rect x="8" y="11" width="32" height="29" rx="4" fill="F"/><rect x="8" y="11" width="32" height="29" rx="4"/><path d="M8 19h32M16 7v7M32 7v7"/><path d="M15 26h3M23 26h3M31 26h3M15 33h3M23 33h3"/>',
  // 수거 없는 날
  'calx': '<rect x="8" y="11" width="32" height="29" rx="4" fill="F"/><rect x="8" y="11" width="32" height="29" rx="4"/><path d="M8 19h32M16 7v7M32 7v7"/><path d="M19 25l10 9M29 25l-10 9"/>',
  // 화살표
  'arrow': '<path d="M12 24h24M27 15l9 9-9 9"/>',
  // 찾기
  'search': '<circle cx="21" cy="21" r="12"/><path d="M30 30l10 10"/>',
  // 장소
  'pin': '<path d="M24 41s-11-10-11-19a11 11 0 0 1 22 0c0 9-11 19-11 19z" fill="F"/><path d="M24 41s-11-10-11-19a11 11 0 0 1 22 0c0 9-11 19-11 19z"/><circle cx="24" cy="22" r="4"/>',
  // 시계
  'time': '<circle cx="24" cy="24" r="15" fill="F"/><circle cx="24" cy="24" r="15"/><path d="M24 15v9l6 4"/>',
  // 쉬는 날
  'off': '<rect x="9" y="11" width="30" height="28" rx="3" fill="F"/><rect x="9" y="11" width="30" height="28" rx="3"/><path d="M9 19h30M17 8v6M31 8v6"/><path d="M19 26l10 8M29 26l-10 8"/>',
  // 전화
  'phone': '<path d="M15 8l5 9-3.5 3c2 4.5 6 8.5 10.5 10.5l3-3.5 9 5-2 6c-14 1-27-12-26-26z" fill="F"/><path d="M15 8l5 9-3.5 3c2 4.5 6 8.5 10.5 10.5l3-3.5 9 5-2 6c-14 1-27-12-26-26z"/>',
  // 고치기
  'edit': '<path d="M30 10l8 8-19 19H11v-8z" fill="F"/><path d="M30 10l8 8-19 19H11v-8z"/><path d="M26 14l8 8"/>',
};

class TrashIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color line;
  final Color fill;
  final double weight; // 선 굵기 (48칸 기준)
  const TrashIcon(this.name, {super.key, this.size = 24, this.line = kInk, this.fill = kSoft, this.weight = 1.6});

  @override
  Widget build(BuildContext context) {
    String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final fo = fill.a < 0.99 ? ' fill-opacity="${fill.a.toStringAsFixed(2)}"' : '';
    final svg = '$_head${_body[name] ?? _body['g']!}</svg>'.replaceAll('"L"', '"${hex(line)}"').replaceAll('fill="F"', 'fill="${hex(fill)}"$fo').replaceAll('stroke-width="1.6"', 'stroke-width="$weight"');
    return SvgPicture.string(svg, width: size, height: size);
  }
}
