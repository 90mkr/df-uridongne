// 하늘 모양 아이콘 · 등급 색 · 밤 판단
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'api.dart';

const _head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="#17181c" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';
const _dropFill = '#DCE8FF';
const _drop = '<path d="M24 34c-3 4-3 6 0 7 3-1 3-3 0-7z" fill="$_dropFill"/>';

// 하늘 모양 아이콘 — 대표님이 고른 입체 날씨 그림 세트 (assets/art/wx_*.png, 11-26)
String skyAsset(Sky s, bool night) => 'assets/art/wx_${switch (s) {
      Sky.clear => night ? 'moon' : 'sun',
      Sky.partly => night ? 'moon_cloud' : 'sun_cloud',
      Sky.cloudy => night ? 'moon_cloud2' : 'cloud_sun',
      Sky.overcast => 'overcast',
      Sky.rain => 'rain',
      Sky.shower => 'rain_heavy',
      Sky.snow => 'snow',
      Sky.sleet => 'sleet',
    }}.png';

class SkyIcon extends StatelessWidget {
  final Sky sky;
  final double size;
  final bool night;
  const SkyIcon(this.sky, {super.key, this.size = 28, this.night = false});
  @override
  Widget build(BuildContext context) =>
      Image.asset(skyAsset(sky, night), width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
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
