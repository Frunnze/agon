import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';

const String _wordsInstruction =
    'mac-mini shows four words. Approve only if they match these, in this '
    'order.';

AppDependencies buildDependenciesWithPairing({
  required PairingSession? session,
  required PairingRequest? request,
}) {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    pairingRepository: FakePairingRepository(
      session: session,
      request: request,
      clock: FixedClock(galleryNow),
      deviceRepository: base.deviceRepository as FakeDeviceRepository,
      joinOutcome: galleryPairingOutcome,
    ),
  );
}

PairingOutcome describeClientOutcome() {
  return PairingOutcome(
    deviceName: galleryPairingOutcome.deviceName,
    role: DeviceRole.client,
    workspaceNames: galleryPairingOutcome.workspaceNames,
    runnerLabels: galleryPairingOutcome.runnerLabels,
    approverName: galleryPairingOutcome.approverName,
  );
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('the pairing code page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const PairingCodeRoute(),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'Add a device',
        'Pair it once, then use it in any of your workspaces.',
        '4F7-K2Q',
        'Expires in 4:52',
        'On the new device',
        'Open the app and choose how the device will be used.',
        'Come back here, check four words match, then approve.',
        'Enter this code, or scan the QR code with a phone.',
        'App server peer link 4f7a2c19',
        'Check mac-mini',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets('the approval page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const PairingApprovalRoute(),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'Approve mac-mini?',
        'It wants to join as a runner.',
        'Same network · encrypted',
        '1. Check the words',
        _wordsInstruction,
        'maple',
        'lamp',
        '2. Check the request',
        'Runner',
        'Secure Enclave',
        '3. Choose where it works',
        'acme',
        'Reject',
        'Approve with Touch ID',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.textContaining('4F7-K2Q'), findsOneWidget);
    });
  }

  testWidgets('test_pairing_code_screen_property_qr_holds_code_and_server', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingCodeRoute(),
      dependencies: dependencies,
    );

    for (int i = 0; i < 3; i += 1) {
      final PairingQrCode qrCode = tester.widget(find.byType(PairingQrCode));
      final PairingSession session = dependencies.pairingRepository
          .findActiveSession()!;

      expect(qrCode.invitation.code, session.code);
      expect(
        qrCode.invitation.serverAddress,
        dependencies.workspaceRepository.currentWorkspace().appServerAddress,
      );
      expect(find.bySemanticsLabel('QR code for ${session.code}'), findsOne);

      await dependencies.pairingRepository.startPairing();
      await pumpFrames(tester);
    }
  });

  testWidgets('approving pairs the device into the chosen workspaces', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingApprovalRoute(),
      dependencies: dependencies,
    );

    await tapVisible(tester, find.bySemanticsLabel('Remove acme'));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Approve with Touch ID'));
    await pumpFrames(tester);
    expect(find.text('Choose at least one workspace'), findsOneWidget);
    expect(dependencies.pairingRepository.findPendingRequest(), isNotNull);

    await addFieldTag(tester, label: 'Workspaces', tag: 'personal');
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Approve with Touch ID'));
    await pumpFrames(tester);

    expect(dependencies.pairingRepository.findPendingRequest(), isNull);
    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    expect(find.text('mac-mini'), findsOneWidget);
    expect(find.text('personal'), findsWidgets);
  });

  testWidgets('rejecting ends the pairing', (WidgetTester tester) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingApprovalRoute(),
      dependencies: dependencies,
    );

    await tapVisible(tester, find.text('Reject'));
    await pumpFrames(tester);

    expect(dependencies.pairingRepository.findPendingRequest(), isNull);
    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
  });

  testWidgets('an expired code can be replaced', (WidgetTester tester) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingCodeRoute(),
      dependencies: buildDependenciesWithPairing(session: null, request: null),
    );
    expect(find.text('This code expired.'), findsOneWidget);
    expect(find.text('Waiting for the new device'), findsOneWidget);

    await tester.tap(find.text('Show a new code'));
    await pumpFrames(tester);

    expect(find.text('9QX-3MD'), findsOneWidget);
    expect(find.text('Expires in 5:00'), findsOneWidget);
  });

  testWidgets('the approval page explains when no device waits', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: phoneSize,
      route: const PairingApprovalRoute(),
      dependencies: buildDependenciesWithPairing(
        session: galleryPairingSession,
        request: null,
      ),
    );

    expect(find.text('No device is waiting'), findsOneWidget);
  });

  testWidgets('setup routes hide the navigation', (WidgetTester tester) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SetupRoleRoute(),
      dependencies: buildGalleryDependencies(),
    );

    expect(find.text('How will this Mac be used?'), findsOneWidget);
    expect(find.text('Approvals'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('pairing done shows what the new device became', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: phoneSize,
      route: PairingDoneRoute(galleryPairingOutcome),
      dependencies: buildGalleryDependencies(),
    );

    for (final String text in <String>[
      'Paired',
      'This Mac is now a runner',
      'Used in',
      'acme',
      'mac-mini',
      'arm64',
      'air-laptop',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }

    final PairingOutcome clientOutcome = describeClientOutcome();
    await pumpApp(
      tester,
      size: phoneSize,
      route: PairingDoneRoute(clientOutcome),
      dependencies: buildGalleryDependencies(),
    );
    expect(find.text('This Mac is now a client'), findsOneWidget);
    expect(find.text('arm64'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
