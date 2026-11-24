// 알림·시계 알람 (본부 방만 고침): 휴대폰 앱에서만 동작, 웹 미리보기에서는 아무것도 안 함.
//   scheduleNote(id, 언제, 제목, 내용) — 정해진 때 알림 (기념일 등)
//   cancelNote(id) · askNotePermission()
//   setPhoneAlarm(시, 분, 이름, 요일) — 휴대폰 기본 시계 앱에 알람 넣기 (확실히 울리게)
export 'notify_stub.dart' if (dart.library.io) 'notify_native.dart';
