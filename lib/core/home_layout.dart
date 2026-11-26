// 「홈 편집」 (본부 방만 고침): 사용자가 단지 홈 카드의 순서를 바꾸고, 안 보고 싶은 카드·생활 도구를 끈다.
// 설정은 이 휴대폰에만 저장 (prefs: home.order · home.hide · home.hideTools)
import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/registry.dart';
import 'data.dart';
import 'feature.dart';
import 'theme.dart';
import 'ui.dart';

/// 바뀌면 홈이 다시 그려진다
final homeLayoutTick = ValueNotifier<int>(0);

List<String> _order = [];
Set<String> _hide = {};
Set<String> _on = {}; // 처음엔 꺼져 있는 한 줄 카드(r:) 중 사용자가 켠 것
Map<String, String> _size = {}; // 사용자가 바꾼 크기: big · icon (11-26 홈 두 단계)
bool _loaded = false;

Future<void> loadHomeLayout() async {
  if (_loaded) return;
  _loaded = true;
  try {
    final o = await prefGet('home.order');
    if (o != null && o.isNotEmpty) _order = List<String>.from(jsonDecode(o));
    final h = await prefGet('home.hide');
    if (h != null && h.isNotEmpty) _hide = Set<String>.from(jsonDecode(h));
    final t = await prefGet('home.on');
    if (t != null && t.isNotEmpty) _on = Set<String>.from(jsonDecode(t));
    final z = await prefGet('home.size');
    if (z != null && z.isNotEmpty) _size = Map<String, String>.from(jsonDecode(z));
  } catch (_) {}
  homeLayoutTick.value++;
}

Future<void> _save() async {
  await prefSet('home.order', jsonEncode(_order));
  await prefSet('home.hide', jsonEncode(_hide.toList()));
  await prefSet('home.on', jsonEncode(_on.toList()));
  await prefSet('home.size', jsonEncode(_size));
  homeLayoutTick.value++;
  homeLayoutSaved?.call(homeLayoutJson());
}

/// 홈 배치 한 묶음 (로그인한 분 설정 백업·되살리기, settings_sync.dart)
void Function(Map<String, dynamic>)? homeLayoutSaved;
Map<String, dynamic> homeLayoutJson() => {'order': _order, 'hide': _hide.toList(), 'on': _on.toList(), 'size': _size};
bool get homeLayoutTouched => _order.isNotEmpty || _hide.isNotEmpty || _on.isNotEmpty || _size.isNotEmpty;
Future<void> applyHomeLayout(Map j) async {
  _order = List<String>.from(j['order'] ?? const []);
  _hide = Set<String>.from(j['hide'] ?? const []);
  _on = Set<String>.from(j['on'] ?? const []);
  _size = Map<String, String>.from(j['size'] ?? const {});
  final keep = homeLayoutSaved;
  homeLayoutSaved = null; // 되살릴 때는 다시 올리지 않음
  await _save();
  homeLayoutSaved = keep;
}

// 11-26 홈 두 단계: 한 줄 카드(r:)도 처음부터 보임 — 대부분 아이콘 줄에 들어가 홈이 길어지지 않음
const _defaultOff = {'m:school', 'm:pet'}; // 처음엔 꺼 둘 것 (학교: 아이 학교를 등록하면 저절로 켜짐 · 반려동물: 테마 첫 화면에서 켜거나 우리 아이를 등록하면 켜짐)
bool isHidden(String id) => _hide.contains(id) || (_defaultOff.contains(id) && !_on.contains(id));

// ---- 크게 보기 / 아이콘으로 (11-26) ----
// 기본값은 기능 등록부(registry.dart 의 kHomeBig)가 정함: 오늘 바뀌는 정보만 큰 카드, 나머지는 아이콘
bool canBeBig(String id) => !id.startsWith('i:');
bool isBig(String id) {
  if (!canBeBig(id)) return false;
  final u = _size[id];
  if (u != null) return u == 'big';
  return id == 'today' || kHomeBig.contains(id);
}

Future<void> setHomeSize(String id, bool big) async {
  if (big && !canBeBig(id)) return;
  _size[id] = big ? 'big' : 'icon';
  await _save();
}

/// 아이콘 줄 이름 (칸이 좁아 짧게)
const kHomeShort = {'weather': '날씨', 'board': '단지 이야기', 'events': '행사·축제', 'trash': '분리수거', 'pharmacy': '문 연 약국', 'postcode': '택배·우편', 'deals': '최근 거래', 'bus': '버스', 'roulette': '뭐 먹지?', 'school': '학교 급식', 'parking': '주차장', 'mycar': '내 차', 'toilet': '화장실', 'charger': '충전소', 'gas': '주유소', 'anniv': '기념일', 'subway': '지하철', 'phonebook': '전화번호부', 'pet': '반려동물', 'lotto': '로또', 'alarm': '알람', 'benefit': '지원금'};

/// 홈 아래 「전체 보기」 → 생활 도구 탭 (셸이 들음)
final homeToolsAsk = ValueNotifier<int>(0);

/// 기능 화면에서 「홈에 보이게」 (예: 학교 등록하면 학교 카드 켜기)
Future<void> setHomeCardOn(String id) async {
  if (!isHidden(id)) return;
  _setOn(id, true);
  if (id == 'm:pet' && _size[id] == null) _size[id] = 'big'; // 반려 배너는 켜면 큰 카드
  if (_order.isNotEmpty) {
    _order.remove(id);
    _order.insert(1.clamp(0, _order.length), id); // 켜면 맨 위 카드 바로 아래 (첫 화면에 보이게)
  }
  await _save();
}

/// 기능 화면에서 「홈에서 빼기」 (예: 반려동물 테마 첫 화면의 「홈에 띄우기」 끄기)
Future<void> setHomeCardOff(String id) async {
  if (isHidden(id)) return;
  _setOn(id, false);
  await _save();
}

void _setOn(String id, bool v) {
  if (v) {
    _hide.remove(id);
    _on.add(id);
  } else {
    _hide.add(id);
    _on.remove(id);
  }
}

// 「내 차 어디 댔지」 같은 한 줄 카드가 따로 없는 기능의 한 줄 카드 제목·설명
const _rowTitles = {
  'weather': ('오늘', '날씨', '기온·미세먼지 한눈에'),
  'trash': ('오늘', '배출', '오늘 내놓을 쓰레기·분리수거'),
  'lotto': ('로또', '당첨 번호', '이번 회차 번호와 내 번호 맞춰 보기'),
  'postcode': ('택배', '우편번호', '우리 단지 우편번호·택배 조회'),
  'alarm': ('알람', '맞추기', '휴대폰 시계 앱에 알람을 넣어 드려요'),
};

class _RowCard extends StatelessWidget {
  final Feature f;
  final Complex c;
  const _RowCard({required this.f, required this.c});
  @override
  Widget build(BuildContext context) {
    final t = _rowTitles[f.id];
    return FutureBuilder<Brief?>(
      future: f.brief(c, DateTime.now()),
      builder: (_, snap) {
        final b = snap.data;
        final sub = b == null ? (t?.$3 ?? '') : [b.bold, b.hot, b.rest].where((x) => x.isNotEmpty).join(' ').trim();
        return MainRowCard(
          icon: f.icon,
          bold: t?.$1 ?? f.name,
          thin: t?.$2 ?? '',
          sub: sub.isEmpty ? (t?.$3 ?? '') : sub,
          subLines: 1,
          trailing: const Icon(Icons.chevron_right_rounded, color: kSub),
          onTap: () => openFeature(context, f),
        );
      },
    );
  }
}

const _topMain = {'pet'};

// 본문 큰 카드 이름 (mainCard 는 기능 이름과 다르게 부름)
const _mainNames = {'parking': '내 차 어디 댔지', 'charger': '충전소 찾기', 'gas': '제일 싼 주유소', 'anniv': '다가오는 기념일', 'school': '우리 아이 학교 급식', 'events': '주변 행사·축제', 'board': '우리 단지 이야기', 'pet': '오늘의 반려 생활', 'subway': '우리 역 노선도'};

/// 홈 한 칸
class HomeBlock {
  final String id; // today · f:<기능> · m:<기능> · r:<기능> · i:<기능>(아이콘만)
  final String name, icon;
  final bool half;
  final Widget Function(BuildContext context) build;
  const HomeBlock(this.id, this.name, this.icon, this.build, {this.half = false});
  String get fid => id.contains(':') ? id.substring(id.indexOf(':') + 1) : id;
}

/// 기본 순서의 홈 칸들 (만들 수 있는 것만)
List<HomeBlock> defaultBlocks(BuildContext context, Complex c, {required Widget Function() today, required Widget Function(Feature f) card}) {
  List<Feature> at(Slot s) => features.where((f) => f.slot == s).toList()..sort((a, b) => a.order.compareTo(b.order));
  final out = <HomeBlock>[];
  for (final f in at(Slot.hero)) {
    out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f)));
  }
  if (at(Slot.hero).isEmpty) out.add(HomeBlock('today', '지금 우리 단지', 'weather', (_) => today()));
  // 켜면 첫 화면 맨 위 카드 바로 아래에 오는 배너형 큰 카드 (반려동물 「오늘의 반려 생활」, 대표님 11-26)
  for (final f in features.where((f) => _topMain.contains(f.id))) {
    final w = f.mainCard(context, c);
    if (w != null) out.add(HomeBlock('m:${f.id}', _mainNames[f.id] ?? f.name, f.icon, (_) => w));
  }
  for (final f in at(Slot.half)) {
    out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f), half: true));
  }
  for (final s in [Slot.section, Slot.wide]) {
    for (final f in at(s)) {
      out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f)));
    }
  }
  for (final f in [...features]..sort((a, b) => a.mainOrder.compareTo(b.mainOrder))) {
    if (_topMain.contains(f.id)) continue;
    final w = f.mainCard(context, c);
    if (w != null) out.add(HomeBlock('m:${f.id}', _mainNames[f.id] ?? f.name, f.icon, (_) => w));
  }
  // 한 줄 카드가 따로 없는 기능도 같은 모양 한 줄 카드로 (처음엔 꺼 둠)
  for (final f in features) {
    if (!f.ready || !_rowTitles.containsKey(f.id) || f.mainCard(context, c) != null) continue;
    final t = _rowTitles[f.id]!;
    out.add(HomeBlock('r:${f.id}', '${t.$1} ${t.$2}', f.icon, (_) => _RowCard(f: f, c: c)));
  }
  for (final f in at(Slot.tail)) {
    out.add(HomeBlock('f:${f.id}', f.name, f.icon, (_) => card(f)));
  }
  // 홈 칸이 없는 기능은 아이콘 줄에만 (예: 화장실·로또·지원금)
  final have = {for (final b in out) b.fid};
  for (final f in [...features]..sort((a, b) => a.order.compareTo(b.order))) {
    if (have.contains(f.id) || f.slot == Slot.header || f.slot == Slot.info) continue;
    out.add(HomeBlock('i:${f.id}', f.name, f.icon, (_) => const SizedBox.shrink()));
  }
  return out;
}

/// 사용자 순서 적용 (새로 생긴 칸은 기본 자리 근처에 끼움). hidden 포함 여부 선택
List<HomeBlock> arrange(List<HomeBlock> base, {bool withHidden = false}) {
  if (_order.isEmpty) return withHidden ? base : base.where((b) => !isHidden(b.id)).toList();
  final byId = {for (final b in base) b.id: b};
  final out = <HomeBlock>[];
  for (final id in _order) {
    final b = byId.remove(id);
    if (b != null) out.add(b);
  }
  // 새 칸: 기본 순서에서 바로 앞 칸 뒤에
  for (var i = 0; i < base.length; i++) {
    final b = base[i];
    if (!byId.containsKey(b.id)) continue;
    final prev = i == 0 ? null : base[i - 1].id;
    final at = prev == null ? 0 : out.indexWhere((x) => x.id == prev) + 1;
    out.insert(at.clamp(0, out.length), b);
    byId.remove(b.id);
  }
  return withHidden ? out : out.where((b) => !isHidden(b.id)).toList();
}

// ---- 홈 편집 (홈 화면 그 자리에서: 작은 막대로 줄여 끌어 옮기기 · ⊖ 끄기 · ⊕ 켜기) ----

/// 내 정보 탭 등에서 「홈 편집」을 열어 달라고 할 때 (셸이 홈 탭으로 넘기고, 홈이 편집 모드로)
final homeEditAsk = ValueNotifier<int>(0);

void setHomeOrder(List<HomeBlock> visible, List<HomeBlock> hidden) {
  _order = [for (final b in visible) b.id, for (final b in hidden) b.id];
  _save();
}

void hideBlock(String id, List<HomeBlock> visible, List<HomeBlock> hidden) {
  _setOn(id, false);
  final v = visible.where((b) => b.id != id).toList();
  final h = [...visible.where((b) => b.id == id), ...hidden];
  setHomeOrder(v, h);
}

void showBlock(String id, List<HomeBlock> visible, List<HomeBlock> hidden) {
  _setOn(id, true);
  final v = [...visible, ...hidden.where((b) => b.id == id)]; // 켜면 맨 아래에 붙는다
  final h = hidden.where((b) => b.id != id).toList();
  setHomeOrder(v, h);
}

void resetHomeLayout() {
  _order = [];
  _hide = {};
  _on = {};
  _size = {};
  _save();
}
