# 충전소 방 → 본부 요청 (11-23 22:30) — 충전소 0.2.0

## 1. 휴대폰 알림 공용 부품 (급함: 보통)
충전소의 「빈자리 알림」「충전 타이머(완료·급속 1시간 과태료 안내)」는 지금 **앱이 켜져 있는 동안만** 앱 안에서 진동+알림 창으로 알립니다.
앱을 닫거나 화면이 꺼져도 울리려면 휴대폰 알림이 필요합니다.

- `pubspec.yaml` 에 `flutter_local_notifications`(+ `timezone`) 추가, 안드로이드 알림 권한(POST_NOTIFICATIONS)·정확한 알람 권한 처리
- `lib/core/` 에 공용 함수 두 개 부탁드립니다
  - `notifyNow(String title, String body)` — 바로 알림
  - `notifyAt(int id, DateTime at, String title, String body)` / `cancelNotify(int id)` — 예약 알림 (충전 타이머)
- 생기면 충전소는 `lib/features/charger/watch.dart` 의 `notify()` 한 곳만 바꿉니다.
- 빈자리 알림은 앱이 꺼져 있으면 상태를 확인할 수 없어(백그라운드 실행 필요) 일단 「앱이 켜진 동안 + 예약 알림」으로 가고, 필요하면 나중에 서버 쪽(파이어베이스 함수)으로 옮깁니다.

## 2. 파이어베이스 쓰기 규칙: `dn_charger_reports` (고장 제보)
문서 번호 = `충전소ID_충전기ID_uid_yyyyMMdd` → 같은 사람은 한 충전기에 하루 한 번만 (덮어쓰기 금지).

```
match /dn_charger_reports/{id} {
  allow read: if true;
  allow create: if request.auth != null
    && request.resource.data.keys().hasOnly(['sid', 'cid', 'uid', 'day', 'kind', 'text', 'at'])
    && request.resource.data.uid == request.auth.uid
    && id == request.resource.data.sid + '_' + request.resource.data.cid + '_' + request.auth.uid + '_' + request.resource.data.day
    && request.resource.data.at == request.time
    && request.resource.data.sid is string && request.resource.data.sid.size() <= 40
    && request.resource.data.cid is string && request.resource.data.cid.size() <= 10
    && request.resource.data.day is string && request.resource.data.day.size() == 8
    && request.resource.data.kind is string && request.resource.data.kind.size() <= 20
    && request.resource.data.text is string && request.resource.data.text.size() <= 80;
  allow update: if false;
  allow delete: if isAdmin();
}
```
(앱은 `where('sid', ==)` 하나로만 읽어서 따로 색인은 필요 없습니다.)

- 작업판 버전: 충전소 0.2.0
