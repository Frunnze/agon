import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/screens/setup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/recording_pairing_repository.dart';

const String _portProblem =
    'the app server cannot listen on port 8731: Address already in use';
const Set<TargetPlatform> _computers = <TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.linux,
  TargetPlatform.windows,
};

final TargetPlatformVariant _onMac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);
const TargetPlatformVariant _onPhones = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.iOS,
  TargetPlatform.android,
});

Future<AppNavigation> _pumpCodeEntry(
  WidgetTester tester, {
  required DeviceRole role,
  required RecordingPairingRepository pairing,
}) {
  return pumpApp(
    tester,
    size: desktopSize,
    route: PairingCodeEntryRoute(role),
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      pairingRepository: pairing,
    ),
  );
}

void main() {
  test('test_list_setup_roles_property_phones_only_get_client_only', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final List<DeviceRole> roles = listSetupRoles(platform);

      if (_computers.contains(platform)) {
        expect(roles, <DeviceRole>[
          DeviceRole.clientAndRunner,
          DeviceRole.client,
          DeviceRole.runner,
        ]);
      } else {
        expect(roles, <DeviceRole>[DeviceRole.client]);
      }
    }
  });

  test('test_can_host_app_server_property_computers_that_are_clients', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      for (final DeviceRole role in DeviceRole.values) {
        final bool isClientComputer =
            _computers.contains(platform) && role != DeviceRole.runner;

        expect(
          canHostAppServer(platform: platform, role: role),
          isClientComputer,
          reason: '$platform $role',
        );
      }
    }
  });

  testWidgets('test_pairing_code_entry_property_server_link_follows_role', (
    WidgetTester tester,
  ) async {
    for (final DeviceRole role in DeviceRole.values) {
      await _pumpCodeEntry(
        tester,
        role: role,
        pairing: RecordingPairingRepository(hostingProblem: null),
      );

      final bool offersHosting = role != DeviceRole.runner;
      expect(
        find.text(makeThisComputerTheServerLabel).evaluate().isNotEmpty,
        offersHosting,
        reason: '$role',
      );
      expect(
        find.text(noOtherDevicesText).evaluate().isNotEmpty,
        offersHosting,
      );
      expect(find.text('App server address'), findsNothing);
    }
  }, variant: _onMac);

  testWidgets('test_pairing_code_entry_property_server_choice_is_a_button', (
    WidgetTester tester,
  ) async {
    for (final DeviceRole role in DeviceRole.values) {
      await _pumpCodeEntry(
        tester,
        role: role,
        pairing: RecordingPairingRepository(hostingProblem: null),
      );

      final Finder serverButton = find.widgetWithText(
        AppButton,
        makeThisComputerTheServerLabel,
      );
      final int expectedButtons = role == DeviceRole.runner ? 0 : 1;
      expect(serverButton, findsNWidgets(expectedButtons), reason: '$role');
      expect(find.byType(InlineLink), findsNothing, reason: '$role');
    }
  }, variant: _onMac);

  testWidgets('test_host_app_server_property_registers_the_first_workspace', (
    WidgetTester tester,
  ) async {
    for (final DeviceRole role in <DeviceRole>[
      DeviceRole.clientAndRunner,
      DeviceRole.client,
    ]) {
      final RecordingPairingRepository pairing = RecordingPairingRepository(
        hostingProblem: null,
      );
      final AppNavigation navigation = await _pumpCodeEntry(
        tester,
        role: role,
        pairing: pairing,
      );

      await tapVisible(tester, find.text(makeThisComputerTheServerLabel));
      await pumpFrames(tester);

      final AppRoute done = navigation.currentRoute;
      expect(done, isA<PairingDoneRoute>());
      expect((done as PairingDoneRoute).outcome.workspaceNames, <String>[
        firstWorkspaceName,
      ]);
      expect(pairing.hostedAccountRequests, <HostedAccountRequest>[
        (
          workspaceName: firstWorkspaceName,
          deviceName: suggestDeviceName(Platform.localHostname),
          role: role,
        ),
      ]);
      expect(pairing.joinServerAddresses, isEmpty);
      expect(find.text('Account created'), findsOneWidget);
      expect(firstWorkspaceName, 'personal');
    }
  }, variant: _onMac);

  testWidgets('a failed hosting is explained and the code entry stays', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _pumpCodeEntry(
      tester,
      role: DeviceRole.client,
      pairing: RecordingPairingRepository(hostingProblem: _portProblem),
    );

    await tapVisible(tester, find.text(makeThisComputerTheServerLabel));
    await pumpFrames(tester);

    expect(find.text(_portProblem), findsOneWidget);
    expect(
      navigation.currentRoute,
      const PairingCodeEntryRoute(DeviceRole.client),
    );
  }, variant: _onMac);

  testWidgets('test_join_with_code_property_typed_code_sends_no_address', (
    WidgetTester tester,
  ) async {
    final RecordingPairingRepository pairing = RecordingPairingRepository(
      hostingProblem: null,
    );
    final AppNavigation navigation = await _pumpCodeEntry(
      tester,
      role: DeviceRole.runner,
      pairing: pairing,
    );

    await enterFieldText(tester, label: 'Pairing code', text: '4F7-K2Q');
    await tapVisible(tester, find.text('Pair this Mac'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, isA<PairingDoneRoute>());
    expect(pairing.joinServerAddresses, <String?>[null]);
  }, variant: _onMac);

  testWidgets('phones offer only the client role and never the server', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SetupRoleRoute(),
      dependencies: buildGalleryDependencies(),
    );

    expect(find.text('Client only'), findsOneWidget);
    expect(find.text('Client and runner'), findsNothing);
    expect(find.text('Runner only'), findsNothing);

    await tapVisible(tester, find.text('Continue'));
    await pumpFrames(tester);

    expect(
      navigation.currentRoute,
      const PairingCodeEntryRoute(DeviceRole.client),
    );
    expect(find.text('Enter the pairing code'), findsOneWidget);
    expect(find.text(makeThisComputerTheServerLabel), findsNothing);
  }, variant: _onPhones);
}
