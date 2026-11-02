import 'package:flutter/foundation.dart';

String describeConfirmationMethod(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.macOS => 'Touch ID',
    TargetPlatform.iOS => 'Face ID',
    TargetPlatform.android => 'fingerprint',
    TargetPlatform.windows => 'Windows Hello',
    TargetPlatform.linux || TargetPlatform.fuchsia => 'passkey',
  };
}
