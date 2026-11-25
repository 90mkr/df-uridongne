# 지원금·혜택 방 → 본부 요청 (11-25, benefit 0.1.0)

대표님 지시(요청서 board-1125 의 4번): 「우리 동네 지원금·혜택」은 화면·자료를 따로 만든 별도 기능이고, 커뮤니티에서는 카드로 연결만 한다.
만든 곳: `lib/features/benefit/` · `collector/features/benefit.py` · `web/data/benefit/` · `board/benefit.json`

## 1. 등록부에 한 줄 (급함: 보통)
- `lib/features/registry.dart` 에 `import 'benefit/feature.dart';` + `BenefitFeature(), // 생활 도구 + 커뮤니티 카드: 우리 동네 지원금·혜택`
- 자리는 `Slot.tool` (생활 도구 칸). 단지 홈 카드는 없음.

## 2. 매일 모으기 + 열쇠 (급함: 높음 — 이게 돼야 자료가 생김)
- `build.yml` 하루 3번 갈래 `FEATURES` 에 `benefit` 추가 (`gas,events` → `gas,events,benefit`). 스스로 「20시간 안에 받았으면 건너뜀」이라 실제로는 하루 한 번만 받음.
- 같은 단계 env 에 `YOUTH_KEY: ${{ secrets.YOUTH_KEY }}` 추가 (온통청년 청년정책 인증키 — 깃허브 비밀은 대표님 키 받으면 등록). 없으면 청년정책만 건너뛰고 나머지는 돌아감.
- 넣은 뒤 「앱 제작」 수동 실행 `only_features: true`, `features: benefit` 로 한 번 돌려서 결과(로그 첫 줄들)를 작업판에 남겨 주세요. 처음엔 FORCE 없이도 받음(meta 없음).
- 정부24 혜택은 `DATA_GO_KR_KEY` 로 `api.odcloud.kr/api/gov24/v3/` 를 부름 — 공공데이터포털 「행정안전부_대한민국 공공서비스(혜택) 정보」(15113968) 활용신청이 필요(자동승인). 로그에 「목록을 받지 못함」이 나오면 활용신청 안 된 것.

## 3. 커뮤니티 첫 화면 카드 (게시판 담당 — 지금은 본부)
- 커뮤니티 포털식 첫 화면(board-1125 의 1번) 위쪽에 큰 카드 하나: 「우리 동네 지원금·혜택」 → 누르면 `openFeature(context, featureById('benefit')!)`.
- 카드 글 예: 굵게 「연수구 지원금·혜택」 + 가늘게 「312가지」 / 작은 글 「몰라서 못 받는 혜택, 나이대·자녀만 고르면 추려 드려요」
- 숫자는 코드 가져다 쓰지 말고 자료로: `${dataBase}benefit/meta.json` 의 `c[시군구코드]`(우리 구) + `s[시도코드]` + `n`(전국). 시군구코드는 동네 id 에서 `k(\d{5})`, 송도는 `28185`.

## 4. 아이콘 (급함: 낮음)
- `benefit` 아이콘(선물 상자나 동전 주머니 — 가는 선 + 옅은 면). 지금은 임시로 `public` 을 씀. 생기면 기능 방이 `icon` 만 바꿈.

## 5. (참고) 자료 크기
- 목록: `n.json`(전국 수천 건, 목록 줄만), `s_<시도>.json`, `l_<시군구>.json`. 자세히는 `d_00~63.json` 로 나눠 누를 때만 받음. 바뀐 파일만 다시 씀.
- 나중에 store(R2)로 옮길 때 같이 옮겨 주세요. 앱은 `${dataBase}benefit/` 한 곳에서만 읽음.
