// 이웃 제보: 「지금 자리 많아요」·「꽉 찼어요」 (이 폴더는 주차장 담당 방만 고침)
// 파이어베이스 dn_parking_busy — 문서 번호 = 주차장id_uid_30분칸 → 같은 사람은 한 주차장에 30분에 한 번만.
// 최근 1시간 제보만 보여 준다. 쓰기 규칙은 본부에 요청 (requests/parking-1123-이웃제보-쓰기규칙.md).
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../core/fb.dart';
import '../../core/me.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class Busy {
  final String kind; // 'many' · 'full'
  final DateTime at;
  const Busy(this.kind, this.at);
  String get label => kind == 'many' ? '자리 많아요' : '꽉 찼어요';
}

String _lid(String id) => id.replaceAll('/', '_');

Future<List<Busy>> recentBusy(String lotId) async {
  if (!await fbReady()) return const [];
  try {
    final q = await db.collection('dn_parking_busy').where('lid', isEqualTo: _lid(lotId)).get();
    final since = DateTime.now().subtract(const Duration(hours: 1));
    final out = <Busy>[
      for (final d in q.docs)
        if (d.data()['at'] is fs.Timestamp) Busy('${d.data()['kind']}', (d.data()['at'] as fs.Timestamp).toDate())
    ]..removeWhere((b) => b.at.isBefore(since));
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  } catch (_) {
    return const [];
  }
}

Future<String?> sendBusy(String lotId, String kind) async {
  if (!await fbReady()) return '지금은 보낼 수 없어요';
  final u = me;
  if (u == null) return 'login';
  final slot = DateTime.now().millisecondsSinceEpoch ~/ (30 * 60 * 1000);
  final lid = _lid(lotId);
  final ref = db.collection('dn_parking_busy').doc('${lid}_${u.uid}_$slot');
  try {
    final old = await ref.get();
    if (old.exists) return '30분 안에 이미 알려 주셨어요';
    await ref.set({'lid': lid, 'uid': u.uid, 'slot': slot, 'kind': kind, 'at': fs.FieldValue.serverTimestamp()});
    return null;
  } catch (_) {
    return '보내지 못했어요. 잠시 뒤 다시 해 주세요';
  }
}

String ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  return m < 1 ? '방금' : '$m분 전';
}

// 주차장 창 안의 이웃 제보 줄
class BusyBox extends StatefulWidget {
  final String lotId;
  const BusyBox({super.key, required this.lotId});
  @override
  State<BusyBox> createState() => _BusyBoxState();
}

class _BusyBoxState extends State<BusyBox> {
  List<Busy>? list;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await recentBusy(widget.lotId);
    if (mounted) setState(() => list = v);
  }

  Future<void> _send(String kind) async {
    if (sending) return;
    setState(() => sending = true);
    final r = await sendBusy(widget.lotId, kind);
    if (!mounted) return;
    setState(() => sending = false);
    if (r == 'login') {
      toast(context, '로그인하면 이웃에게 알려 줄 수 있어요');
      openLogin(context);
      return;
    }
    toast(context, r ?? '고마워요. 이웃에게 1시간 동안 보여요');
    if (r == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = list ?? const <Busy>[];
    final last = l.isEmpty ? null : l.first;
    final many = l.where((b) => b.kind == 'many').length, full = l.length - many;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('이웃 제보', style: T.title),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              list == null
                  ? '확인하는 중…'
                  : last == null
                      ? '최근 1시간 제보가 없어요'
                      : '${ago(last.at)} · ${last.label}${l.length > 1 ? '  (1시간 동안 많아요 $many · 꽉 $full)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: last == null ? kMute : kInk, fontWeight: last == null ? FontWeight.w400 : FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Btn('지금 자리 많아요', h: 38, onTap: () => _send('many'))),
          const SizedBox(width: 8),
          Expanded(child: Btn('꽉 찼어요', h: 38, onTap: () => _send('full'))),
        ]),
      ]),
    );
  }
}
