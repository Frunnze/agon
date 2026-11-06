import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/platform_runner_presence.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

import '../support/random_inputs.dart';

const String _nativeChannelName = 'agent_orchestration/runner_presence';
const String _nativeStayInTrayMethod = 'stayInTray';
const String _nativeLeaveTrayMethod = 'leaveTray';
const String _nativeRegisterMethod = 'registerLoginItem';
const String _nativeUnregisterMethod = 'unregisterLoginItem';
const int _largestBuildCount = 4;
const List<TargetPlatform> _desktopPlatforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.linux,
];

List<String> _listenAsNativeRunner() {
  const MethodChannel nativeChannel = MethodChannel(_nativeChannelName);
  final List<String> receivedMethods = <String>[];
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(nativeChannel, (MethodCall call) async {
    receivedMethods.add(call.method);
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(nativeChannel, null));
  return receivedMethods;
}

RunnerPresence _buildPresenceOn(TargetPlatform platform) {
  final RunnerPresence? presence = buildPlatformRunnerPresence(platform);
  if (presence == null) {
    fail('$platform has no runner presence');
  }
  return presence;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'test_build_platform_runner_presence_property_linux_starts_this_program',
    () {
      final Random random = seededRandom(48201);
      final int buildCount = 1 + random.nextInt(_largestBuildCount);

      for (int i = 0; i < buildCount; i += 1) {
        final RunnerPresence presence = _buildPresenceOn(TargetPlatform.linux);
        final LoginItem loginItem = presence.loginItem;
        if (loginItem is! XdgAutostartLoginItem) {
          fail('Linux starts at login without an autostart entry');
        }

        expect(loginItem.executablePath, Platform.resolvedExecutable);
        expect(loginItem.environment, Platform.environment);
      }
    },
  );

  test(
    'test_build_platform_runner_presence_property_tray_uses_native_names',
    () async {
      final Random random = seededRandom(48202);
      final List<String> receivedMethods = _listenAsNativeRunner();
      final List<String> expectedMethods = <String>[];

      for (int i = 0; i < propertyIterations; i += 1) {
        final TargetPlatform platform = pickOne(random, _desktopPlatforms);
        final RunnerPresence presence = _buildPresenceOn(platform);
        final bool isShowingTray = random.nextBool();
        final bool isChangingLoginItem =
            platform == TargetPlatform.macOS && random.nextBool();

        if (isChangingLoginItem && isShowingTray) {
          await presence.loginItem.register();
          expectedMethods.add(_nativeRegisterMethod);
        } else if (isChangingLoginItem) {
          await presence.loginItem.unregister();
          expectedMethods.add(_nativeUnregisterMethod);
        } else if (isShowingTray) {
          await presence.trayPresence.stayInTray();
          expectedMethods.add(_nativeStayInTrayMethod);
        } else {
          await presence.trayPresence.leaveTray();
          expectedMethods.add(_nativeLeaveTrayMethod);
        }

        expect(receivedMethods, expectedMethods);
      }
    },
  );

  test(
    'test_build_platform_runner_presence_property_macos_keeps_saved_choice',
    () async {
      final Random random = seededRandom(48203);

      for (int i = 0; i < propertyIterations; i += 1) {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final List<String> receivedMethods = _listenAsNativeRunner();
        final RunnerPresence presence = _buildPresenceOn(TargetPlatform.macOS);
        final DeviceRole role = pickOne(random, DeviceRole.values);
        final bool hasChosen = random.nextBool();
        final bool isChosen = random.nextBool();
        if (hasChosen) {
          await presence.startAtLoginChoiceStore.saveIsStartAtLoginChosen(
            isChosen: isChosen,
          );
        }

        await presence.keepForRole(role);

        final List<String> expectedMethods = <String>[];
        if (roleRunsTasks(role)) {
          expectedMethods.add(_nativeStayInTrayMethod);
        }
        if (roleRunsTasks(role) && (!hasChosen || isChosen)) {
          expectedMethods.add(_nativeRegisterMethod);
        }
        expect(receivedMethods, expectedMethods);
      }
    },
  );
}
