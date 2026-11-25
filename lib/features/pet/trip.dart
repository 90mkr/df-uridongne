// 같이 갈 수 있는 곳 — 한국관광공사 반려동물 동반여행 (반려동물 테마 방)
// 「우리 동네」(10km) ↔ 「주말 나들이」(60km), 관광지·숙소·식당카페·쇼핑 거르기, 지도 먼저
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/feature.dart';
import '../../core/icons.dart';
import '../../core/map.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';
import 'places.dart';

class PetTripPage extends StatefulWidget {
  final Complex complex;
  const PetTripPage({super.key, required this.complex});
  @override
  State<PetTripPage> createState() => _PetTripPageState();
}

class _PetTripPageState extends State<PetTripPage> {
  bool loading = true, map = false, far = false; // 카드 먼저 (대표님 11-26)
  TripKind kind = TripKind.all;
  List<(Trip, double)> all = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    var v = await tripsNear(widget.complex.pos, km: far ? 60 : 10);
    if (!far && v.length < 4) {
      // 동네에 거의 없으면 바로 나들이 범위로
      far = true;
      v = await tripsNear(widget.complex.pos, km: 60);
    }
    if (!mounted) return;
    setState(() {
      all = v;
      loading = false;
    });
  }

  List<(Trip, double)> get list => kind == TripKind.all ? all : all.where((x) => x.$1.kind == kind).toList();

  @override
  Widget build(BuildContext context) {
    final l = list;
    return DetailPage(
      title: '같이 갈 수 있는 곳',
      icon: 'event',
      actions: [
        if (!loading && all.isNotEmpty)
          TextButton(onPressed: () => setState(() => map = !map), child: Text(map ? '목록 보기' : '지도 보기', style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Seg(far: far, onChange: (v) {
              far = v;
              _load();
            }),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final k in kTripKinds) ...[
                  ChoiceChipBox(
                      k.$1 == TripKind.all ? k.$2 : '${k.$2} ${all.where((x) => x.$1.kind == k.$1).length}',
                      on: kind == k.$1,
                      onTap: () => setState(() => kind = k.$1)),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
          ]),
        ),
        Container(height: 1, color: kLine),
        Expanded(
          child: loading
              ? const PetLoading('반려동물과 갈 수 있는 곳을 모으고 있어요')
              : l.isEmpty
                  ? const PetEmpty('이 범위에는 아직 등록된 곳이 없어요')
                  : map
                      ? DongneMap(
                          key: ValueKey('trip-$far-$kind'),
                          center: widget.complex.pos,
                          zoom: far ? 10 : 13,
                          icon: 'pet',
                          points: [
                            for (final x in l.take(250))
                              MapPoint(
                                  id: 'trip_${x.$1.id}',
                                  name: x.$1.title,
                                  sub: '${x.$1.kindName} · ${distText(x.$2)}',
                                  pos: x.$1.pos,
                                  onTap: (ctx) => showTrip(ctx, x.$1, x.$2)),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(kPad, 6, kPad, 30),
                          itemCount: l.length.clamp(0, 120) + 1,
                          itemBuilder: (ctx, i) => i == l.length.clamp(0, 120)
                              ? const Padding(padding: EdgeInsets.only(top: 14), child: Text('한국관광공사 반려동물 동반여행 자료예요. 동반 조건은 바뀔 수 있으니 가기 전에 확인해 주세요.', style: T.tiny))
                              : _TripRow(t: l[i].$1, m: l[i].$2),
                        ),
        ),
      ]),
    );
  }
}

// 「우리 동네 · 주말 나들이」 두 칸 (붙은 네모 탭)
class _Seg extends StatelessWidget {
  final bool far;
  final ValueChanged<bool> onChange;
  const _Seg({required this.far, required this.onChange});
  @override
  Widget build(BuildContext context) {
    Widget one(String t, String s, bool on, bool v) => Expanded(
          child: GestureDetector(
            onTap: () => onChange(v),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? kInk : Colors.white),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : kInk)),
                TextSpan(text: '  $s', style: TextStyle(fontSize: 11, color: on ? Colors.white70 : kSub)),
              ])),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [one('우리 동네', '10km', !far, false), Container(width: 1, height: 40, color: kLine), one('주말 나들이', '60km', far, true)]),
    );
  }
}

Widget _thumb(String url, double w, double h) {
  Widget ph() => Container(width: w, height: h, color: const Color(0xFFF1F3F6), alignment: Alignment.center, child: const LineIcon('pet', size: 26));
  if (url.isEmpty) return ph();
  return Image.network(url, width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph(),
      webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never);
}

class _TripRow extends StatelessWidget {
  final Trip t;
  final double m;
  const _TripRow({required this.t, required this.m});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => showTrip(context, t, m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: _thumb(t.img, 76, 58)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.kindName, style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title),
                const SizedBox(height: 2),
                Text('${distText(m)} · ${t.addr}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
          ]),
        ),
      );
}

Future<void> showTrip(BuildContext context, Trip t, double m) => showSheet(context, (ctx) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kPad, 14, kPad, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (t.img.isNotEmpty) ...[
            ClipRRect(borderRadius: BorderRadius.circular(12), child: _thumb(t.img, double.infinity, 170)),
            const SizedBox(height: 12),
          ],
          Text(t.kindName, style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(t.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('${distText(m)} · ${t.addr}', style: T.small),
          const SizedBox(height: 12),
          const MixTitle('반려동물', '동반 조건', size: 14.5),
          const SizedBox(height: 4),
          FutureBuilder<List<(String, String)>?>(
            future: tripDetail(t.id),
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('불러오는 중…', style: T.small));
              final d = s.data;
              if (d == null || d.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('자세한 동반 조건은 전화로 확인해 주세요.', style: T.small));
              return Column(children: [
                for (final x in d)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 92, child: Text(x.$1, style: T.small)),
                      Expanded(child: Text(x.$2, style: T.body)),
                    ]),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 14),
          Row(children: [
            if (t.tel.isNotEmpty) ...[Expanded(child: Btn('전화', icon: 'phone', onTap: () => callTel(t.tel.split(RegExp(r'[,/]')).first))), const SizedBox(width: 10)],
            Expanded(child: Btn('길안내', icon: 'route', primary: true, onTap: () => startNav(ctx, name: t.title, lat: t.pos.latitude, lng: t.pos.longitude))),
          ]),
          const SizedBox(height: 10),
          const Text('한국관광공사 반려동물 동반여행 자료 · 조건은 바뀔 수 있어요', style: T.tiny),
        ]),
      );
    });
