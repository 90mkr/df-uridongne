# 날씨 방 요청: 아침 날씨 알림 (공용 알림 기능)

- 무엇: 휴대폰 알림을 정해진 아침 시각에 띄우는 공용 기능
  - 날씨 방은 설정과 알림 글만 갖고 있음
    - 켜짐/꺼짐: `prefGet('weather.alarm')` → `'1'` / `'0'`
    - 시각: `prefGet('weather.alarmTime')` → `'07:00'`
    - 알림 글: `lib/features/weather/api.dart` 의 `morningBrief(Weather w)` — 특별한 게 없는 날은 `null` (이때는 보내지 않음)
    - 날씨 받기: `weatherFor(complex)` (고른 단지 기준)
  - 본부가 할 일: 정한 시각에 앱이 깨어나 `weatherFor` → `morningBrief` → 글이 있으면 알림 하나 띄우기
    - 예: flutter_local_notifications + workmanager(안드로이드 주기 작업) — pubspec·AndroidManifest(알림 권한, 정확한 알람 권한) 변경이 필요해 본부 소관
    - 알림 제목 「우리동네 날씨」, 본문은 `morningBrief` 글 그대로 (줄바꿈 = 항목 여러 개)
- 왜: 대표님 명세 「아침 알림 (원하는 사람만, 시간 선택) · 특별한 게 없는 날은 보내지 않기」
- 급한지: 보통 (화면·설정은 날씨 0.2.0에 이미 들어감, 켜면 「다음 업데이트부터」 안내)
- 작업판 버전: weather 0.2.0

## 함께 확인 부탁 (공공데이터포털 신청)
날씨 0.2.0이 아래 서비스를 부릅니다. 신청·승인이 안 된 것이 있으면 그 칸만 비어 보이고 나머지는 정상입니다.
- 기상청 중기예보 조회서비스 (MidFcstInfoService) — 이번 주 10일 예보
- 기상청 기상특보 조회서비스 (WthrWrnInfoService) — 특보 강조
- 기상청 생활기상지수 조회서비스(3.0) (LivingWthrIdxServiceV4) — 자외선·동파
- 한국환경공단 에어코리아 측정소정보 (MsrstnInfoInqireSvc) — 가장 가까운 측정소 (없으면 동네 이름으로 대신 찾음)
