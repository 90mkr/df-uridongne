{{flutter_js}}
{{flutter_build_config}}

// 새로 올린 화면이 바로 보이도록 서비스 워커(오프라인 저장본)를 쓰지 않는다.
// 예전에 등록된 것이 있으면 해제한다.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function (list) {
    list.forEach(function (r) { r.unregister(); });
  });
}
_flutter.loader.load();
