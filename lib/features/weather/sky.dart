// 하늘 모양 아이콘 (이 폴더 안에서만 쓰는 임시 그림 — 본부 icons.dart 와 같은 「가는 선 + 옅은 면」 방식)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';
import 'api.dart';

const _head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="#17181c" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';
const _sunFill = '#FFE7A3';
const _cloudFill = '#EEF1F6';
const _dropFill = '#DCE8FF';

const _sun = '<circle cx="24" cy="24" r="8" fill="$_sunFill"/><path d="M24 8v4M24 36v4M8 24h4M36 24h4M12.7 12.7l2.8 2.8M32.5 32.5l2.8 2.8M12.7 35.3l2.8-2.8M32.5 15.5l2.8-2.8"/>';
const _sunSmall = '<circle cx="18" cy="17" r="6" fill="$_sunFill"/><path d="M18 6v3M7 17h3M10.2 9.2l2.1 2.1M25.8 9.2l-2.1 2.1"/>';
const _cloud = '<path d="M14 36h20a7 7 0 0 0 0-14 10 10 0 0 0-19-2 7.5 7.5 0 0 0-1 16z" fill="$_cloudFill"/>';
const _cloudLow = '<path d="M13 31h20a6.5 6.5 0 0 0 0-13 9.5 9.5 0 0 0-18-2 7 7 0 0 0-2 15z" fill="$_cloudFill"/>';
const _cloudBack = '<path d="M30 15a8 8 0 0 1 11 6 5.5 5.5 0 0 1-2 10" fill="none"/>';
const _moon = '<path d="M30 10a14 14 0 1 0 8 25A12 12 0 0 1 30 10z" fill="#FFF1C2"/>';
const _moonSmall = '<path d="M21 6a8.5 8.5 0 1 0 5 15A7 7 0 0 1 21 6z" fill="#FFF1C2"/>';
const _rain = '<path d="M17 36l-2 5M24 36l-2 5M31 36l-2 5" stroke="#2563eb"/>';
const _snow = '<path d="M17 37.5v3M15.5 39h3M28 37.5v3M26.5 39h3" stroke="#6b6f7a"/>';
const _sleet = '<path d="M18 36l-2 5" stroke="#2563eb"/><path d="M28 37.5v3M26.5 39h3" stroke="#6b6f7a"/>';
const _drop = '<path d="M24 34c-3 4-3 6 0 7 3-1 3-3 0-7z" fill="$_dropFill"/>';

String _body(Sky s, bool night) => switch (s) {
      Sky.clear => night ? _moon : _sun,
      Sky.partly => '${night ? _moonSmall : _sunSmall}$_cloud',
      Sky.cloudy => '${night ? _moonSmall : _sunSmall}$_cloud$_cloudBack',
      Sky.overcast => '$_cloudBack$_cloud',
      Sky.rain => '$_cloudLow$_rain',
      Sky.shower => '${night ? _moonSmall : _sunSmall}$_cloudLow$_rain',
      Sky.snow => '$_cloudLow$_snow',
      Sky.sleet => '$_cloudLow$_sleet',
    };

class SkyIcon extends StatelessWidget {
  final Sky sky;
  final double size;
  final bool night;
  const SkyIcon(this.sky, {super.key, this.size = 28, this.night = false});
  @override
  Widget build(BuildContext context) => SvgPicture.string('$_head${_body(sky, night)}</svg>', width: size, height: size);
}

// 밤인지 (서울 기준 달마다 대략의 해 뜨고 지는 시각)
bool isNightHour(DateTime t) {
  const rise = [8, 7, 7, 6, 6, 5, 5, 6, 6, 7, 7, 8];
  const down = [18, 18, 19, 19, 19, 20, 20, 19, 19, 18, 18, 17];
  return t.hour < rise[t.month - 1] || t.hour >= down[t.month - 1];
}

// 미세먼지 등급 색 (우리나라 앱들이 흔히 쓰는 순서: 파랑·초록·주황·빨강) — 글자·점에만 옅게
Color gradeColor(int g) => switch (g) {
      1 => kBlue,
      2 => const Color(0xFF1F9D57),
      3 => const Color(0xFFE07A10),
      4 => const Color(0xFFD93A3A),
      _ => kMute,
    };

// 물방울 (습도·강수 표시용 작은 그림)
const dropSvg = '$_head$_drop</svg>';
