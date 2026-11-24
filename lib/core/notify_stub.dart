// 웹 미리보기: 알림·알람 없음
bool get canNotify => false;
Future<void> initNotify() async {}
Future<bool> askNotePermission() async => false;
Future<void> scheduleNote(int id, DateTime when, String title, String body) async {}
Future<void> cancelNote(int id) async {}
Future<bool> setPhoneAlarm(int hour, int minute, String label, List<int> days) async => false;
