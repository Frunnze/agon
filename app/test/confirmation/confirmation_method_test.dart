import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/confirmation.dart';

const String _appleDesktopMethod = 'Touch ID';

void main() {
  test('test_describe_confirmation_method_property_names_each_platform', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final String methodName = describeConfirmationMethod(platform);

      expect(methodName.trim(), isNotEmpty, reason: platform.name);
      if (platform != TargetPlatform.macOS) {
        expect(methodName, isNot(_appleDesktopMethod), reason: platform.name);
      }
    }
    expect(describeConfirmationMethod(TargetPlatform.macOS), 'Touch ID');
    expect(describeConfirmationMethod(TargetPlatform.android), 'fingerprint');
  });
}
