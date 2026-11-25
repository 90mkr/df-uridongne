// 공통 자료 (본부 방만 고침): 동네(지역) · 단지 · 내 위치 · 자료 받기 · 기억해 두기
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kk.dart';
import 'remote.dart';

// 자동 제작이 모아 둔 자료 파일 주소 (web/data/ → 미리보기 주소의 data/)
const kSiteUrl = 'https://90mkr.github.io/df-uridongne/';
const kDataUrl = '${kSiteUrl}data/';
const kKokpleDataUrl = 'https://90mkr.github.io/df-app-lab/data/';
const kKokpleWeb = 'https://90mkr.github.io/df-app-lab/';

// 자료는 저장소 main 에서 바로 받는다 (자료를 모아 올리면 미리보기 게시를 기다리지 않고 곧바로 보임 — 5분 안팎 캐시)
const kRawDataUrl = 'https://raw.githubusercontent.com/90mkr/df-uridongne/main/web/data/';
String get dataBase => kRawDataUrl;
// 전국 동네·가게·아파트 (공공데이터로 매주 새로 만듦, 본부 「전국 자료」) — 서버 설정 app.json 의 store 로 바꿀 수 있음 (R2)
const kStoreUrl = 'https://raw.githubusercontent.com/90mkr/df-uridongne/store/';
String get storeBase {
  final s = remoteCfg.value.store;
  return s.isEmpty ? kStoreUrl : (s.endsWith('/') ? s : '$s/');
}

// JSON 받기 (실패하면 null). 10분 단위로 새로 받는다.
Future<dynamic> getJson(String url, {Duration timeout = const Duration(seconds: 20)}) async {
  try {
    final sep = url.contains('?') ? '&' : '?';
    final r = await http.get(Uri.parse('$url${sep}t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}')).timeout(timeout);
    if (r.statusCode != 200) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  } catch (_) {
    return null;
  }
}

// ---------------- 거리 ----------------
double meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

String distText(double m) => m < 1000 ? '${(m / 10).round() * 10}m' : '${(m / 1000).toStringAsFixed(1)}km';

// ---------------- 동네 (콕플과 같은 id·범위) ----------------
class Area {
  final String id, name, sido, gu;
  final double lat, lng;
  final List<double> bbox; // [서경, 남위, 동경, 북위]
  final bool ready;
  Area(this.id, this.name, this.sido, this.gu, this.lat, this.lng, this.bbox, this.ready);
  LatLng get center => LatLng(lat, lng);
  bool contains(LatLng p) => p.longitude >= bbox[0] && p.longitude <= bbox[2] && p.latitude >= bbox[1] && p.latitude <= bbox[3];
}

List<Area> areas = [];

Future<void> loadAreas() async {
  if (areas.isNotEmpty) return;
  final j = await getJson('${storeBase}regions.json') ?? await getJson('${dataBase}regions.json');
  if (j is! Map) return;
  final out = <Area>[];
  for (final s in (j['sido'] as List? ?? const [])) {
    for (final a in (s['areas'] as List? ?? const [])) {
      final b = a['bbox'];
      if (b is! List || b.length != 4) continue;
      out.add(Area('${a['id']}', '${a['name']}', '${s['name']}', '${a['gu'] ?? ''}', (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble(),
          [for (final x in b) (x as num).toDouble()], a['ready'] == true));
    }
  }
  areas = out;
}

Area? areaAt(LatLng p) {
  Area? best;
  var bd = 30000.0;
  for (final a in areas) {
    // 범위가 겹치면(시군구 경계) 범위 안 동네 가운데 가운데가 가장 가까운 곳
    final d = a.contains(p) ? meters(p, a.center) - 1e7 : meters(p, a.center);
    if (d < bd) {
      bd = d;
      best = a;
    }
  }
  return best;
}

Area? areaById(String id) => areas.where((a) => a.id == id).firstOrNull;

// ---------------- 단지 ----------------
// 단지 = 이름·주소·위치 + 속한 동네 id. 모든 기능은 「지금 고른 단지」를 기준으로 보여 준다.
class Complex {
  final String id; // 카카오 장소 번호 (직접 넣은 단지는 'my_…')
  final String name, addr, areaId;
  final double lat, lng;
  const Complex({required this.id, required this.name, required this.addr, required this.areaId, required this.lat, required this.lng});
  LatLng get pos => LatLng(lat, lng);
  Area? get area => areaById(areaId);
  // 아파트가 아닌 집(주택·빌라 등, 11-25): 단지 게시판 없이 동네 게시판만
  bool get isHome => id.startsWith('home_');

  // 「송도」 + 「○○아파트」처럼 앞 동네 이름과 단지 이름을 나눠 보여 줄 때
  // 준비된 동네가 아니면 주소의 시·군·구에서 (예: 「부산 해운대구 …」 → 「해운대」)
  String get town {
    final a = area;
    if (a != null) return a.name.split('/').first;
    final w = addr.split(' ');
    if (w.length < 2) return '';
    var g = w[1];
    if (g.length > 2 && (g.endsWith('구') || g.endsWith('시') || g.endsWith('군'))) g = g.substring(0, g.length - 1);
    return g;
  }

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'a': addr, 'ar': areaId, 'y': lat, 'x': lng};
  static Complex? fromJson(dynamic j) {
    if (j is! Map || j['y'] == null || j['x'] == null) return null;
    return Complex(
        id: '${j['id']}', name: '${j['n'] ?? ''}', addr: '${j['a'] ?? ''}', areaId: '${j['ar'] ?? ''}', lat: (j['y'] as num).toDouble(), lng: (j['x'] as num).toDouble());
  }
}

final Map<String, List<Complex>> _apts = {};

// 동네의 아파트 단지 목록 (자동 제작이 web/data/apt_<동네>.json 으로 모아 둠)
Future<List<Complex>> complexesOf(Area a) async {
  final have = _apts[a.id];
  if (have != null) return have;
  final j = await getJson('${storeBase}apt_${a.id}.json');
  if (j == null) {
    // 아직 아파트 자료가 없는 동네: 그 자리에서 카카오로 찾아 보여 주기만 (저장 안 함)
    final live = await kkComplexes(near: a.center);
    return [for (final c in live) Complex(id: c.id, name: c.name, addr: c.addr, areaId: a.id, lat: c.lat, lng: c.lng)];
  }
  final list = <Complex>[
    for (final x in (j is Map ? (j['apts'] as List? ?? const []) : const []))
      if (x is Map && x['y'] != null)
        Complex(id: '${x['id']}', name: '${x['n']}', addr: '${x['a'] ?? ''}', areaId: a.id, lat: (x['y'] as num).toDouble(), lng: (x['x'] as num).toDouble())
  ];
  _apts[a.id] = list;
  return list;
}

// 지금 고른 단지 (앱 전체가 이걸 바라본다)
final complex = ValueNotifier<Complex?>(null);

Future<void> loadSavedComplex() async {
  try {
    final s = (await SharedPreferences.getInstance()).getString('complex');
    if (s != null) complex.value = Complex.fromJson(jsonDecode(s));
  } catch (_) {}
}

Future<void> setComplex(Complex c) async {
  complex.value = c;
  try {
    await (await SharedPreferences.getInstance()).setString('complex', jsonEncode(c.toJson()));
  } catch (_) {}
}

// ---------------- 내 위치 ----------------
final myPos = ValueNotifier<LatLng?>(null);

Future<LatLng?> myLocation({bool ask = true}) async {
  try {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && ask) perm = await Geolocator.requestPermission();
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return null;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)),
    );
    final p = LatLng(pos.latitude, pos.longitude);
    myPos.value = p;
    return p;
  } catch (_) {
    return null;
  }
}

// 거리를 잴 기준점: 단지 (없으면 내 위치)
LatLng? get basePos => complex.value?.pos ?? myPos.value;

// ---------------- 기능별 작은 기억 칸 ----------------
// 기능 방은 자기 이름을 앞에 붙여 쓴다. 예: prefGet('bus.pinned')
Future<String?> prefGet(String key) async {
  try {
    return (await SharedPreferences.getInstance()).getString(key);
  } catch (_) {
    return null;
  }
}

Future<void> prefSet(String key, String value) async {
  try {
    await (await SharedPreferences.getInstance()).setString(key, value);
  } catch (_) {}
}
