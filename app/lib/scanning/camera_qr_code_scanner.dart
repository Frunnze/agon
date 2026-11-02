import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/qr_code_scanner.dart';
import 'package:agent_orchestration/scanning/qr_scanner_page.dart';

final class CameraQrCodeScanner implements QrCodeScanner {
  const CameraQrCodeScanner();

  @override
  Future<String?> scanQrCode(BuildContext context) {
    final NavigatorState navigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    return navigator.push<String>(
      MaterialPageRoute<String>(builder: _buildScannerPage),
    );
  }

  Widget _buildScannerPage(BuildContext context) => const QrScannerPage();
}
