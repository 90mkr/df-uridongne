// 지금 문 연 약국 — 그림 (이 폴더는 약국 담당 방만 고침)
// 약국 건물 · 밤 동네 · 편의점 수레 · 구급상자 · 응급실. 둥근 면 + 옅은 그늘로 입체감만 살짝.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _store = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 150">
  <defs>
    <linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E4EDFF"/></linearGradient>
    <linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6EA8FF"/><stop offset="1" stop-color="#2F6FEA"/></linearGradient>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4ED38A"/><stop offset="1" stop-color="#1FA463"/></linearGradient>
    <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#BFE0FF"/><stop offset="1" stop-color="#7DB6F5"/></linearGradient>
  </defs>
  <ellipse cx="112" cy="138" rx="92" ry="8" fill="#2F6FEA" opacity="0.10"/>
  <!-- 잎 -->
  <path d="M30 128c-8-18 2-36 18-40-2 16-6 30-18 40z" fill="#3CC47A"/>
  <path d="M38 130c4-20 20-30 34-26-8 12-18 22-34 26z" fill="#22A861"/>
  <path d="M196 126c8-16 0-34-14-38 0 14 4 28 14 38z" fill="#3CC47A"/>
  <!-- 건물 -->
  <rect x="58" y="52" width="104" height="80" rx="6" fill="url(#w)"/>
  <rect x="58" y="52" width="104" height="80" rx="6" fill="none" stroke="#C9D8F5"/>
  <!-- 차양 -->
  <path d="M50 52h120l-6 20H56z" fill="url(#b)"/>
  <path d="M62 52l-4 20M82 52l-2 20M102 52v20M122 52l2 20M142 52l4 20" stroke="#FFFFFF" stroke-width="7" opacity="0.9"/>
  <path d="M56 72h108" stroke="#2A5FCF" stroke-width="2"/>
  <!-- 지붕 간판 -->
  <rect x="70" y="30" width="80" height="22" rx="5" fill="#FFFFFF" stroke="#C9D8F5"/>
  <!-- 창·문 -->
  <rect x="68" y="82" width="34" height="30" rx="3" fill="url(#glass)"/>
  <path d="M85 82v30M68 97h34" stroke="#FFFFFF" stroke-width="2"/>
  <rect x="112" y="82" width="38" height="50" rx="3" fill="url(#glass)"/>
  <path d="M131 82v50" stroke="#FFFFFF" stroke-width="2"/>
  <!-- 초록 십자 -->
  <circle cx="110" cy="26" r="20" fill="url(#g)"/>
  <circle cx="110" cy="26" r="20" fill="none" stroke="#FFFFFF" stroke-width="3"/>
  <path d="M110 16v20M100 26h20" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>
  <!-- 알약 -->
  <g transform="rotate(-20 40 126)"><rect x="22" y="119" width="36" height="14" rx="7" fill="#FFFFFF"/><path d="M40 119h11a7 7 0 0 1 0 14H40z" fill="#F26B5B"/></g>
  <!-- 구급 가방 -->
  <rect x="166" y="96" width="38" height="34" rx="6" fill="#FFFFFF" stroke="#C9D8F5"/>
  <path d="M178 96v-6h14v6" fill="none" stroke="#9FB6E0" stroke-width="3"/>
  <path d="M185 104v18M176 113h18" stroke="#22A861" stroke-width="6" stroke-linecap="round"/>
</svg>''';

const _night = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80">
  <defs><linearGradient id="n" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4E7CF0"/><stop offset="1" stop-color="#2346B8"/></linearGradient></defs>
  <path d="M20 80V24a18 18 0 0 1 18-18h64a18 18 0 0 1 18 18v56z" fill="url(#n)"/>
  <path d="M96 14a9 9 0 1 0 8 13 7 7 0 0 1-8-13z" fill="#FFE28A"/>
  <circle cx="40" cy="18" r="1.2" fill="#FFFFFF"/><circle cx="62" cy="12" r="1" fill="#FFFFFF"/><circle cx="80" cy="26" r="1.2" fill="#FFFFFF"/>
  <rect x="30" y="46" width="16" height="34" rx="2" fill="#3460D6"/>
  <rect x="50" y="34" width="20" height="46" rx="2" fill="#2A54C6"/>
  <rect x="74" y="44" width="18" height="36" rx="2" fill="#3460D6"/>
  <rect x="96" y="52" width="16" height="28" rx="2" fill="#2A54C6"/>
  <g fill="#FFD966"><rect x="34" y="52" width="4" height="4"/><rect x="40" y="60" width="4" height="4"/><rect x="55" y="40" width="4" height="4"/><rect x="62" y="48" width="4" height="4"/><rect x="55" y="58" width="4" height="4"/><rect x="78" y="50" width="4" height="4"/><rect x="85" y="58" width="4" height="4"/><rect x="100" y="58" width="4" height="4"/></g>
</svg>''';

const _cart = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 9h6l5 22h21l4-14H12" stroke="#1E2A4A" stroke-width="2.4"/>
  <circle cx="18" cy="38" r="3" stroke="#1E2A4A" stroke-width="2.4"/><circle cx="33" cy="38" r="3" stroke="#1E2A4A" stroke-width="2.4"/>
  <circle cx="31" cy="14" r="9" fill="#22A861"/><path d="M31 9.5v9M26.5 14h9" stroke="#FFFFFF" stroke-width="2.6"/>
</svg>''';

const _kit = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <path d="M18 12V8h12v4" stroke="#1E2A4A" stroke-width="2.4"/>
  <rect x="5" y="12" width="38" height="28" rx="5" fill="#EAF1FF" stroke="#1E2A4A" stroke-width="2.4"/>
  <path d="M24 19v14M17 26h14" stroke="#F0473C" stroke-width="4"/>
</svg>''';

const _er = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <rect x="9" y="8" width="30" height="34" rx="5" fill="#FFFFFF" stroke="#1E2A4A" stroke-width="2.4"/>
  <path d="M18 8V5h12v3" stroke="#1E2A4A" stroke-width="2.4"/>
  <path d="M24 17v14M17 24h14" stroke="#F0473C" stroke-width="4"/>
</svg>''';

class Art extends StatelessWidget {
  final String name;
  final double w, h;
  const Art(this.name, {super.key, required this.w, required this.h});
  @override
  Widget build(BuildContext context) => SvgPicture.string(
        switch (name) {
          'store' => _store,
          'night' => _night,
          'cart' => _cart,
          'kit' => _kit,
          _ => _er,
        },
        width: w,
        height: h,
      );
}
