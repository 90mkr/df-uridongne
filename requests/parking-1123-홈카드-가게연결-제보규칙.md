# 주차장 방 → 본부 요청 (11-23 23:00) — 주차장 0.2.0

대표님 주차장 기능 지시(내 차 어디 댔지 · 단지 홈 카드 · 가게 연결 · 이웃 제보)에 필요한 공통 부분입니다.
주차장 쪽 코드는 모두 만들어 두었고, 아래만 붙여 주시면 바로 동작합니다.

## 1. 단지 홈 맨 위 「주차 중」 카드 (급함: 보통)
- `lib/core/home.dart` 의 `_body` 맨 위(hero 카드 위)에 `ParkingFeature.topCard()` 한 줄.
- 주차 중이 아니면 `SizedBox.shrink()` 라 아무것도 안 보입니다. 누르면 내 차 창이 열립니다.
- 더 일반적으로 하시려면 `Feature` 에 `Widget? topCard(BuildContext, Complex)` 를 두고 기능마다 돌려도 됩니다 (그러면 저는 그 이름으로 옮김).

## 2. 가게 화면에 「근처 주차장」 한 줄 (급함: 보통)
- 전화번호부 가게 창(`phonebook/shop_sheet.dart`)의 전화·길안내 버튼 바로 아래:
  `FutureBuilder(ParkingFeature.nearHint(LatLng(s.lat, s.lng)))` → 글자가 있으면 한 줄, 누르면 `ParkingFeature.openNear(context, LatLng(s.lat, s.lng), s.name)`.
- 기능끼리 서로 가져다 쓰지 않는 규칙 때문에 본부(또는 등록부를 통한 공용 연결)로 부탁드립니다. 500m 안 주차장 기준.

## 3. 파이어베이스 쓰기 규칙: `dn_parking_busy` (이웃 제보 「자리 많아요」·「꽉 찼어요」)
문서 번호 = `주차장id_uid_30분칸` → 같은 사람은 한 주차장에 30분에 한 번만 (덮어쓰기 금지). 앱은 `where('lid', ==)` 하나로 읽고 최근 1시간만 보여 줍니다.
```
match /dn_parking_busy/{id} {
  allow read: if true;
  allow create: if request.auth != null
    && request.resource.data.keys().hasOnly(['lid', 'uid', 'slot', 'kind', 'at'])
    && request.resource.data.uid == request.auth.uid
    && request.resource.data.slot is int
    && id == request.resource.data.lid + '_' + request.auth.uid + '_' + string(request.resource.data.slot)
    && request.resource.data.at == request.time
    && request.resource.data.lid is string && request.resource.data.lid.size() <= 40
    && request.resource.data.kind in ['many', 'full'];
  allow update: if false;
  allow delete: if isAdmin();
}
```

## 4. 휴대폰 알림 (충전소 요청과 같은 것 — 함께 쓰겠습니다)
「무료 시간 끝나기 10분 전」 알림이 지금은 앱이 켜진 동안만 뜹니다. 충전소 방이 요청한 `notifyAt / cancelNotify` 가 생기면 `parking/car.dart` 의 `_watch()` 한 곳만 바꿉니다.

## 5. 사진 1장 (층·구역 사진)
「내 차」에 층·구역 사진을 찍어 두려면 `image_picker` 패키지가 필요합니다 (`pubspec.yaml`, 안드로이드 카메라 권한). 사진은 휴대폰 안에만 저장합니다 (서버로 안 보냄). 생기면 알려 주세요 — 지금은 층·구역 메모로 대신합니다.

- 작업판: 주차장 0.2.0
