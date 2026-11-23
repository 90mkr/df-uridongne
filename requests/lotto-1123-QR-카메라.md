# 복권 방 요청: 앱 안에서 QR 읽기 (카메라)

- 무엇: 휴대폰 카메라로 QR 을 읽는 공용 부품
  1. `pubspec.yaml` 에 `mobile_scanner` 추가
  2. 안드로이드 카메라 권한 (`tool/patch_android.py` 로 AndroidManifest 에 `android.permission.CAMERA`, `uses-feature camera required=false`)
  3. `lib/core/` 에 공용 함수 하나: `Future<String?> scanQr(BuildContext context, {String title = 'QR 읽기'})`
     — 전체 화면 카메라 + 가운데 네모 틀 + 플래시 켜기, 읽히면 글자 그대로 돌려주고 닫힘. 웹(크롬 미리보기)에서는 null.
- 왜: 대표님이 로또 용지 QR 로 당첨 확인을 원하심. 해석(회차·게임 번호)은 복권 폴더(`parseTicketQr`)에 이미 있음.
  지금은 「QR로 확인」을 누르면 QR 주소 붙여 넣기 창이 대신 뜸 (`lib/features/lotto/widgets.dart` 의 `scanTicket`).
- 처리되면 복권 방이 `scanTicket` 안에서 `scanQr` 를 부르도록 바꿈 (복권 폴더 안만 고침).
- 다른 기능도 쓸 수 있음 (예: 사장님 등록 때 사업자 QR, 주차장 QR 등).
- 급한 정도: 보통 (복권 화면 1차는 이것 없이도 돌아감)
- 작업판 버전: lotto 0.1.0
