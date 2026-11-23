// 공공데이터 등 열쇠값 (본부 방만 고침)
// 값은 코드에 적지 않는다. 깃허브 비밀(Settings → Secrets)에 넣으면 자동 제작이 --dart-define 으로 넣어 준다.
// 기능 방이 새 열쇠가 필요하면 본부 방에 「비밀 이름」을 요청한다.
const kDataGoKrKey = String.fromEnvironment('DATA_GO_KR_KEY'); // 공공데이터포털 (약국·버스·쓰레기·실거래가·주차장 등)
const kOpinetKey = String.fromEnvironment('OPINET_KEY'); // 오피넷 (주유소)
const kAirKoreaKey = String.fromEnvironment('AIRKOREA_KEY'); // 에어코리아 (미세먼지) — 비면 kDataGoKrKey 사용
const kEvKey = String.fromEnvironment('EV_KEY'); // 환경부 충전소 — 비면 kDataGoKrKey 사용

// 공공데이터 「중간 다리」 (클라우드플레어 워커 dongne-dari, 코드 proxy/worker.js)
// 열쇠는 다리 서버에만 있고, 앱·미리보기는 다리를 부른다 → 크롬 미리보기(CORS)·열쇠 노출·한도 낭비 해결
// 기능 방은 apis.data.go.kr 주소를 lib/core/dg.dart 의 dgUrl()/dgGet() 으로 감싸면 된다.
const kDataProxy = String.fromEnvironment('DATA_PROXY', defaultValue: 'https://dongne-dari.dfmail.workers.dev');

// 공공데이터를 부를 수 있는지 (다리가 있거나 열쇠가 있으면)
bool get hasDataKey => kDataProxy.isNotEmpty || kDataGoKrKey.isNotEmpty;
