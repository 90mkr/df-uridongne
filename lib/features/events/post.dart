// 「행사 알리기」 (2단계): 이웃·관리사무소·사장님이 동네 행사를 올림 → 관리자 승인 뒤 공개
// 사진 1~3장: 휴대폰에서 바로 줄임(약 80KB) · 얼굴이 크게 나온 사진은 막음(안드로이드 기본 얼굴 찾기, 콕플과 같은 방식)
// 장소: 지도를 움직여 가운데 핀으로 고름
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';
import '../../core/dnmap.dart';
import '../../core/fb.dart';
import '../../core/me.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'data.dart';

const _photoCh = MethodChannel('dongne/photo');

class _Photo {
  final Uint8List full, thumb;
  _Photo(this.full, this.thumb);
}

/// 사진 고르기 → 줄이기 → 얼굴 검사. 얼굴이 크면 'face' 를 돌려줌
Future<(_Photo?, String?)> _pick() async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (x == null) return (null, null);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final m = await _photoCh.invokeMapMethod<String, dynamic>('prep', {'path': x.path, 'full': 960, 'thumb': 320});
        if (m != null && m['full'] is Uint8List && m['thumb'] is Uint8List) {
          if (m['faceBig'] == true) return (null, 'face');
          return (_Photo(m['full'] as Uint8List, m['thumb'] as Uint8List), null);
        }
      } catch (_) {}
    }
    // 웹·예전 앱: 다시 작게 골라 줄임 (얼굴 검사는 관리자 승인 때 눈으로)
    final small = await x.readAsBytes();
    if (small.length > 160 * 1024) return (null, 'big');
    return (_Photo(small, small), null);
  } catch (_) {
    return (null, null);
  }
}

Future<bool?> openPost(BuildContext context, Complex c) async {
  if (me == null) {
    toast(context, '로그인하면 행사를 알릴 수 있어요');
    await openLogin(context);
    if (me == null || !context.mounted) return null;
  }
  return Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _PostPage(c: c)));
}

class _PostPage extends StatefulWidget {
  final Complex c;
  const _PostPage({required this.c});
  @override
  State<_PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<_PostPage> {
  final title = TextEditingController(), time = TextEditingController(), place = TextEditingController(), desc = TextEditingController(), fee = TextEditingController();
  late DateTime start, end;
  LatLng? pos;
  String scope = 'apt';
  final photos = <_Photo>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final t = DateTime.now();
    start = DateTime(t.year, t.month, t.day);
    end = start;
  }

  String _d(DateTime d) => '${d.month}월 ${d.day}일 (${'월화수목금토일'[d.weekday - 1]})';

  Future<void> _date(bool isStart) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: isStart ? start : end,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      if (isStart) {
        start = d;
        if (end.isBefore(d)) end = d;
      } else {
        end = d.isBefore(start) ? start : d;
      }
    });
  }

  Future<void> _addPhoto() async {
    final (p, err) = await _pick();
    if (!mounted) return;
    if (err == 'face') return toast(context, '사람 얼굴이 크게 나온 사진은 올릴 수 없어요. 행사장·포스터 사진을 골라 주세요');
    if (err == 'big') return toast(context, '사진이 너무 커요. 다른 사진을 골라 주세요');
    if (p != null) setState(() => photos.add(p));
  }

  Future<void> _pickPlace() async {
    final r = await Navigator.push<(LatLng, String)>(context, MaterialPageRoute(builder: (_) => _PlacePick(start: pos ?? widget.c.pos)));
    if (r == null) return;
    setState(() {
      pos = r.$1;
      if (place.text.trim().isEmpty) place.text = r.$2;
    });
  }

  Future<void> _send() async {
    if (title.text.trim().length < 2) return toast(context, '행사 이름을 적어 주세요');
    if (pos == null) return toast(context, '지도에서 장소를 골라 주세요');
    if (place.text.trim().isEmpty) return toast(context, '장소 이름을 적어 주세요');
    if (photos.isEmpty) return toast(context, '사진을 한 장 이상 넣어 주세요');
    setState(() => busy = true);
    final err = await sendPost(
      c: widget.c,
      title: title.text.trim(),
      start: start,
      end: end,
      time: time.text.trim(),
      place: place.text.trim(),
      pos: pos!,
      desc: desc.text.trim(),
      fee: fee.text.trim(),
      scope: scope,
      photos: [for (final p in photos) p.full],
      thumbs: [for (final p in photos) p.thumb],
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) return toast(context, err);
    Navigator.pop(context, true);
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: T.title));

  Widget _pickBox({required String text, required VoidCallback onTap, IconData icon = Icons.event_rounded, bool set = true}) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE1E8))),
          child: Row(children: [
            Icon(icon, size: 18, color: set ? kInk : kSub),
            const SizedBox(width: 8),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: set ? kInk : kSub))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kBg, elevation: 0, surfaceTintColor: Colors.transparent, titleSpacing: 0, title: const Text('행사 알리기', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
        body: ListView(padding: const EdgeInsets.fromLTRB(kPad, 4, kPad, 40), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardBox(),
            child: const Text('단지 장터·벼룩시장·작은 음악회·관리사무소 행사처럼 이웃이 알면 좋은 소식을 올려 주세요.\n확인 뒤 지도와 목록에 올라가요.', style: TextStyle(fontSize: 13, height: 1.45)),
          ),
          _label('사진 (1~3장)'),
          SizedBox(
            height: 92,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(photos[i].thumb, width: 92, height: 92, fit: BoxFit.cover)),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: InkWell(
                        onTap: () => setState(() => photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
              if (photos.length < 3)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _addPhoto,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE1E8))),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_photo_alternate_outlined, color: kSub),
                      const SizedBox(height: 4),
                      Text('${photos.length}/3', style: T.tiny),
                    ]),
                  ),
                ),
            ]),
          ),
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('사람 얼굴이 크게 나온 사진은 올릴 수 없어요.', style: T.tiny)),
          const SizedBox(height: 10),
          Field('행사 이름', title, hint: '예) 더테라스 가을 벼룩시장', need: true, max: 60),
          _label('날짜'),
          Row(children: [
            Expanded(child: _pickBox(text: _d(start), onTap: () => _date(true))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
            Expanded(child: _pickBox(text: _d(end), onTap: () => _date(false))),
          ]),
          const SizedBox(height: 10),
          Field('시간', time, hint: '예) 오전 10시 ~ 오후 4시', max: 40),
          _label('장소'),
          _pickBox(
            text: pos == null ? '지도에서 장소 고르기' : '지도에서 고름 · ${distText(meters(widget.c.pos, pos!))} 거리',
            icon: Icons.place_outlined,
            set: pos != null,
            onTap: _pickPlace,
          ),
          const SizedBox(height: 10),
          Field('장소 이름', place, hint: '예) 단지 중앙광장', need: true, max: 80),
          Field('요금', fee, hint: '비워 두면 「무료」', max: 40),
          Field('설명', desc, hint: '무엇을 하는지, 준비물 등 (200자까지)', lines: 4, max: 200),
          _label('누구에게 보일까요?'),
          Row(children: [
            Expanded(child: ChoiceChipBox('우리 단지만', on: scope == 'apt', onTap: () => setState(() => scope = 'apt'))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChipBox('근처 단지 모두', on: scope == 'near', onTap: () => setState(() => scope = 'near'))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(scope == 'apt' ? '${widget.c.name} 주민에게만 보여요.' : '근처 단지 이웃 모두에게 보여요.', style: T.tiny),
          ),
          const SizedBox(height: 24),
          Btn(busy ? '보내는 중…' : '보내기', primary: true, h: 50, onTap: busy ? null : _send),
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('관리자가 확인한 뒤 공개돼요. 광고·홍보성 글은 올라가지 않아요.', style: T.tiny, textAlign: TextAlign.center)),
        ]),
      );
}

// 지도 가운데 핀으로 장소 고르기
class _PlacePick extends StatefulWidget {
  final LatLng start;
  const _PlacePick({required this.start});
  @override
  State<_PlacePick> createState() => _PlacePickState();
}

class _PlacePickState extends State<_PlacePick> {
  late LatLng at = widget.start;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: kBg, elevation: 0, surfaceTintColor: Colors.transparent, titleSpacing: 0, title: const Text('장소 고르기', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
        body: Stack(children: [
          Positioned.fill(child: DnMap(center: widget.start, zoom: 17, onIdle: (c, z, b, g) => at = c)),
          const IgnorePointer(
            child: Center(
              child: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.location_on_rounded, size: 44, color: Color(0xFFE5484D))),
            ),
          ),
          Positioned(
            left: kPad,
            right: kPad,
            bottom: 24,
            child: SafeArea(child: Btn('이 위치로 정하기', primary: true, h: 50, onTap: () => Navigator.pop(context, (at, '')))),
          ),
          Positioned(
            left: kPad,
            right: kPad,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: cardBox(),
              child: const Text('지도를 움직여 빨간 핀을 행사 장소에 맞춰 주세요', style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
            ),
          ),
        ]),
      );
}
