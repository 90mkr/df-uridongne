// 설정 백업 (본부 방만 고침, 대표님 11-26 「아이콘 배치 등 설정을 저장하려면」)
// 로그인 없이도 설정은 이 휴대폰에 그대로 저장. 로그인해 있으면 서버(dn_my/…/app.settings)에도 저절로 백업되고,
// 다시 깔거나 새 휴대폰에서 로그인하면 우리 단지·홈 배치(크게 보기/아이콘·순서·켜고 끄기)가 되살아난다.
import 'package:flutter/foundation.dart';

import 'data.dart';
import 'fb.dart';
import 'home_layout.dart';
import 'mydata.dart';

const _key = 'app.settings';
String? _lastUid;
bool _started = false;

Future<void> startSettingsSync() async {
  if (_started) return;
  _started = true;
  await fbReady();
  homeLayoutSaved = (_) => _push();
  complex.addListener(_push);
  authTick.addListener(_onAuth);
  _onAuth();
}

Map<String, dynamic> _now() => {'home': homeLayoutJson(), if (complex.value != null) 'complex': complex.value!.toJson()};

void _push() {
  if (me == null) return;
  putMine(_key, _now());
}

Future<void> _onAuth() async {
  final u = me;
  if (u == null) {
    _lastUid = null;
    return;
  }
  if (_lastUid == u.uid) return;
  _lastUid = u.uid;
  try {
    final v = await loadMine(_key);
    // 이 휴대폰에서 아직 손대지 않았거나 이 계정으로 처음 로그인했으면 → 서버 설정으로 되살리기
    final first = (await prefGet('my.restored.${u.uid}')) != '1';
    if (v is Map && (first || !homeLayoutTouched)) {
      if (v['home'] is Map) await applyHomeLayout(v['home'] as Map);
      final c = Complex.fromJson(v['complex']);
      if (c != null && (first || complex.value == null)) await setComplex(c);
      await prefSet('my.restored.${u.uid}', '1');
    } else {
      await prefSet('my.restored.${u.uid}', '1');
      _push(); // 서버에 없으면 지금 설정을 올림
    }
  } catch (e) {
    debugPrint('settings sync: $e');
  }
}
