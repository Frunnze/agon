import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/platform_runner_presence.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';
import 'package:agent_orchestration/storage.dart';

void main() {
  test(
    'test_build_platform_runner_presence_property_only_macos_and_linux',
    () {
      for (final TargetPlatform platform in TargetPlatform.values) {
        final RunnerPresence? presence = buildPlatformRunnerPresence(platform);

        switch (platform) {
          case TargetPlatform.macOS:
            expect(presence?.loginItem, isA<ChannelLoginItem>());
            expect(presence?.trayPresence, isA<ChannelTrayPresence>());
            expect(
              presence?.startAtLoginChoiceStore,
              isA<SharedPreferencesStartAtLoginChoiceStore>(),
            );
          case TargetPlatform.linux:
            expect(presence?.loginItem, isA<XdgAutostartLoginItem>());
            expect(presence?.trayPresence, isA<ChannelTrayPresence>());
            expect(
              presence?.startAtLoginChoiceStore,
              isA<SharedPreferencesStartAtLoginChoiceStore>(),
            );
          case TargetPlatform.windows:
          case TargetPlatform.iOS:
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
            expect(presence, isNull);
        }
      }
    },
  );
}
