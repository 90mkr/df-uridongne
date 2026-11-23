// 주차장 자료 (이 폴더는 주차장 담당 방만 고침)
// collector/features/parking.py 가 전국 주차장을 0.1도 칸으로 나눠 web/data/parking/t/<칸>.json 에 둔다.
// 앱은 단지 둘레 칸만 받아서 가까운 순으로 보여 준다.
import 'package:latlong2/latlong.dart';

import '../../core/data.dart';

const _tile = 10; // collector 의 TILE 과 같게

class Lot {
  final String id, name, kind, type, addr, days, fee, pay, note, org, tel;
  final int spaces, basicMin, basicWon, addMin, addWon, dayMin, dayWon, monthWon;
  final List<String> hours; // 평일 시작·끝, 토 시작·끝, 공휴일 시작·끝
  final bool disabled; // 장애인 전용 구역 있음
  final double lat, lng;

  Lot.fromJson(Map j)
      : id = '${j['id']}',
        name = '${j['n'] ?? ''}',
        kind = '${j['k'] ?? ''}',
        type = '${j['ty'] ?? ''}',
        addr = '${j['a'] ?? ''}',
        days = '${j['d'] ?? ''}',
        fee = '${j['f'] ?? ''}',
        pay = '${j['pay'] ?? ''}',
        note = '${j['sp'] ?? ''}',
        org = '${j['org'] ?? ''}',
        tel = '${j['tel'] ?? ''}',
        spaces = _i(j['c']),
        basicMin = _i(j['bt']),
        basicWon = _i(j['bc']),
        addMin = _i(j['at']),
        addWon = _i(j['ac']),
        dayMin = _i(j['dt']),
        dayWon = _i(j['dc']),
        monthWon = _i(j['mc']),
        hours = [for (var i = 0; i < 6; i++) (j['h'] is List && (j['h'] as List).length > i) ? '${j['h'][i]}' : ''],
        disabled = j['dis'] == 1,
        lat = (j['y'] as num).toDouble(),
        lng = (j['x'] as num).toDouble();

  LatLng get pos => LatLng(lat, lng);
  bool get isPublic => kind.contains('공영');
  bool get isFree => fee.contains('무료') && !fee.contains('유료');

  // 「노외 · 공영」처럼 짧은 구분
  String get label => [if (kind.isNotEmpty) kind, if (type.isNotEmpty) type].join(' · ');

  // 요금 한 줄 (목록용)
  String get feeShort {
    if (isFree) return '무료';
    if (basicMin > 0 && basicWon > 0) return '$basicMin분 ${won(basicWon)}';
    if (fee.contains('혼합')) return '유료·무료 혼합';
    if (fee.isNotEmpty) return fee;
    return '요금 정보 없음';
  }

  // 오늘 운영시간 (평일·토·일/공휴일)
  (String, String) today(DateTime now) {
    final w = now.weekday;
    final k = w == DateTime.saturday ? 2 : (w == DateTime.sunday ? 4 : 0);
    var o = hours[k], c = hours[k + 1];
    if (o.isEmpty && c.isEmpty && k != 0) {
      // 토·공휴일 운영 요일에 들어 있는데 시간이 비었으면 평일 시간을 쓴다
      final on = k == 2 ? days.contains('토') : days.contains('공휴') || days.contains('일');
      if (on) {
        o = hours[0];
        c = hours[1];
      }
    }
    return (o, c);
  }

  bool get allDay {
    final (o, c) = (hours[0], hours[1]);
    return o == '00:00' && (c == '23:59' || c == '24:00' || c == '00:00');
  }

  String hoursText(DateTime now) {
    final (o, c) = today(now);
    if (o.isEmpty || c.isEmpty) return '';
    if (o == '00:00' && (c == '23:59' || c == '24:00' || c == '00:00')) return '24시간';
    return '$o~$c';
  }

  // 지금 운영 중인지 (모르면 null)
  bool? openAt(DateTime now) {
    final w = now.weekday;
    if (days.isNotEmpty) {
      if (w == DateTime.saturday && !days.contains('토')) return false;
      if (w == DateTime.sunday && !(days.contains('공휴') || days.contains('일요'))) return false;
      if (w <= 5 && !days.contains('평일') && !days.contains('월')) {
        // 「토요일+공휴일」만 운영하는 드문 경우
        if (days.contains('토') || days.contains('공휴')) return false;
      }
    }
    final (o, c) = today(now);
    final a = _min(o), b = _min(c);
    if (a == null || b == null) return null;
    final t = now.hour * 60 + now.minute;
    if (a == 0 && (b >= 1439 || b == 0)) return true;
    return a <= b ? (t >= a && t < b) : (t >= a || t < b);
  }
}

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

int? _min(String s) {
  final p = s.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String won(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b원';
}

// 단지 둘레 칸들을 받는다 (한 번 받은 칸은 앱이 켜져 있는 동안 다시 받지 않음)
final Map<String, List<Lot>> _tiles = {};

Future<List<Lot>> lotsNear(LatLng p, {double km = 3}) async {
  final dLat = km / 111.0, dLng = km / 88.0;
  final keys = <String>{};
  for (final y in [p.latitude - dLat, p.latitude, p.latitude + dLat]) {
    for (final x in [p.longitude - dLng, p.longitude, p.longitude + dLng]) {
      keys.add('${(y * _tile).floor()}_${(x * _tile).floor()}');
    }
  }
  await Future.wait([
    for (final k in keys)
      if (!_tiles.containsKey(k))
        getJson('${dataBase}parking/t/$k.json').then((j) {
          _tiles[k] = [
            for (final x in (j is Map ? (j['p'] as List? ?? const []) : const []))
              if (x is Map && x['y'] != null && x['x'] != null) Lot.fromJson(x)
          ];
        }),
  ]);
  final out = <Lot>[for (final k in keys) ...?_tiles[k]];
  final d = {for (final l in out) l.id: meters(p, l.pos)};
  out.removeWhere((l) => d[l.id]! > km * 1000);
  out.sort((a, b) => d[a.id]!.compareTo(d[b.id]!));
  return out;
}

// 자료 기준일 (meta.json)
Future<String> parkingUpdated() async {
  final j = await getJson('${dataBase}parking/meta.json');
  if (j is Map && j['updated'] != null) return '${j['updated']}'.substring(0, 10);
  return '';
}
