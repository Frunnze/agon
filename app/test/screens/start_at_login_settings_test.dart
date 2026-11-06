import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/memory_start_at_login_choice_store.dart';
import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';

const String _startAtLoginHint =
    'Opens when you log in so this computer can run tasks.';
const int _largestSwitchCount = 4;

Finder _findStartAtLoginToggle() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is SwitchToggle && widget.semanticLabel == startAtLoginLabel,
  );
}

SwitchToggle _readToggle(WidgetTester tester) {
  return tester.widget<SwitchToggle>(_findStartAtLoginToggle());
}

Device _findRunnerDevice() {
  for (final Device device in galleryDevices) {
    if (roleRunsTasks(device.role)) {
      return device;
    }
  }
  throw StateError('the gallery has no runner device');
}

Future<void> _openSettings(
  WidgetTester tester, {
  required DeviceId currentDeviceId,
  required RunnerPresence? runnerPresence,
}) async {
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: currentDeviceId,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    runnerPresence: runnerPresence,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.settings),
    dependencies: dependencies,
  );
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_property_start_at_login_only_on_runner_computers', (
    WidgetTester tester,
  ) async {
    for (final Device device in galleryDevices) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: true,
      );
      await _openSettings(
        tester,
        currentDeviceId: device.id,
        runnerPresence: recorded.presence,
      );

      final Matcher expected = roleRunsTasks(device.role)
          ? findsOneWidget
          : findsNothing;
      expect(_findStartAtLoginToggle(), expected, reason: device.name);
      expect(find.text(_startAtLoginHint), expected, reason: device.name);
    }
  });

  testWidgets('test_build_property_start_at_login_hidden_without_presence', (
    WidgetTester tester,
  ) async {
    await _openSettings(
      tester,
      currentDeviceId: _findRunnerDevice().id,
      runnerPresence: null,
    );

    expect(_findStartAtLoginToggle(), findsNothing);
  });

  testWidgets('test_build_property_switch_shows_the_saved_choice', (
    WidgetTester tester,
  ) async {
    for (final bool isStartAtLoginChosen in <bool>[true, false]) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: isStartAtLoginChosen,
      );
      await _openSettings(
        tester,
        currentDeviceId: _findRunnerDevice().id,
        runnerPresence: recorded.presence,
      );

      expect(_readToggle(tester).value, isStartAtLoginChosen);
    }
  });

  testWidgets('test_change_start_at_login_property_switch_follows_each_tap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(12201);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isChosenAtFirst = random.nextBool();
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: isChosenAtFirst,
      );
      await _openSettings(
        tester,
        currentDeviceId: _findRunnerDevice().id,
        runnerPresence: recorded.presence,
      );
      final int switchCount = 1 + random.nextInt(_largestSwitchCount);
      bool isExpectedOn = isChosenAtFirst;

      for (int tap = 0; tap < switchCount; tap += 1) {
        await tapVisible(tester, _findStartAtLoginToggle());
        await pumpFrames(tester);
        isExpectedOn = !isExpectedOn;

        expect(_readToggle(tester).value, isExpectedOn);
        expect(recorded.choiceStore.isStartAtLoginChosen, isExpectedOn);
        expect(recorded.loginItem.isRegistered, isExpectedOn);
      }
    }
  });

  testWidgets('test_change_start_at_login_property_refusal_keeps_the_switch', (
    WidgetTester tester,
  ) async {
    for (final bool isStartAtLoginChosen in <bool>[true, false]) {
      final MemoryStartAtLoginChoiceStore store =
          MemoryStartAtLoginChoiceStore(
            isStartAtLoginChosen: isStartAtLoginChosen,
          );
      await _openSettings(
        tester,
        currentDeviceId: _findRunnerDevice().id,
        runnerPresence: RunnerPresence(
          loginItem: RefusingLoginItem(),
          trayPresence: RecordingTrayPresence(),
          startAtLoginChoiceStore: store,
        ),
      );

      await tapVisible(tester, _findStartAtLoginToggle());
      await pumpFrames(tester);

      expect(_readToggle(tester).value, isStartAtLoginChosen);
      expect(_readToggle(tester).onChanged, isNotNull);
      expect(store.isStartAtLoginChosen, isStartAtLoginChosen);
      expect(find.text(refusedLoginItemMessage), findsOneWidget);
    }
  });
}
