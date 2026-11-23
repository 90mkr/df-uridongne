# 우리동네 (df-uridongne)

> 작업 규칙: [WORKRULES.md](WORKRULES.md) · 작업판: https://90mkr.github.io/df-uridongne/board.html

디자인필 생활정보 앱 — 아파트 단지 하나를 고르면 쓰레기 배출일·버스·약국·동네 전화번호부·실거래가 같은 생활 정보가 한 화면에 모인다.

```
lib/core/          공통 (본부 방)
lib/features/<기능>/ 기능별 (담당 방)
lib/features/registry.dart 기능 등록부 (본부 방)
```

- 앱: 플러터 (안드로이드·아이폰 공용), 고유 이름 `kr.designfeel.dongne`
- 자료: `collector/collect.py`가 카카오 장소 검색으로 동네별 업체를 모아 `web/data/<동네id>.json`에 저장 (매주 월요일 새벽 자동)
- 콕플 연계: 동네 id를 콕플과 같이 써서 같은 동네의 콕플 맛집(구글 별점·유튜브)을 그대로 붙여 보여 줌
- 파이어베이스: 콕플과 같은 「디자인필」 프로젝트(kokple)를 같이 씀. 사장님 등록·정보 수정 신고는 `dn_reqs`
  - 규칙은 `firestore.dongne.rules` 블록을 콕플 규칙(`df-app-lab/firestore.rules`) 안에 함께 넣어 게시해야 함 (한 프로젝트에 규칙 파일은 하나)
- 크롬 미리보기: https://90mkr.github.io/df-uridongne/
- 안드로이드 설치 파일: 깃허브 Releases의 `latest`
