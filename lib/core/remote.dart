// 서버 설정 (본부 방만 고침) — 앱 업데이트 없이 바로 바뀌는 것 (WORKRULES 「앱 업데이트 vs 서버」)
// web/data/app.json 하나로:
//   "off":  ["lotto", ...]          기능 급히 숨기기 (홈 카드·생활 도구·지도 칩 모두에서 빠짐)
//   "art":  {"hero": 2, ...}        머리 사진 바꾸기 — web/data/art/<이름>.jpg|png 를 올리고 숫자(판)를 올리면
//                                    앱 안 assets/art/<이름> 대신 서버 그림을 씀 (받기 실패하면 앱 안 그림)
// 앱은 켤 때 휴대폰에 저장해 둔 지난 설정을 먼저 쓰고, 서버에서 새로 받아 저장한다 (몇 초 안 기다림).
import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';

class RemoteCfg {
  final Set<String> off;
  final Map<String, int> art;
  const RemoteCfg({this.off = const {}, this.art = const {}});
  static RemoteCfg from(dynamic j) {
    if (j is! Map) return const RemoteCfg();
    return RemoteCfg(
      off: {for (final x in (j['off'] as List? ?? const [])) '$x'},
      art: {
        for (final e in ((j['art'] as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
    );
  }
}

final remoteCfg = ValueNotifier<RemoteCfg>(const RemoteCfg());

bool remoteOff(String id) => remoteCfg.value.off.contains(id);

Future<void> loadRemote() async {
  try {
    final s = await prefGet('core.remote');
    if (s != null && s.isNotEmpty) remoteCfg.value = RemoteCfg.from(jsonDecode(s));
  } catch (_) {}
  final j = await getJson('${dataBase}app.json', timeout: const Duration(seconds: 3));
  if (j is Map) {
    remoteCfg.value = RemoteCfg.from(j);
    prefSet('core.remote', jsonEncode(j));
  }
}

// 머리·배경 그림: 서버에 새 판이 있으면 서버 그림, 아니면(또는 받기 실패하면) 앱 안 그림
Widget artImage(String asset, {BoxFit? fit, AlignmentGeometry alignment = Alignment.center, FilterQuality filterQuality = FilterQuality.medium, double? width, double? height}) {
  final local = Image.asset(asset, fit: fit, alignment: alignment, filterQuality: filterQuality, width: width, height: height);
  final file = asset.split('/').last;
  final key = file.contains('.') ? file.substring(0, file.lastIndexOf('.')) : file;
  final v = remoteCfg.value.art[key];
  if (v == null || v <= 0) return local;
  return Image.network(
    '${dataBase}art/$file?v=$v',
    fit: fit,
    alignment: alignment,
    filterQuality: filterQuality,
    width: width,
    height: height,
    frameBuilder: (_, child, frame, sync) => frame == null && !sync ? local : child, // 받는 동안은 앱 안 그림
    errorBuilder: (_, __, ___) => local,
  );
}
