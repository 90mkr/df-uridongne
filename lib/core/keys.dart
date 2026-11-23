// 공공데이터 등 열쇠값 (본부 방만 고침)
// 값은 코드에 적지 않는다. 깃허브 비밀(Settings → Secrets)에 넣으면 자동 제작이 --dart-define 으로 넣어 준다.
// 기능 방이 새 열쇠가 필요하면 본부 방에 「비밀 이름」을 요청한다.
const kDataGoKrKey = String.fromEnvironment('DATA_GO_KR_KEY'); // 공공데이터포털 (약국·버스·쓰레기·실거래가·주차장 등)
const kOpinetKey = String.fromEnvironment('OPINET_KEY'); // 오피넷 (주유소)
const kAirKoreaKey = String.fromEnvironment('AIRKOREA_KEY'); // 에어코리아 (미세먼지) — 비면 kDataGoKrKey 사용
const kEvKey = String.fromEnvironment('EV_KEY'); // 환경부 충전소 — 비면 kDataGoKrKey 사용

bool get hasDataKey => kDataGoKrKey.isNotEmpty;
