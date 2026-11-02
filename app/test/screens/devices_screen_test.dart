import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/refusing_biometric_confirmation.dart';

const String _revokeWarning =
    'Its key stops working in every workspace at once. To come back, it has '
    'to be paired again.';
const String _revokeNote =
    "Revoking needs your passkey, so a stolen device can't remove your other "
    'devices.';

Future<void> openRevokeDialog(WidgetTester tester, int rowIndex) async {
  await tapVisible(tester, find.text('Revoke').at(rowIndex));
  await pumpFrames(tester);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('your devices match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.devices),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'Shared by all your workspaces. Pair once, revoke once.',
        'Add device',
        'This device · Secure Enclave',
        'TPM 2.0',
        'StrongBox',
        'acme, personal',
        'Client and runner',
        'Now',
        '1 min ago',
        '3 days ago',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Revoke'), findsNWidgets(6));
    });
  }

  testWidgets('revoking a device needs the dialog and the passkey', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.devices),
      dependencies: dependencies,
    );

    await openRevokeDialog(tester, 4);
    for (final String text in <String>[
      'Revoke old-macbook?',
      _revokeWarning,
      'Used in',
      '12 March 2026, approved by air-laptop',
      _revokeNote,
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }

    await tester.tap(find.text('Keep device'));
    await pumpFrames(tester);
    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.oldMacbook)
          .revoked,
      isFalse,
    );

    await openRevokeDialog(tester, 4);
    await tester.tap(find.text('Revoke with Touch ID'));
    await pumpFrames(tester);

    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.oldMacbook)
          .revoked,
      isTrue,
    );
    expect(find.text('old-macbook'), findsNothing);
    expect(find.text('Revoke'), findsNWidgets(5));
  });

  testWidgets('a refused passkey keeps the device', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = replaceRepositories(
      buildGalleryDependencies(),
      biometricConfirmation: const RefusingBiometricConfirmation(),
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.devices),
      dependencies: dependencies,
    );

    await openRevokeDialog(tester, 0);
    await tester.tap(find.text('Revoke with Touch ID'));
    await pumpFrames(tester);

    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.macStudio)
          .revoked,
      isFalse,
    );
  });

  testWidgets('add device leads to the code and then the approval', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.devices),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('Add device'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const PairingCodeRoute());

    await tapVisible(tester, find.text('Check mac-mini'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const PairingApprovalRoute());
  });

  testWidgets('add device shows a fresh code when none is active', (
    WidgetTester tester,
  ) async {
    final AppDependencies base = buildGalleryDependencies();
    final AppDependencies dependencies = replaceRepositories(
      base,
      pairingRepository: FakePairingRepository(
        session: null,
        request: null,
        clock: FixedClock(galleryNow),
        deviceRepository: base.deviceRepository as FakeDeviceRepository,
        joinOutcome: galleryPairingOutcome,
      ),
    );
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.devices),
      dependencies: dependencies,
    );

    await tester.tap(find.text('Add device'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const PairingCodeRoute());
    expect(find.text('This code expired.'), findsNothing);
    expect(find.text('9QX-3MD'), findsOneWidget);
  });

  testWidgets('cancel withdraws the code and returns to your devices', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.devices),
      dependencies: dependencies,
    );
    await tester.tap(find.text('Add device'));
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    expect(dependencies.pairingRepository.findActiveSession(), isNull);
    await tester.tap(find.text('Add device'));
    await pumpFrames(tester);
    expect(find.text('9QX-3MD'), findsOneWidget);
  });

  testWidgets('cancel on an expired code only closes the page', (
    WidgetTester tester,
  ) async {
    final AppDependencies base = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.devices),
      dependencies: replaceRepositories(
        base,
        pairingRepository: FakePairingRepository(
          session: null,
          request: null,
          clock: FixedClock(galleryNow),
          deviceRepository: base.deviceRepository as FakeDeviceRepository,
          joinOutcome: galleryPairingOutcome,
        ),
      ),
    );
    navigation.openRoute(const PairingCodeRoute());
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    expect(tester.takeException(), isNull);
  });
}
