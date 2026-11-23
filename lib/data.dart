part of 'main.dart';

// ---------------- 자료: 동네 · 업체 · 콕플 맛집 ----------------
// 업체 자료는 깃허브 자동 제작이 카카오에서 모아 둔 파일을 받아 온다.
// 동네 id는 콕플과 같아서, 같은 동네의 콕플 맛집 자료(유튜버·구글 별점)를 그대로 붙여 보여 준다.

const kDataUrl = 'https://90mkr.github.io/df-uridongne/data/';
const kKokpleDataUrl = 'https://90mkr.github.io/df-app-lab/data/';
const kKokpleWeb = 'https://90mkr.github.io/df-app-lab/';

String get dataBase => kIsWeb && Uri.base.host.endsWith('github.io') ? 'data/' : kDataUrl;

// 앱 분야 (아이콘 이름 = id)
class Cat {
  final String id, name, desc;
  const Cat(this.id, this.name, this.desc);
}

const kCats = [
  Cat('food', '음식점', '밥집·분식·배달'),
  Cat('cafe', '카페', '커피·디저트'),
  Cat('mart', '마트·편의점', '장보기'),
  Cat('hosp', '병원', '의원·치과·한의원'),
  Cat('pharm', '약국', '약국'),
  Cat('kids', '어린이집', '어린이집·유치원'),
  Cat('acad', '학원', '학원·교습소'),
  Cat('laundry', '세탁소', '세탁·빨래방'),
  Cat('ricecake', '떡집·반찬', '떡집·반찬가게'),
  Cat('hair', '미용실', '미용실·헤어'),
  Cat('flower', '꽃집', '꽃·화원'),
  Cat('repair', '수선·열쇠', '옷 수선·열쇠·구두'),
  Cat('hardware', '철물·설비', '철물·인테리어·설비'),
  Cat('realty', '부동산', '공인중개사'),
  Cat('bank', '은행', '은행·금융'),
  Cat('car', '자동차', '주유·세차·정비'),
  Cat('pet', '반려동물', '동물병원·애견미용'),
  Cat('public', '공공기관', '주민센터·우체국'),
];

Cat catOf(String id) => kCats.firstWhere((c) => c.id == id, orElse: () => kCats.first);

class Area {
  final String id, name, sido, gu, updated;
  final double lat, lng;
  final List<double> bbox;
  final bool ready;
  final int count;
  Area(this.id, this.name, this.sido, this.gu, this.lat, this.lng, this.bbox, this.ready, this.count, this.updated);

  LatLng get center => LatLng(lat, lng);
  bool contains(LatLng p) => p.longitude >= bbox[0] && p.longitude <= bbox[2] && p.latitude >= bbox[1] && p.latitude <= bbox[3];
  String get full => '$sido $name';
}

class Kok {
  final double grate;
  final int greviews;
  final bool top;
  final int yt; // 다녀간 유튜브 영상 수
  const Kok(this.grate, this.greviews, this.top, this.yt);
}

class Shop {
  final String id, name, sub, addr, tel;
  final List<String> cats;
  final double lat, lng;
  Kok? kok; // 콕플 맛집이면 별점·유튜브 정보
  Shop(this.id, this.name, this.cats, this.sub, this.addr, this.tel, this.lat, this.lng);

  LatLng get pos => LatLng(lat, lng);
  String get kakaoUrl => 'https://place.map.kakao.com/$id';

  factory Shop.fromJson(Map j) => Shop(
        '${j['id']}',
        '${j['n'] ?? ''}',
        [for (final c in (j['c'] as List? ?? const [])) '$c'],
        '${j['s'] ?? ''}',
        '${j['a'] ?? ''}',
        '${j['t'] ?? ''}',
        (j['y'] as num).toDouble(),
        (j['x'] as num).toDouble(),
      );
}

class Store {
  List<Area> areas = [];
  final Map<String, List<Shop>> _shops = {};
  final Map<String, String> _updated = {};
  final Map<String, List<Shop>> _kokTops = {};

  Future<void> loadAreas() async {
    final j = await _get('${dataBase}regions.json');
    if (j == null) return;
    final out = <Area>[];
    for (final s in (j['sido'] as List? ?? const [])) {
      for (final a in (s['areas'] as List? ?? const [])) {
        final b = a['bbox'];
        if (b is! List || b.length != 4) continue;
        out.add(Area(
          '${a['id']}',
          '${a['name']}',
          '${s['name']}',
          '${a['gu'] ?? ''}',
          (a['lat'] as num).toDouble(),
          (a['lng'] as num).toDouble(),
          [for (final x in b) (x as num).toDouble()],
          a['ready'] == true,
          (a['count'] as num?)?.toInt() ?? 0,
          '${a['updated'] ?? ''}',
        ));
      }
    }
    areas = out;
  }

  String updatedOf(String areaId) => _updated[areaId] ?? '';

  // 한 동네의 업체 전부 + 콕플 맛집 정보 붙이기
  Future<List<Shop>> shops(Area a) async {
    final have = _shops[a.id];
    if (have != null) return have;
    final results = await Future.wait([_get('$dataBase${a.id}.json'), _get('$kKokpleDataUrl${a.id}.json')]);
    final j = results[0];
    final list = <Shop>[
      for (final s in (j?['shops'] as List? ?? const []))
        if (s is Map && s['y'] != null && s['x'] != null) Shop.fromJson(s)
    ];
    _updated[a.id] = '${j?['updated'] ?? ''}';
    final byId = {for (final s in list) s.id: s};
    final tops = <Shop>[];
    final k = results[1];
    for (final p in (k?['places'] as List? ?? const [])) {
      if (p is! Map) continue;
      final id = '${p['id']}';
      final kok = Kok(
        (p['grate'] as num?)?.toDouble() ?? 0,
        (p['greviews'] as num?)?.toInt() ?? 0,
        p['top'] == true,
        (p['vids'] is List) ? (p['vids'] as List).length : 0,
      );
      var s = byId[id];
      if (s == null) {
        // 콕플에는 있는데 우리 자료에 아직 없는 맛집 → 함께 넣는다
        final lat = (p['lat'] as num?)?.toDouble(), lng = (p['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        s = Shop(id, '${p['name'] ?? ''}', [p['kind'] == 'cafe' ? 'cafe' : 'food'], '${p['cat'] ?? ''}', '${p['addr'] ?? ''}', '${p['tel'] ?? ''}', lat, lng);
        list.add(s);
        byId[id] = s;
      }
      s.kok = kok;
      if (kok.top) tops.add(s);
    }
    tops.sort((x, y) => (y.kok!.grate * math.log(y.kok!.greviews + 2)).compareTo(x.kok!.grate * math.log(x.kok!.greviews + 2)));
    _kokTops[a.id] = tops;
    _shops[a.id] = list;
    return list;
  }

  List<Shop> kokTops(Area a) => _kokTops[a.id] ?? const [];

  Future<Map?> _get(String url) async {
    try {
      final r = await http.get(Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return j is Map ? j : null;
    } catch (_) {
      return null;
    }
  }
}

final store = Store();

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

Area? areaAt(List<Area> all, LatLng p) {
  Area? best;
  var bd = 15000.0;
  for (final a in all) {
    final d = a.contains(p) ? 0.0 : meters(p, a.center);
    if (best == null ? d < bd : (d < bd || (d == 0 && meters(p, a.center) < meters(p, best.center)))) {
      bd = d;
      best = a;
    }
  }
  return best;
}

// ---------------- 파이어베이스 (콕플과 같은 「디자인필」 프로젝트) ----------------
// 사장님 등록·정보 수정 신고만 쓴다. 공개 설정 값이라 코드에 둬도 된다.
const kFb = <String, String>{
  'apiKey': 'AIzaSyCtAYeMr_86li7WmmkXUL6Nx0ae8xmG5ME',
  'androidApiKey': 'AIzaSyB5wrd2GrSG7LqmrZqCvcWBBRWH7glm5Os',
  'authDomain': 'kokple.firebaseapp.com',
  'projectId': 'kokple',
  'storageBucket': 'kokple.firebasestorage.app',
  'messagingSenderId': '233879188710',
  'webAppId': '1:233879188710:web:543f8fd620c76f0685f727',
  'androidAppId': '1:233879188710:android:d370f784c3a7f72185f727',
};

Future<bool>? _fbF;
Future<bool> fbReady() => _fbF ??= () async {
      try {
        await fc.Firebase.initializeApp(
          options: fc.FirebaseOptions(
            apiKey: kIsWeb ? kFb['apiKey']! : kFb['androidApiKey']!,
            appId: kIsWeb ? kFb['webAppId']! : kFb['androidAppId']!,
            messagingSenderId: kFb['messagingSenderId']!,
            projectId: kFb['projectId']!,
            authDomain: kFb['authDomain'],
            storageBucket: kFb['storageBucket'],
          ),
        );
        return true;
      } catch (_) {
        return false;
      }
    }();

// 사장님 등록·정보 수정 신고 보내기 (관리자가 확인한 뒤 반영)
Future<bool> sendRequest(Map<String, dynamic> data) async {
  if (!await fbReady()) return false;
  try {
    await fs.FirebaseFirestore.instance.collection('dn_reqs').add({
      ...data,
      'app': 'dongne',
      'st': 'new',
      'at': fs.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (_) {
    return false;
  }
}

// ---------------- 기억해 둘 것 (마지막 동네) ----------------
Future<String?> savedArea() async {
  try {
    return (await SharedPreferences.getInstance()).getString('area');
  } catch (_) {
    return null;
  }
}

Future<void> saveArea(String id) async {
  try {
    await (await SharedPreferences.getInstance()).setString('area', id);
  } catch (_) {}
}
