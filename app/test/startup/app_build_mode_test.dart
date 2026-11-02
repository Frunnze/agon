import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/startup/app_build_mode.dart';

void main() {
  test('test_read_app_build_mode_property_follows_the_compiled_mode', () {
    const AppBuildMode expectedMode = kDebugMode
        ? AppBuildMode.debug
        : AppBuildMode.release;

    for (int i = 0; i < 3; i += 1) {
      expect(readAppBuildMode(), expectedMode);
    }
  });
}
