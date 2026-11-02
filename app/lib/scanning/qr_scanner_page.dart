import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

String? findFirstScannedText(BarcodeCapture capture) {
  for (final Barcode barcode in capture.barcodes) {
    final String? text = barcode.rawValue;
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _hasFinished = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(onDetect: _finishWithCapture),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Point the camera at the QR code on your other device.',
                    style: AppTextStyles.bodyBold,
                  ),
                  const Spacer(),
                  AppButton.secondary(
                    label: 'Cancel',
                    onPressed: () => _finish(null),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _finishWithCapture(BarcodeCapture capture) {
    final String? text = findFirstScannedText(capture);
    if (text != null) {
      _finish(text);
    }
  }

  void _finish(String? scannedText) {
    if (_hasFinished) {
      return;
    }

    _hasFinished = true;
    Navigator.of(context).pop(scannedText);
  }
}
