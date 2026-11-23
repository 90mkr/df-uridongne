# 연휴에 문 여는 약국 — 단지 홈에 따로 뜨는 카드 자리

- 기능: 지금 문 연 약국 (작업판 0.2.0)
- 급함: 보통 (다음 공휴일 12/25 전까지면 좋음)

대표님 지시: 연휴 3일 전부터 단지 홈에 「연휴에 문 여는 약국」 카드를 **따로** 자동 표시.
지금 Feature 는 홈 카드가 하나(homeCard)뿐이라, 약국 반쪽 카드 아래쪽 글(foot)을 「연휴에 문 여는 약국 보기 ›」로 바꿔 두는 것으로 임시 처리했습니다.

요청: 기능이 때때로 홈 맨 위(오늘의 단지 소식 바로 아래)에 알림 카드 하나를 더 낼 수 있는 자리
예) `Feature` 에 `Widget? noticeCard(BuildContext context, Complex c) => null;` 를 두고 home.dart 에서 hero 다음에 null 이 아닌 것만 그리기.
약국 쪽은 준비돼 있습니다: `lib/features/pharmacy/page.dart` 의 `HolidayPage`, `data.dart` 의 `holidayRun(now)` (3일 안에 시작하는 연휴 날짜 목록, 아니면 빈 목록).
자리가 생기면 약국 방이 noticeCard 를 채웁니다.
