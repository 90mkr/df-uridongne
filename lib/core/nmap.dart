// 네이버 지도 (본부 방만 고침): 휴대폰 앱에서는 네이버 지도, 웹 미리보기에서는 기존 오픈스트리트맵.
// 기능 방은 core/map.dart 의 DongneMap 을 쓰면 알아서 바뀐다.
export 'nmap_stub.dart' if (dart.library.io) 'nmap_native.dart';
