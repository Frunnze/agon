import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/server_group_repositories.dart';
import '../support/workspace_device_finders.dart';

const String _serverDownNotice =
    'Runners on this network still work. Runs for gpu-box wait until the '
    'server is back.';

Finder _findAcmeDevice(String deviceName) {
  return findWorkspaceDevice(workspaceName: 'acme', deviceName: deviceName);
}

Future<AppNavigation> _pumpDevices(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) {
  return pumpApp(
    tester,
    size: size,
    route: const SectionRoute(AppSection.devices),
    dependencies: dependencies,
  );
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('devices show runner info at ${size.width}', (
      WidgetTester tester,
    ) async {
      await _pumpDevices(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.title, 'Devices');
      expect(
        header.summary.single.text,
        'Runners: 3 of 4 online · 5 free slots',
      );
      for (final String text in <String>[
        'Computer · In Docker',
        'Computer · On its own computer',
        '1 of 4 busy',
        '1 of 2 busy',
        '0 of 1 busy',
        'None free',
        'Offline',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.byType(SlotsIndicator), findsNWidgets(3));
      final Matcher columnHeads = size == desktopSize
          ? findsOneWidget
          : findsNothing;
      expect(find.text('Slots'), columnHeads);
    });
  }

  testWidgets('the server-down devices page matches the gallery', (
    WidgetTester tester,
  ) async {
    await _pumpDevices(
      tester,
      size: desktopSize,
      dependencies: buildDependenciesWithServerDown(),
    );

    for (final String text in <String>[
      'Runners: 2 of 4 reachable',
      "Can't reach the app server",
      _serverDownNotice,
      'Last connected 14:12 · trying every 10 seconds',
      'Unknown',
      'Unreachable',
      "Has a copy · Not syncing: can't reach the app server",
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }

    await tapVisible(tester, find.text('Try now'));
    await pumpFrames(tester);

    expect(find.text("Can't reach the app server"), findsNothing);
    expect(find.text('Runners: 3 of 4 online · 5 free slots'), findsOneWidget);
  });

  testWidgets('a runner row opens its runner and pauses runs', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: desktopSize,
      dependencies: dependencies,
    );
    await tapVisible(tester, _findAcmeDevice('mac-studio'));
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
      'In Docker',
      'Network in Docker',
      'Secure Enclave',
      'Running now',
      'Ship release 2.4',
      'workflow release · build-ios · 4 min',
      'arm64',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }

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

  testWidgets('the runner back link returns to devices', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: desktopSize,
      dependencies: buildGalleryDependencies(),
    );
    await tapVisible(tester, _findAcmeDevice('gpu-box'));
    await pumpFrames(tester);

    final BackLinkButton backLink = tester.widget<BackLinkButton>(
      find.byType(BackLinkButton),
    );
    expect(backLink.link.label, 'Devices');
    await tester.tap(find.byType(BackLinkButton));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
  });

  testWidgets('rows of devices that run nothing open nothing', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: desktopSize,
      dependencies: buildGalleryDependencies(),
    );

    await tapVisible(tester, _findAcmeDevice('pixel-phone'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
  });

  testWidgets('test_devices_screen_property_runner_rows_open_their_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(12301);
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<Runner> runners = dependencies.runnerRepository.listRunners();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Runner runner = pickOne(random, runners);
      final AppNavigation navigation = await _pumpDevices(
        tester,
        size: pickOne(random, <Size>[phoneSize, desktopSize]),
        dependencies: dependencies,
      );
      final String name = dependencies.deviceRepository
          .findDevice(runner.deviceId)
          .name;
      await tapVisible(tester, _findAcmeDevice(name));
      await pumpFrames(tester);

      expect(navigation.currentRoute, RunnerDetailRoute(runner.deviceId));
    }
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
