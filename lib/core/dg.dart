// 공공데이터포털(apis.data.go.kr) 부르기 — 「중간 다리」 경유 (본부 방만 고침)
// 사용 예 (기능 방):
//   final r = await dgGet('https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList?gpsLati=..&gpsLong=..&_type=json');
//   final r = await dgGet(url, cache: 43200); // 노선·정류장 목록처럼 잘 안 바뀌는 것은 12시간 묶어 두기
// - 주소에 serviceKey 를 넣지 않아도 된다 (넣어도 다리 쪽에서 버림). 다리가 서버 열쇠를 붙인다.
// - 다리가 없으면(DATA_PROXY 를 비운 제작) 예전처럼 앱의 DATA_GO_KR_KEY 로 바로 부른다.
import 'package:http/http.dart' as http;

import 'keys.dart';

const _host = 'https://apis.data.go.kr/';

String get _key => kDataGoKrKey.contains('%') ? kDataGoKrKey : Uri.encodeQueryComponent(kDataGoKrKey);

// serviceKey 를 뺀 질문으로 다시 만든다
String _strip(String query) => query.split('&').where((p) => p.isNotEmpty && !p.toLowerCase().startsWith('servicekey=')).join('&');

/// apis.data.go.kr 주소 → 실제로 부를 주소 (다리 또는 열쇠 붙인 원래 주소)
String dgUrl(String url, {int cache = 30}) {
  if (!url.startsWith(_host)) return url;
  final i = url.indexOf('?');
  final path = url.substring(_host.length, i < 0 ? url.length : i);
  final q = _strip(i < 0 ? '' : url.substring(i + 1));
  if (kDataProxy.isNotEmpty) {
    return '$kDataProxy/dg/$path?${q.isEmpty ? '' : '$q&'}_c=$cache';
  }
  return '$_host$path?serviceKey=$_key${q.isEmpty ? '' : '&$q'}';
}

/// 앱이 다리를 부를 때 붙이는 머리값 (다리가 남의 사용을 막는 데 씀)
const dgHeaders = {'X-App': 'dongne'};

/// 부르기 (응답 그대로). 시간 초과 10초.
Future<http.Response> dgGet(String url, {int cache = 30}) =>
    http.get(Uri.parse(dgUrl(url, cache: cache)), headers: kDataProxy.isNotEmpty ? dgHeaders : const {}).timeout(const Duration(seconds: 10));
