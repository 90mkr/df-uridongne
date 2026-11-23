// QR 읽기 공용 부품 (본부 방만 고침)
// 사용: final text = await scanQr(context, title: '로또 용지 QR');  — 읽은 글자 그대로, 취소·웹이면 null
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> scanQr(BuildContext context, {String title = 'QR 읽기'}) async {
  if (kIsWeb) return null; // 크롬 미리보기에서는 카메라를 쓰지 않음
  return Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _QrPage(title: title)));
}

class _QrPage extends StatefulWidget {
  final String title;
  const _QrPage({required this.title});
  @override
  State<_QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<_QrPage> {
  final ctl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
  bool done = false;
  bool torch = false;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _found(BarcodeCapture cap) {
    if (done) return;
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        done = true;
        Navigator.of(context).pop(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const box = 250.0;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: '플래시',
            onPressed: () {
              ctl.toggleTorch();
              setState(() => torch = !torch);
            },
            icon: Icon(torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Stack(alignment: Alignment.center, children: [
        MobileScanner(controller: ctl, onDetect: _found),
        // 가운데 네모 틀 (밖은 살짝 어둡게)
        IgnorePointer(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.45), BlendMode.srcOut),
            child: Stack(alignment: Alignment.center, children: [
              Container(decoration: const BoxDecoration(color: Colors.transparent, backgroundBlendMode: BlendMode.dstOut)),
              Container(width: box, height: box, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16))),
            ]),
          ),
        ),
        IgnorePointer(
          child: Container(
            width: box,
            height: box,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1), borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const Positioned(
          bottom: 60,
          child: Text('QR 을 네모 안에 맞춰 주세요', style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ]),
    );
  }
}
