import 'package:flutter/widgets.dart';

abstract interface class QrCodeScanner {
  Future<String?> scanQrCode(BuildContext context);
}
