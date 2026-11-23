// 날씨·미세먼지 (이 폴더는 날씨 담당 방만 고침)
//  ─ 단지 홈 머리 줄: 하늘 그림 · 기온 · 미세먼지 등급 (누르면 상세)
//  ─ 상세: 지금 날씨 → 미세먼지 → 오늘 생활 안내 → 시간별 → 내일·모레
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'api.dart';
import 'sky.dart';

class WeatherFeature extends Feature {
  @override
  String get id => 'weather';
  @override
  String get name => '날씨·미세먼지';
  @override
  String get icon => 'weather';
  @override
  Slot get slot => Slot.header;
  @override
  int get order => 10;
  @override
  String get version => '0.2.0';
  @override
  bool get ready => true;
  @override
  Color get tint => kSoftYellow;

  @override
  Widget? homeCard(BuildContext context, Complex c) => _HeadChip(key: ValueKey('wx_${c.id}'), c: c, onTap: () => openFeature(context, this));

  @override
  Widget page(BuildContext context, Complex c) => _WeatherPage(c: c);
}

String _deg(double? t) => t == null ? '-' : '${t.round()}°';

// ---------------- 머리 줄 작은 표시 ----------------

class _HeadChip extends StatefulWidget {
  final Complex c;
  final VoidCallback onTap;
  const _HeadChip({super.key, required this.c, required this.onTap});
  @override
  State<_HeadChip> createState() => _HeadChipState();
}

class _HeadChipState extends State<_HeadChip> {
  Weather? w;
  @override
  void initState() {
    super.initState();
    w = cachedWeather(widget.c);
    weatherFor(widget.c).then((v) {
      if (mounted && v != null) setState(() => w = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = w?.dust;
    final al = w?.alert;
    final ac = al == null ? null : alertColor(al);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: ac?.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac?.withValues(alpha: 0.45) ?? kLine),
          ),
          child: w == null
              ? const Row(mainAxisSize: MainAxisSize.min, children: [
                  LineIcon('weather', size: 17, line: kMute, fill: kSoftYellow),
                  SizedBox(width: 5),
                  Text('날씨', style: TextStyle(fontSize: 11, color: kMute)),
                ])
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  SkyIcon(w!.sky, size: 20, night: isNightHour(w!.at)),
                  const SizedBox(width: 3),
                  Text(_deg(w!.temp), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  if (al != null) ...[
                    Container(width: 1, height: 11, margin: const EdgeInsets.symmetric(horizontal: 7), color: ac!.withValues(alpha: 0.35)),
                    Text(al.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ac)),
                  ] else if (d != null && d.worst > 0) ...[
                    Container(width: 1, height: 11, margin: const EdgeInsets.symmetric(horizontal: 7), color: kLine),
                    const Text('미세 ', style: TextStyle(fontSize: 11, color: kSub)),
                    Text(gradeText[d.worst], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gradeColor(d.worst))),
                  ],
                ]),
        ),
      ),
    );
  }
}

// ---------------- 상세 화면 ----------------

class _WeatherPage extends StatefulWidget {
  final Complex c;
  const _WeatherPage({required this.c});
  @override
  State<_WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<_WeatherPage> {
  Weather? w;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    w = cachedWeather(widget.c);
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => loading = true);
    final v = await weatherFor(widget.c, force: force);
    if (!mounted) return;
    setState(() {
      w = v ?? w;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      title: '날씨·미세먼지',
      icon: 'weather',
      white: false,
      actions: [
        IconButton(
          tooltip: '새로 받기',
          onPressed: loading ? null : () => _load(force: true),
          icon: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.6))
              : const Icon(Icons.refresh_rounded, size: 22),
        ),
      ],
      body: w == null
          ? Center(
              child: loading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const LineIcon('weather', size: 54, fill: kSoftYellow),
                        const SizedBox(height: 14),
                        const Text('날씨를 받지 못했어요', style: T.h2),
                        const SizedBox(height: 6),
                        Text(lastWeatherError.isEmpty ? '잠시 뒤 다시 눌러 주세요.' : '잠시 뒤 다시 눌러 주세요.\n($lastWeatherError)', textAlign: TextAlign.center, style: T.small),
                        const SizedBox(height: 16),
                        SizedBox(width: 160, child: Btn('다시 받기', onTap: () => _load(force: true))),
                      ]),
                    ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 30),
                children: [
                  if (w!.alert != null) ...[_AlertBar(a: w!.alert!), const SizedBox(height: 14)],
                  _Now(w: w!, c: widget.c),
                  const SizedBox(height: 14),
                  if (w!.hours.isNotEmpty) ...[_HoursCard(hours: _withNow(w!)), const SizedBox(height: 12)],
                  if (w!.days.length > 1) ...[_DaysCard(days: w!.days), const SizedBox(height: 12)],
                  if (w!.dust != null || w!.dustDays.isNotEmpty) ...[_DustCard(d: w!.dust, days: w!.dustDays), const SizedBox(height: 12)],
                  _LifeCard(w: w!),
                  const SizedBox(height: 12),
                  const _AlarmCard(),
                  const SizedBox(height: 14),
                  Text(
                    '${w!.source == '기상청' ? '날씨·특보·생활지수 기상청 · 미세먼지 에어코리아' : '날씨·미세먼지 ${w!.source}'}'
                    ' · ${_2(w!.at.hour)}:${_2(w!.at.minute)} 받음\n실시간 측정값은 확정 전 자료라 나중에 바뀔 수 있어요.',
                    style: T.tiny,
                  ),
                ],
              ),
            ),
    );
  }
}

String _2(int v) => v.toString().padLeft(2, '0');

// 시간별 첫 칸(지금)은 예보 대신 지금 관측값으로 — 위 큰 숫자와 어긋나지 않게
List<Hour> _withNow(Weather w) {
  final h = w.hours.first;
  return [Hour(h.t, temp: w.temp ?? h.temp, sky: w.sky, pop: h.pop, rain: h.rain, hum: w.hum, wind: w.wind), ...w.hours.skip(1)];
}

// 지금 날씨 (상자 없이 바탕 위에 크게)
class _Now extends StatelessWidget {
  final Weather w;
  final Complex c;
  const _Now({required this.w, required this.c});

  @override
  Widget build(BuildContext context) {
    final td = w.today;
    final feels = w.feels;
    final stats = <(String, String)>[
      if (feels != null) ('체감', _deg(feels)),
      if (w.hum != null) ('습도', '${w.hum}%'),
      if (w.wind != null) ('바람', '${w.wind!.toStringAsFixed(1)}m/s'),
      ('강수', (w.rain1h ?? 0) > 0 ? '${w.rain1h!.toStringAsFixed(w.rain1h! < 1 ? 1 : 0)}mm' : '없음'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${c.town.isNotEmpty ? '${c.town} · ' : ''}${c.name} 기준', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: w.temp == null ? '-' : '${w.temp!.round()}', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w300, letterSpacing: -2, height: 1)),
              const TextSpan(text: '°', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, height: 1)),
              TextSpan(text: '  ${skyText(w.sky)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            ])),
            const SizedBox(height: 6),
            if (td != null)
              Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: kSub), children: [
                const TextSpan(text: '최저 '),
                TextSpan(text: _deg(td.min), style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
                const TextSpan(text: '   최고 '),
                TextSpan(text: _deg(td.max), style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
                if (td.min != null && td.max != null && td.max! - td.min! >= 10) const TextSpan(text: '   일교차 커요'),
              ])),
          ]),
        ),
        SkyIcon(w.sky, size: 78, night: isNightHour(w.at)),
      ]),
      const SizedBox(height: 12),
      // 습도·바람·강수 한 줄 (상자 대신 가는 칸막이)
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 12), color: kLine),
            Text(stats[i].$1, style: const TextStyle(fontSize: 11.5, color: kSub)),
            const SizedBox(width: 5),
            Text(stats[i].$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    ]);
  }
}

// ---------------- 미세먼지 ----------------

class _DustCard extends StatelessWidget {
  final Dust? d;
  final List<DustDay> days;
  const _DustCard({required this.d, required this.days});

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final d = this.d;
    final where = d == null
        ? ''
        : [
            if (d.approx) '모델 추정값' else if (d.station.isNotEmpty) '측정소 ${d.station}',
            if (d.time.length >= 13) '${d.time.substring(11)} 측정',
          ].join(' · ');
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    String label(DateTime t) {
      final diff = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff == 0 ? '오늘' : diff == 1 ? '내일' : diff == 2 ? '모레' : _wd[t.weekday - 1];
    }

    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const MixTitle('미세먼지', '지금·예보', size: 14),
          const Spacer(),
          if (where.isNotEmpty) Text(where, style: T.tiny),
        ]),
        if (d != null) ...[
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _Gauge(label: '미세먼지', sub: 'PM10', value: d.pm10, grade: d.g10, max: 150)),
              Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: kLine),
              Expanded(child: _Gauge(label: '초미세먼지', sub: 'PM2.5', value: d.pm25, grade: d.g25, max: 75)),
            ]),
          ),
          if (d.gO3 >= 3) ...[
            const SizedBox(height: 8),
            Text('오존 ${gradeText[d.gO3]} · 한낮 바깥 활동 줄이기', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: gradeColor(d.gO3))),
          ],
        ],
        if (days.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: kLine),
          const SizedBox(height: 10),
          // 요일별 예보: 왼쪽 줄 이름 + 옆으로 넘기는 칸
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(
              width: 44,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 20),
                SizedBox(height: 20, child: Text('미세', style: TextStyle(fontSize: 11, color: kSub))),
                SizedBox(height: 20, child: Text('초미세', style: TextStyle(fontSize: 11, color: kSub))),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final x in days)
                    SizedBox(
                      width: 52,
                      child: Column(children: [
                        SizedBox(height: 20, child: Text(label(x.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(height: 20, child: _gradeCell(x.g10, '')),
                        SizedBox(height: 20, child: _gradeCell(x.g25, x.week25)),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          const Text('3일 뒤부터는 초미세먼지만 「낮음·높음」으로 예보돼요.', style: T.tiny),
        ],
      ]),
    );
  }

  Widget _gradeCell(int g, String week) {
    if (g > 0) {
      return Text(gradeText[g], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: gradeColor(g)));
    }
    if (week.isNotEmpty) {
      return Text(week, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: week == '높음' ? gradeColor(3) : gradeColor(1)));
    }
    return const Text('-', style: TextStyle(fontSize: 11.5, color: kMute));
  }
}

class _Gauge extends StatelessWidget {
  final String label, sub;
  final int? value;
  final int grade;
  final int max;
  const _Gauge({required this.label, required this.sub, required this.value, required this.grade, required this.max});

  @override
  Widget build(BuildContext context) {
    final col = gradeColor(grade);
    final pos = value == null ? null : (value! / max).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        TextSpan(text: '  $sub', style: const TextStyle(fontSize: 10, color: kMute)),
      ])),
      const SizedBox(height: 5),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(gradeText[grade], style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: col, height: 1.1)),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(value == null ? '' : '$value㎍/㎥', style: const TextStyle(fontSize: 11, color: kSub)),
        ),
      ]),
      const SizedBox(height: 9),
      // 네 칸 막대 + 지금 위치 표시
      LayoutBuilder(builder: (context, box) {
        final wdt = box.maxWidth;
        return SizedBox(
          height: 12,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 4,
              child: Row(children: [
                for (var g = 1; g <= 4; g++) ...[
                  if (g > 1) const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: gradeColor(g).withValues(alpha: g == grade ? 0.85 : 0.18), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ],
              ]),
            ),
            if (pos != null)
              Positioned(
                left: (wdt * _barPos(value!, grade, max) - 6).clamp(0.0, wdt - 12),
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: col, width: 1)),
                ),
              ),
          ]),
        );
      }),
    ]);
  }

  // 등급 칸(4등분) 안에서의 위치
  double _barPos(int v, int g, int max) {
    final cuts = max == 150 ? [0, 30, 80, 150, 250] : [0, 15, 35, 75, 125];
    final gi = g.clamp(1, 4);
    final lo = cuts[gi - 1], hi = cuts[gi];
    final inside = ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
    return ((gi - 1) + inside) / 4;
  }
}

// ---------------- 오늘 생활 안내 ----------------

class _Tip {
  final String icon; // 이 폴더 그림 이름 또는 core 아이콘
  final String title, sub;
  final bool alert; // 꼭 짚을 것 (파랑)
  const _Tip(this.icon, this.title, this.sub, {this.alert = false});
}

List<_Tip> lifeTips(Weather w) {
  final out = <_Tip>[];
  final next12 = w.hours.take(12).toList();
  final next24 = w.hours.take(24).toList();
  final d = w.dust;
  final td = w.today;
  final t = w.feels ?? w.temp;
  final todayDust = w.dustDays.isEmpty ? null : w.dustDays.first;
  final dustNow = d?.worst ?? 0;
  final dustToday = math.max(todayDust?.g10 ?? 0, todayDust?.g25 ?? 0);
  final dustBad = math.max(dustNow, dustToday) >= 3;

  // 우산
  final wet = next12.where((h) => (h.pop ?? 0) >= 60 || isWet(h.sky)).toList();
  if (isWet(w.sky)) {
    out.add(_Tip('umbrella', '우산 챙기세요', '지금 ${skyText(w.sky)} 오고 있어요', alert: true));
  } else if (wet.isNotEmpty) {
    final h = wet.first;
    final what = h.sky == Sky.snow || h.sky == Sky.sleet ? skyText(h.sky) : '비';
    out.add(_Tip('umbrella', '우산 챙기세요', '${_when(h.t)}부터 $what 소식 (${h.pop ?? 0}%)', alert: true));
  } else if (next12.any((h) => (h.pop ?? 0) >= 30)) {
    out.add(const _Tip('umbrella', '작은 우산 있으면 좋아요', '비 올 확률이 조금 있어요'));
  } else {
    out.add(const _Tip('umbrella', '우산은 두고 가도 돼요', '12시간 안에 비 소식이 없어요'));
  }

  // 옷차림
  if (t != null) {
    final c = _clothes(t);
    final gap = td?.min != null && td?.max != null && td!.max! - td.min! >= 10;
    out.add(_Tip('shirt', c.$1, gap ? '일교차가 커요, 겉옷 하나 더' : c.$2));
  }

  // 미세먼지 → 마스크
  if (dustBad) {
    out.add(_Tip('mask', '마스크 챙기세요', math.max(dustNow, dustToday) == 4 ? '바깥 운동은 오늘 쉬어 가세요' : 'KF80 이상이 좋아요', alert: true));
  }

  // 환기 (미세먼지 예보 기준, 한낮이 공기가 잘 섞여 가장 좋음)
  if (d != null || todayDust != null) {
    if (dustBad) {
      out.add(const _Tip('window', '창문은 닫아 두세요', '요리할 땐 3분만 짧게 환기'));
    } else if (isWet(w.sky)) {
      out.add(const _Tip('window', '비 그치면 환기하세요', '하루 세 번, 10분씩'));
    } else {
      out.add(const _Tip('window', '환기 좋은 시간 오후 2~4시', '공기가 잘 섞이는 한낮에 10분씩'));
    }
  }

  // 빨래 (앞으로 비 예보 + 습도)
  final dry = next24.every((h) => (h.pop ?? 0) < 30 && !isWet(h.sky));
  final humid = next24.where((h) => h.t.hour >= 9 && h.t.hour <= 17 && h.hum != null).map((h) => h.hum!).toList();
  final avgHum = humid.isEmpty ? (w.hum ?? 60) : humid.reduce((a, b) => a + b) / humid.length;
  if (dry && avgHum < 65 && !dustBad) {
    out.add(const _Tip('laundry', '빨래 말리기 좋은 날', '바깥에 널어도 잘 말라요'));
  } else {
    final why = next24.any((h) => (h.pop ?? 0) >= 60 || isWet(h.sky))
        ? '비 소식이 있어요'
        : !dry
            ? '비 올 확률이 조금 있어요'
            : dustBad
                ? '미세먼지가 나빠요'
                : '습도가 높아 더디 말라요';
    out.add(_Tip('laundry', '빨래는 실내에서', why));
  }

  // 세차 (앞으로 2~3일)
  final rain3 = w.hours.any((h) => (h.pop ?? 0) >= 60) || w.days.skip(1).take(2).any((x) => x.pop >= 60);
  final rain3some = w.days.skip(1).take(2).any((x) => x.pop >= 40);
  out.add(rain3
      ? const _Tip('car', '세차는 미뤄 두세요', '2~3일 안에 비 소식이 있어요')
      : rain3some
          ? const _Tip('car', '세차는 조금 기다려 보세요', '비 올 확률이 조금 있어요')
          : const _Tip('car', '세차하기 좋은 날', '2~3일 동안 비 소식 없어요'));

  // 자외선 (기상청 생활기상지수)
  final uv = w.uv;
  if (uv != null) {
    out.add(_Tip('sun', '자외선 ${uvText(uv)}', uv >= 6 ? '한낮엔 모자·선크림 챙기세요' : uv >= 3 ? '오래 밖에 있으면 선크림' : '선크림 없어도 괜찮아요', alert: uv >= 8));
  }

  // 동파 (겨울 생활기상지수) · 길 미끄럼 · 폭염
  final fz = w.freeze;
  final low = td?.min;
  if ((fz != null && fz >= 50) || (low != null && low <= -5)) {
    out.add(_Tip('thermo', '동파 조심하세요', (fz ?? 0) >= 75 || (low ?? 0) <= -10 ? '수도꼭지를 조금 틀어 두세요' : '수도·보일러 배관을 살펴 주세요', alert: true));
  } else if (t != null && t <= 1 && (isWet(w.sky) || next12.any((h) => isWet(h.sky)))) {
    out.add(const _Tip('thermo', '길이 미끄러워요', '계단·단지 경사로 조심', alert: true));
  } else if ((td?.max ?? 0) >= 33) {
    out.add(const _Tip('thermo', '무더위 조심하세요', '한낮 바깥 활동은 줄이세요', alert: true));
  }
  return out;
}

String _when(DateTime t) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 9));
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final pre = day.isAfter(today) ? '내일 ' : '';
  final h = t.hour;
  final part = h == 0 ? '밤 12시' : h < 12 ? '오전 $h시' : h == 12 ? '낮 12시' : '오후 ${h - 12}시';
  return '$pre$part';
}

(String, String) _clothes(double t) {
  if (t <= -5) return ('두꺼운 패딩·목도리', '장갑까지 챙기세요');
  if (t <= 4) return ('패딩이나 두꺼운 코트', '목도리가 있으면 좋아요');
  if (t <= 8) return ('코트에 니트', '안에 얇은 내복도 좋아요');
  if (t <= 11) return ('자켓·트렌치코트', '안에 니트나 맨투맨');
  if (t <= 16) return ('가벼운 자켓·가디건', '아침저녁엔 쌀쌀해요');
  if (t <= 19) return ('얇은 니트·맨투맨', '활동하기 좋은 날씨');
  if (t <= 22) return ('긴팔에 얇은 겉옷', '한낮엔 따뜻해요');
  if (t <= 27) return ('반팔·얇은 셔츠', '가볍게 입으세요');
  return ('반팔·민소매', '물 자주 드세요');
}

// 생활 안내 그림 (이 폴더 안 임시 그림)
const _tipSvg = <String, String>{
  'umbrella': '<path d="M7 24a17 17 0 0 1 34 0c-2-2-5-2-6 0-2-2-5-2-6 0-2-2-5-2-6 0-2-2-5-2-6 0-2-2-5-2-6 0z" fill="F"/><path d="M24 24v13a3 3 0 0 1-6 0"/><path d="M24 7v2"/>',
  'shirt': '<path d="M17 8l-9 5 3 8 5-2v20h16V19l5 2 3-8-9-5c-1 3-4 5-7 5s-6-2-7-5z" fill="F"/>',
  'mask': '<path d="M12 17c8-4 16-4 24 0v10c-4 7-20 7-24 0z" fill="F"/><path d="M12 19c-5 0-6 8 0 9M36 19c5 0 6 8 0 9M17 21h14M17 26h14"/>',
  'window': '<rect x="10" y="8" width="28" height="32" rx="2" fill="F"/><path d="M24 8v32M10 24h28"/><path d="M15 14c2 1 4 1 6 0M27 30c2 1 4 1 6 0"/>',
  'sun': '<circle cx="24" cy="24" r="7" fill="F"/><path d="M24 9v4M24 35v4M9 24h4M35 24h4M13.4 13.4l2.8 2.8M31.8 31.8l2.8 2.8M13.4 34.6l2.8-2.8M31.8 16.2l2.8-2.8"/>',
  'thermo': '<path d="M20 28V11a4 4 0 0 1 8 0v17a7 7 0 1 1-8 0z" fill="F"/><path d="M24 33V18"/><path d="M32 14h4M32 19h3M32 24h4"/>',
};

class _TipIcon extends StatelessWidget {
  final String name;
  const _TipIcon(this.name);
  @override
  Widget build(BuildContext context) {
    final b = _tipSvg[name];
    if (b == null) return LineIcon(name, size: 26, fill: kSoft);
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="#17181c" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
        '${b.replaceAll('fill="F"', 'fill="#E8EEFF"')}</svg>';
    return SvgPicture.string(svg, width: 26, height: 26);
  }
}

class _LifeCard extends StatelessWidget {
  final Weather w;
  const _LifeCard({required this.w});

  @override
  Widget build(BuildContext context) {
    final tips = lifeTips(w);
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MixTitle('오늘', '생활 지수', size: 14),
        const SizedBox(height: 6),
        // 짧은 글이라 휴대폰에서도 두 칸씩
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 520 ? 3 : 2;
          final cw = (box.maxWidth - (cols - 1) * 14) / cols - 0.5;
          return Wrap(spacing: 14, children: [
            for (final t in tips)
              SizedBox(
                width: cw,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _TipIcon(t.icon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.title,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.3, color: t.alert ? kBlue : kInk)),
                        const SizedBox(height: 1),
                        Text(t.sub, style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

// ---------------- 시간별 (옆으로 밀기) ----------------

class _HoursCard extends StatelessWidget {
  final List<Hour> hours;
  const _HoursCard({required this.hours});

  static const _cw = 50.0;

  @override
  Widget build(BuildContext context) {
    final temps = hours.map((h) => h.temp).toList();
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: MixTitle('시간별', '예보', size: 14)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: _cw * hours.length,
            child: Column(children: [
              Row(children: [
                for (var i = 0; i < hours.length; i++)
                  SizedBox(
                    width: _cw,
                    child: Column(children: [
                      Text(_label(hours, i),
                          style: TextStyle(fontSize: 11, color: i == 0 ? kInk : kSub, fontWeight: i == 0 || hours[i].t.hour == 0 ? FontWeight.w700 : FontWeight.w400)),
                      const SizedBox(height: 4),
                      SkyIcon(hours[i].sky, size: 28, night: isNightHour(hours[i].t)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 4),
              // 기온 꺾은선
              SizedBox(height: 48, width: _cw * hours.length, child: CustomPaint(painter: _TempLine(temps, _cw))),
              Row(children: [
                for (final h in hours)
                  SizedBox(
                    width: _cw,
                    child: Column(children: [
                      Text((h.pop ?? 0) >= 20 ? '${h.pop}%' : '', style: TextStyle(fontSize: 10.5, color: (h.pop ?? 0) >= 60 ? kInk : kMute, fontWeight: FontWeight.w600)),
                      if (h.rain.isNotEmpty) Text(h.rain, style: const TextStyle(fontSize: 9.5, color: kMute)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  String _label(List<Hour> hs, int i) {
    if (i == 0) return '지금';
    final h = hs[i].t.hour;
    if (h == 0) return '내일';
    return '$h시';
  }
}

class _TempLine extends CustomPainter {
  final List<double?> temps;
  final double cw;
  _TempLine(this.temps, this.cw);

  @override
  void paint(Canvas canvas, Size size) {
    final vs = temps.whereType<double>().toList();
    if (vs.isEmpty) return;
    final lo = vs.reduce(math.min), hi = vs.reduce(math.max);
    final span = math.max(hi - lo, 4.0);
    const top = 16.0, bottom = 6.0;
    double y(double t) => top + (size.height - top - bottom) * (1 - (t - lo) / span);
    final line = Paint()
      ..color = const Color(0xFFB8BEC9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    var started = false;
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) continue;
      final p = Offset(cw * i + cw / 2, y(t));
      started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      started = true;
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = kInk;
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) continue;
      final p = Offset(cw * i + cw / 2, y(t));
      canvas.drawCircle(p, 2.2, dot);
      final tp = TextPainter(
        text: TextSpan(text: '${t.round()}°', style: const TextStyle(fontFamily: 'Pretendard', fontSize: 11.5, fontWeight: FontWeight.w700, color: kInk)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 3));
    }
  }

  @override
  bool shouldRepaint(covariant _TempLine old) => old.temps != temps;
}

// ---------------- 이번 주 (최대 10일) ----------------

class _DaysCard extends StatelessWidget {
  final List<Day> days;
  const _DaysCard({required this.days});

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final all = [for (final d in days) ...[d.min, d.max]].whereType<double>().toList();
    final lo = all.isEmpty ? 0.0 : all.reduce(math.min), hi = all.isEmpty ? 1.0 : all.reduce(math.max);
    return Container(
      decoration: cardBox(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const MixTitle('이번 주', '날씨', size: 14),
          const Spacer(),
          Text('${days.length}일 예보', style: T.tiny),
        ]),
        const SizedBox(height: 4),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) Container(height: 1, color: const Color(0xFFF0F1F4)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: i == 0 ? '오늘' : i == 1 ? '내일' : _wd[days[i].date.weekday - 1],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' ${days[i].date.month}.${days[i].date.day}', style: const TextStyle(fontSize: 10.5, color: kMute)),
                ])),
              ),
              SkyIcon(days[i].am, size: 24),
              const SizedBox(width: 2),
              SkyIcon(days[i].pm, size: 24),
              SizedBox(
                width: 34,
                child: Text(days[i].pop >= 20 ? '${days[i].pop}%' : '',
                    textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: days[i].pop >= 60 ? kInk : kSub, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 28, child: Text(_deg(days[i].min), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: kSub))),
              const SizedBox(width: 8),
              Expanded(child: _range(days[i], lo, hi)),
              const SizedBox(width: 8),
              SizedBox(width: 28, child: Text(_deg(days[i].max), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _range(Day d, double lo, double hi) {
    if (d.min == null || d.max == null || hi <= lo) return const SizedBox(height: 4);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final a = (d.min! - lo) / (hi - lo) * w, b = (d.max! - lo) / (hi - lo) * w;
      return SizedBox(
        height: 4,
        child: Stack(children: [
          Container(decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(2))),
          Positioned(
            left: a,
            width: math.max(b - a, 4),
            top: 0,
            bottom: 0,
            child: Container(decoration: BoxDecoration(color: const Color(0xFF9AA3B2), borderRadius: BorderRadius.circular(2))),
          ),
        ]),
      );
    });
  }
}

// ---------------- 특보 띠 ----------------

Color alertColor(Alert a) => a.kind == '황사'
    ? const Color(0xFFB7791F)
    : a.warning
        ? const Color(0xFFD93A3A)
        : const Color(0xFFE07A10);

String _alertTip(Alert a) => switch (a.kind) {
      '폭염' => '한낮(12~17시) 바깥 활동을 줄이고 물을 자주 드세요.',
      '한파' => '수도·보일러 동파에 조심하고 따뜻하게 입으세요.',
      '호우' => '저지대·하천 주변은 피하고 배수구를 살펴 주세요.',
      '대설' => '눈길 미끄럼에 조심하고 차량 이동을 줄이세요.',
      '황사' => '외출 땐 마스크, 창문은 닫아 두세요.',
      '태풍' => '창문을 단단히 잠그고 바깥 물건을 치워 주세요.',
      '강풍' => '간판·화분 등 날아갈 물건을 살펴 주세요.',
      _ => '불씨 관리에 조심해 주세요.',
    };

class _AlertBar extends StatelessWidget {
  final Alert a;
  const _AlertBar({required this.a});
  @override
  Widget build(BuildContext context) {
    final c = alertColor(a);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.campaign_outlined, size: 19, color: c)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.name} 발효 중', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(_alertTip(a), style: const TextStyle(fontSize: 11.5, color: kSub, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- 아침 알림 설정 ----------------
// 설정만 이 기능이 갖고, 실제 알림 보내기는 본부 공용 알림 기능이 맡는다 (requests/ 에 요청).
//   weather.alarm = '1' | '0',  weather.alarmTime = '07:00'
class _AlarmCard extends StatefulWidget {
  const _AlarmCard();
  @override
  State<_AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<_AlarmCard> {
  bool on = false;
  String time = '07:00';

  @override
  void initState() {
    super.initState();
    () async {
      final a = await prefGet('weather.alarm'), t = await prefGet('weather.alarmTime');
      if (!mounted) return;
      setState(() {
        on = a == '1';
        time = t ?? time;
      });
    }();
  }

  Future<void> _pick() async {
    final p = time.split(':');
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 7, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0),
      helpText: '알림 받을 시각',
    );
    if (r == null) return;
    final v = '${_2(r.hour)}:${_2(r.minute)}';
    await prefSet('weather.alarmTime', v);
    setState(() => time = v);
  }

  String get _timeText {
    final p = time.split(':');
    final h = int.tryParse(p[0]) ?? 7;
    final m = p.length > 1 ? p[1] : '00';
    return '${h < 12 ? '오전' : '오후'} ${h == 0 ? 12 : h > 12 ? h - 12 : h}:$m';
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: cardBox(),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          const LineIcon('bell', size: 24, fill: kSoftYellow),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MixTitle('아침', '날씨 알림', size: 13.5),
              const SizedBox(height: 2),
              Text(on ? '$_timeText · 비·미세먼지·특보가 있는 날만 보내요' : '비·미세먼지·특보가 있는 날만 아침에 알려 드려요',
                  style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
            ]),
          ),
          if (on)
            TextButton(
              onPressed: _pick,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 34)),
              child: Text(_timeText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          Switch(
            value: on,
            onChanged: (v) async {
              await prefSet('weather.alarm', v ? '1' : '0');
              setState(() => on = v);
              if (v && context.mounted) toast(context, '알림은 앱 다음 업데이트부터 받아 보실 수 있어요');
            },
          ),
        ]),
      );
}

