# 쓰레기 방 요청: 「우리 단지 배출 요일」 파이어베이스 쓰기 규칙

- 무엇: `dn_trash_days/{단지id}` 문서 읽기·쓰기 규칙 게시
- 왜: 아파트는 관리사무소가 요일을 정하는 경우가 많아, 주민이 단지별 요일을 넣고 고치게 함 (앱 0.1.0 에 화면은 이미 있음 — 규칙이 없어 지금은 저장하면 「저장하지 못했어요」가 뜸)
- 급한지: 보통 (지자체 자료는 규칙 없이도 나옴)
- 작업판 버전: trash 0.1.0

앱이 쓰는 칸: g·f·r(요일 글자 '월수금' 등, 7자 이하) · s·e('18:00' 모양, 비어도 됨) · note(80자 이하) · apt(단지 이름) · uid · name · at(서버 시각)

제안 규칙 (firestore.dongne.rules 에 추가):

```
    // 우리 단지 배출 요일: 누구나 보기 · 로그인 회원이 쓰기(자기 uid로) · 지우기는 관리자
    match /dn_trash_days/{cid} {
      allow read: if true;
      allow create, update: if request.auth != null
        && request.resource.data.keys().hasOnly(['g', 'f', 'r', 's', 'e', 'note', 'apt', 'uid', 'name', 'at'])
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.at == request.time
        && request.resource.data.g is string && request.resource.data.g.size() <= 7
        && request.resource.data.f is string && request.resource.data.f.size() <= 7
        && request.resource.data.r is string && request.resource.data.r.size() <= 7
        && request.resource.data.s is string && request.resource.data.s.size() <= 5
        && request.resource.data.e is string && request.resource.data.e.size() <= 5
        && request.resource.data.note is string && request.resource.data.note.size() <= 80
        && request.resource.data.apt is string && request.resource.data.apt.size() <= 60
        && request.resource.data.name is string && request.resource.data.name.size() <= 40;
      allow delete: if isAdmin();
    }
```
