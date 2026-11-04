import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/screens/setup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const String _roleNote =
    "The role is part of this Mac's pairing. Later, only a device you "
    'already trust can change it.';

final TargetPlatformVariant _onMac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

const Map<DeviceRole, String> _roleChoiceTitles = <DeviceRole, String>{
  DeviceRole.clientAndRunner: 'Client and runner',
  DeviceRole.client: 'Client only',
  DeviceRole.runner: 'Runner only',
};

Future<void> fillJoinForm(WidgetTester tester, {required String code}) async {
  await enterFieldText(tester, label: 'Pairing code', text: code);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('choosing a role matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SetupRoleRoute(),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'Step 1 of 2',
        'How will this Mac be used?',
        'Client and runner',
        'Use the app here and run tasks on this Mac too.',
        'Client only',
        'Start workflows, chat with agents and approve what they do.',
        'Runner only',
        'Run tasks for your other devices, each in its own sandbox.',
        _roleNote,
        'Continue',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Start a new account'), findsNothing);
    }, variant: _onMac);

    testWidgets('entering the code matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const PairingCodeEntryRoute(DeviceRole.runner),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'Step 2 of 2',
        'Enter the pairing code',
        'Pairing code',
        'Dashes and spaces are optional.',
        'Pair this Mac',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('App server address'), findsNothing);
      expect(find.text('Scan QR code'), findsNothing);
      expect(find.text(makeThisComputerTheServerLabel), findsNothing);
    }, variant: _onMac);
  }

  testWidgets('test_setup_flow_property_chosen_role_reaches_pairing_done', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9951);

    for (int i = 0; i < DeviceRole.values.length; i += 1) {
      final DeviceRole role = pickOne(random, DeviceRole.values);
      final AppNavigation navigation = await pumpApp(
        tester,
        size: phoneSize,
        route: const SetupRoleRoute(),
        dependencies: buildGalleryDependencies(),
      );

      await tapVisible(tester, find.text(_roleChoiceTitles[role]!));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Continue'));
      await pumpFrames(tester);
      expect(navigation.currentRoute, PairingCodeEntryRoute(role));

      await fillJoinForm(tester, code: '4f7 k2q');
      await tapVisible(tester, find.text('Pair this Mac'));
      await pumpFrames(tester);

      final AppRoute done = navigation.currentRoute;
      expect(done, isA<PairingDoneRoute>());
      expect((done as PairingDoneRoute).outcome.role, role);
      expect(navigation.routes.length, 2);
    }
  }, variant: _onMac);

  testWidgets('test_join_form_property_only_valid_input_is_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9952);
    const List<String> codes = <String>['4F7-K2Q', '4F7-K2', '', '4f7k2q'];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String code = pickOne(random, codes);
      final bool isValid = code.replaceAll('-', '').length == 6;
      final AppNavigation navigation = await pumpApp(
        tester,
        size: desktopSize,
        route: const PairingCodeEntryRoute(DeviceRole.client),
        dependencies: buildGalleryDependencies(),
      );

      await fillJoinForm(tester, code: code);
      await tapVisible(tester, find.text('Pair this Mac'));
      await pumpFrames(tester);

      expect(navigation.currentRoute is PairingDoneRoute, isValid);
    }
  }, variant: _onMac);

  testWidgets('a bad pairing code is explained next to the field', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingCodeEntryRoute(DeviceRole.client),
      dependencies: buildGalleryDependencies(),
    );

    await fillJoinForm(tester, code: '4F7-K2');
    await tapVisible(tester, find.text('Pair this Mac'));
    await pumpFrames(tester);

    expect(
      findFieldText('Pairing code', 'A pairing code has six characters'),
      findsOneWidget,
    );
    expect(
      navigation.currentRoute,
      const PairingCodeEntryRoute(DeviceRole.client),
    );
  }, variant: _onMac);

  test(
    'test_choose_route_after_pairing_property_runners_if_it_runs_tasks',
    () {
      for (final DeviceRole role in DeviceRole.values) {
        final AppRoute route = chooseRouteAfterPairing(role);
        final bool runsTasks = role != DeviceRole.client;

        expect(route == const SectionRoute(AppSection.devices), runsTasks);
        expect(route == const SectionRoute(AppSection.tasks), !runsTasks);
      }
    },
  );

  testWidgets('test_pairing_done_property_done_opens_what_the_role_needs', (
    WidgetTester tester,
  ) async {
    for (final DeviceRole role in DeviceRole.values) {
      final AppNavigation navigation = await pumpApp(
        tester,
        size: desktopSize,
        route: PairingCodeEntryRoute(role),
        dependencies: buildGalleryDependencies(),
      );

      await fillJoinForm(tester, code: '4F7-K2Q');
      await tapVisible(tester, find.text('Pair this Mac'));
      await pumpFrames(tester);
      expect(find.text('Paired'), findsOneWidget);
      await tapVisible(tester, find.text('Done'));
      await pumpFrames(tester);

      expect(navigation.currentRoute, chooseRouteAfterPairing(role));
      expect(navigation.routes.length, 1);
      expect(
        find.byType(DevicesScreen).evaluate().isNotEmpty,
        role != DeviceRole.client,
      );
      expect(find.text('Approvals'), findsWidgets);
    }
  }, variant: _onMac);
}
