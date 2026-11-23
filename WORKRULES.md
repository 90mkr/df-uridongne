# 우리동네 작업 규칙

여러 방(대화창)이 한 저장소를 나눠 고칩니다. 모든 방은 작업 전에 이 문서와 작업판을 읽습니다.

- 저장소: https://github.com/90mkr/df-uridongne
- 작업판: https://90mkr.github.io/df-uridongne/board.html (내용은 `board/<기능>.json`)
- 크롬 미리보기: https://90mkr.github.io/df-uridongne/
- 안드로이드 설치 파일: https://github.com/90mkr/df-uridongne/releases/tag/latest
- 기획서: https://claude.ai/artifact/CejsWFXn4ZxFhfqgg6JC4R · 시안: https://claude.ai/artifact/6fbNkjEBNwGQ1rVx6TGNUg

## 1. 누가 어디를 고치나

| 곳 | 고치는 방 |
|---|---|
| `lib/core/` (화면 틀·하단 메뉴·지도·로그인·단지 고르기·디자인 규칙·공용 부품) | 본부 방만 |
| `lib/main.dart`, `lib/features/registry.dart`(기능 등록부) | 본부 방만 |
| `.github/`, `pubspec.yaml`, `tool/`, `collector/collect.py`, `firestore.dongne.rules`, `web/*.html`(우편번호 제외), `web/policy/` | 본부 방만 |
| `lib/features/<기능>/` | 그 기능 담당 방만 |
| `collector/features/<기능>.py`, `web/data/<기능>/` | 그 기능 담당 방만 |
| `board/<기능>.json` | 그 기능 담당 방 (본부는 `board/core.json`) |
| `requests/` | 누구나 **새 파일만** 만든다 (남의 파일은 안 고침) |

- 기능 방은 **자기 폴더 밖을 고치지 않습니다.** 다른 기능 폴더의 코드를 가져다 쓰는 것도 하지 않습니다 (필요하면 본부에 공용으로 올려 달라고 요청).
- 공통 부분을 바꿔야 하면 `requests/` 에 요청 파일을 하나 새로 만들고 본부 방을 기다립니다. 그동안은 자기 폴더 안에서 임시로 해결합니다.

## 2. 작업 순서 (모든 방 공통)

1. **최신 받기**: `git pull --rebase origin main`
2. **작업판 확인**: `board/` 를 읽는다. 다른 방이 「작업 중」인 기능은 손대지 않는다.
3. **찜**: 내 `board/<기능>.json` 을 `"state": "작업 중"`, `"room"`, `"doing"`, `"updated"` 로 고쳐 바로 올린다.
4. **작업**: 내 폴더 안에서만.
5. **점검**: `check` 갈래에 올려 코드 검사를 통과시킨다 → `git push origin HEAD:check` (깃허브 「코드 점검」이 초록이면 통과)
6. **올리기**: 끝나면 바로 `main` 에 올린다. 오래 쥐고 있지 않는다 (작게 자주).
7. **작업판 정리**: `version` 올리고 `"state": "완료"` 또는 `"대기"`, `doing` 에 다음 할 일.
8. 멈출 때는 `"state": "멈춤"` 과 무엇을 기다리는지 `doing` 에 적는다.

올리다가 충돌이 나면 `git pull --rebase origin main` 뒤 다시 올립니다. **남의 폴더 변경을 되돌리거나 덮지 않습니다.**

## 3. 기능이 앱에 붙는 방식

기능 하나 = `lib/features/<기능>/feature.dart` 의 `Feature` 하나 (자세한 설명: `lib/core/feature.dart` 맨 위).

| 자리 (slot) | 단지 홈에서 | 예 |
|---|---|---|
| `header` | 머리 줄 오른쪽 작은 표시 | 날씨·미세먼지 |
| `hero` | 맨 위 큰 파랑 카드 「오늘의 단지 소식」 | 쓰레기·분리수거 |
| `half` | 두 칸짜리 반쪽 카드 | 단지 앞 버스 · 지금 문 연 약국 |
| `section` | 가로 꽉 찬 묶음 카드 | 동네 전화번호부 |
| `wide` | 가로 꽉 찬 한 줄 카드 | 우리 단지 최근 거래 |
| `tool` | 「생활 도구」 줄 작은 칸 | 주유소 · 충전소 · 주차장 · 우편번호 |

- `homeCard()` → 단지 홈 카드 **하나** (틀은 `HomeCardBox`, 맨 위 파랑 카드만 직접 그림)
- `page()` → 카드를 누르면 열리는 상세 화면 (틀은 `DetailPage`)
- `mapPoints()` → 「지도」 탭에 올릴 점 (`ready` 가 true 인 기능만 칩으로 나옴)
- 생활 도구 탭에는 모든 기능이 자동으로 나옵니다.
- 기준 위치는 언제나 **고른 단지** (`c.pos`). 단지가 바뀌면 화면이 다시 그려집니다.
- 다 만들면 `ready => true`, `version` 을 작업판과 같게.

## 4. 디자인 규칙 (`lib/core/theme.dart`)

- 글꼴 Pretendard. 제목은 굵은 말 + 가는 말 (`MixTitle('동네', '전화번호부')`).
- 강조색은 파랑(`kBlue`) 하나. 줄마다 반복되는 표시는 회색, 파랑은 꼭 짚을 것 하나에만.
- 카드: 흰 바탕 · 둥근 모서리 14 · 1px 옅은 선 · 아주 옅은 그림자 → `cardBox()`. 테두리는 1px 넘게 쓰지 않음.
- 아이콘: 가는 선 + 옅은 면 (`LineIcon`). 동그라미 안에 넣지 않음. 새 아이콘이 필요하면 본부에 요청 (그동안은 자기 폴더에 임시로 그려도 됨).
- 글자는 작고 촘촘하게 (본문 13, 보조 11.5, 작은 글 10.5), 휴대폰 양옆 여백 20.
- 가로가 넓어지면 가운데 최대 폭 720.
- 같은 모양 상자를 반복해 늘어놓지 않기. 휴대폰에서 표·단계는 줄바꿈 대신 옆으로 밀기.
- 공공데이터는 늦을 수 있으니 약국·병원 등에는 「방문 전 전화로 확인」 안내.

## 5. 자료와 열쇠값

- **자주 안 바뀌는 자료**(업체·주차장·쓰레기 요일 등): `collector/features/<기능>.py` 가 미리 모아 `web/data/<기능>/` 에 저장 → 앱은 `getJson('${dataBase}<기능>/…json')` 으로 받음. 매주 월요일 새벽 자동, 깃허브 Actions 「앱 제작」 수동 실행도 가능.
- **실시간 자료**(버스 도착·지금 문 연 약국·충전기 상태·날씨): 앱이 화면을 열 때 그 단지 것만 부른다. 같은 것은 30초 안에 다시 부르지 않기.
- 열쇠값은 코드에 적지 않는다. `lib/core/keys.dart` 의 `kDataGoKrKey` 등을 쓴다 (깃허브 비밀 → 자동 제작이 넣음). 새 열쇠가 필요하면 본부에 요청.
- 크롬 미리보기(웹)에서는 공공데이터 서버가 막혀(CORS) 실시간 자료가 안 뜰 수 있다 → 안드로이드 설치 파일로 확인하거나, 미리 모은 자료로 보여 준다.
- 파이어베이스 저장 칸은 `dn_<기능>_…` 로 시작 (예: `dn_trash_days`). 쓰기 규칙이 필요하면 본부에 요청 (규칙 파일은 콕플과 하나라 본부만 게시).
- 휴대폰 기억 칸은 `prefGet('<기능>.이름')` 처럼 기능 이름을 앞에.

## 6. 버전

`0.<큰 변화>.<작은 변화>` — 올릴 때마다 작은 수 하나 올림. `feature.dart` 의 `version` 과 작업판의 `version` 을 같게.

## 공공데이터 부르기 (11-23 본부)
- apis.data.go.kr 는 **반드시 `lib/core/dg.dart` 의 `dgGet(url)` (또는 `dgUrl(url)`)** 로 부른다. 주소에 serviceKey 를 넣지 않는다.
- 다리(클라우드플레어 dongne-dari)가 열쇠를 붙이고 30초 묶어 둔다. 잘 안 바뀌는 목록은 `cache: 43200`.
- 「열쇠 있나」 확인은 `hasDataKey` 만 쓴다 (`kDataGoKrKey.isEmpty` 직접 확인 금지 — 곧 앱에서 열쇠를 뺌).
- 모든 기능이 옮기면 본부가 앱 제작에서 DATA_GO_KR_KEY 를 뺀다.

## 지도는 공용 지도로 (11-24 본부 · 대표님 지시: 네이버 지도로 통일)
휴대폰 앱은 **네이버 지도**, 웹 미리보기는 오픈스트리트맵으로 자동으로 바뀌는 공용 지도가 있다. **`FlutterMap` 을 직접 쓰지 말 것.**
- 점만 찍으면 되는 지도: `core/map.dart` 의 `DongneMap(points: [MapPoint...], icon: '기능아이콘')`
- 내 모양 점·선·원이 필요한 지도: `core/dnmap.dart` 의 `DnMap`
  - 점 `DnMark(id, pos, key, size, child: 내 위젯, onTap)` — 아래 가운데가 위치. **모양이 바뀌면 key 도 바꿀 것** (예: `'${s.id}|${s.price}|$sel'`). 네이버 지도는 위젯을 그림으로 한 번 바꿔 다시 쓴다.
  - 선 `DnLine(points)` (버스 노선) · 원 `DnCircle(pos, 미터)` (반경 표시)
  - 조종 `DnMapCtl` → `ctl.move(pos, 16)` · `ctl.fit([a, b], EdgeInsets.all(60))`
  - 지도 누름 `onMapTap`, 움직임 끝 `onIdle(center, zoom, bounds, gesture)`
  - 우리 단지 파란 이름표는 자동으로 들어감 (따로 그리지 말 것)

### 바꿔 주세요 (방마다)
- 버스: `bus/route_page.dart` 노선 지도 → `DnMap(lines: [DnLine(line)], marks: 정류장 점)`
- 주유소: `gas/page.dart` 가격 말풍선 지도 → `DnMap(marks: [DnMark(child: _Bubble(...))], circles: 반경)`
- 충전소: `charger/page.dart` → `DnMap(marks: ...)`
- 약국: `pharmacy/page.dart` → `DnMap(marks: ..., ctl: 로 처음 화면 맞추기 fit)`
바꾼 뒤 휴대폰 설치 파일에서 네이버 지도로 나오는지 확인하고 작업판에 적을 것.
