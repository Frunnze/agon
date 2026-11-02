import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/qr_code_scanner.dart';

final class FixedQrCodeScanner implements QrCodeScanner {
  FixedQrCodeScanner(this.scannedText);

  final String? scannedText;
  int scanCount = 0;

  @override
  Future<String?> scanQrCode(BuildContext context) async {
    scanCount += 1;
    return scannedText;
  }
}
