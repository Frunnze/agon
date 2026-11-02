import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

Future<void> openSettingsTab(WidgetTester tester, String tab) async {
  await tester.tap(find.text(tab));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_general_settings_property_remove_takes_device_out', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9901);
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: dependencies,
    );

    for (int i = 0; i < 3; i += 1) {
      final int buttonCount = tester.widgetList(find.text('Remove')).length;
      final int chosen = random.nextInt(buttonCount);
      await tapVisible(tester, find.text('Remove').at(chosen));
      await pumpFrames(tester);

      final int members = dependencies.deviceRepository
          .listDevices()
          .where(
            (Device device) =>
                device.workspaces.contains(GalleryWorkspaceIds.acme),
          )
          .length;
      expect(find.text('Remove'), findsNWidgets(buttonCount - 1));
      expect(members, buttonCount);
    }
  });

  testWidgets('a removed device can be added back to the workspace', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await dependencies.deviceRepository.removeDeviceFromWorkspace(
      GalleryDeviceIds.gpuBox,
      GalleryWorkspaceIds.acme,
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: dependencies,
    );
    expect(find.text('gpu-box'), findsNothing);

    await tester.tap(find.text('Add one of your devices'));
    await pumpFrames(tester);
    expect(find.text('Add a device to acme'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await pumpFrames(tester);

    expect(find.text('gpu-box'), findsOneWidget);
    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.gpuBox)
          .workspaces,
      contains(GalleryWorkspaceIds.acme),
    );
  });

  testWidgets('the devices link in settings opens your devices', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('Your devices').last);
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
  });

  testWidgets('runner detail matches the gallery and pauses runs', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: dependencies,
    );
    await openSettingsTab(tester, 'Runners');
    await tester.tap(find.text('mac-studio'));
    await pumpFrames(tester);

    expect(
      navigation.currentRoute,
      const RunnerDetailRoute(GalleryDeviceIds.macStudio),
    );
    for (final String text in <String>[
      'Online · 1 of 4 slots busy',
      'Pause new runs',
      'How runs work here',
      'Where agents run',
      'In Docker, a new container per run, deleted when the run ends',
      "Only the run's own workspace",
      'Secure Enclave',
      'Running now',
      'Ship release 2.4',
      'workflow release · build-ios · 4 min',
      'arm64',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(
      find.textContaining('api.anthropic.com through the hub'),
      findsOneWidget,
    );

    await tester.tap(find.text('Pause new runs'));
    await pumpFrames(tester);
    expect(find.text('Paused · 1 of 4 slots busy'), findsOneWidget);
    expect(
      dependencies.runnerRepository
          .findRunner(GalleryDeviceIds.macStudio)
          .acceptingNewRuns,
      isFalse,
    );

    await tester.tap(find.text('Resume new runs'));
    await pumpFrames(tester);
    expect(find.text('Online · 1 of 4 slots busy'), findsOneWidget);

    await tester.tap(find.text('Ship release 2.4'));
    await pumpFrames(tester);
    expect(find.byType(TaskRunScreen), findsOneWidget);
  });

  testWidgets('test_runner_detail_property_every_runner_renders', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final Runner runner in dependencies.runnerRepository.listRunners()) {
      await pumpApp(
        tester,
        size: phoneSize,
        route: RunnerDetailRoute(runner.deviceId),
        dependencies: dependencies,
      );

      final String name = dependencies.deviceRepository
          .findDevice(runner.deviceId)
          .name;
      expect(find.text(name), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Offline · last seen 3 days ago'), findsOneWidget);
    expect(find.text('Nothing is running here.'), findsOneWidget);
  });
}
