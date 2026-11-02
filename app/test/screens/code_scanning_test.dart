import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';
import 'package:agent_orchestration/scanning/qr_scanner_page.dart';
import 'package:agent_orchestration/screens/setup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/fixed_qr_code_scanner.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/recording_pairing_repository.dart';

const PairingInvitation _galleryInvitation = PairingInvitation(
  code: '4F7-K2Q',
  serverAddress: 'https://relay.acme.dev',
);

const TargetPlatformVariant _onPhones = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.iOS,
  TargetPlatform.android,
});

Future<AppNavigation> pumpJoinWithScanner(
  WidgetTester tester,
  FixedQrCodeScanner scanner, {
  required PairingRepository pairingRepository,
}) {
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    qrCodeScanner: scanner,
    pairingRepository: pairingRepository,
  );

  return pumpApp(
    tester,
    size: phoneSize,
    route: const PairingCodeEntryRoute(DeviceRole.runner),
    dependencies: dependencies,
  );
}

void main() {
  test('test_can_scan_qr_codes_property_only_phones_scan', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final bool isPhone =
          platform == TargetPlatform.iOS || platform == TargetPlatform.android;

      expect(canScanQrCodes(platform), isPhone);
    }
  });

  test('test_find_first_scanned_text_property_first_non_empty_value', () {
    final Random random = seededRandom(9961);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String?> values = <String?>[
        for (int index = 0; index < random.nextInt(4); index += 1)
          pickOne<String?>(random, <String?>[null, '', randomText(random)]),
      ];
      final BarcodeCapture capture = BarcodeCapture(
        barcodes: <Barcode>[
          for (final String? value in values) Barcode(rawValue: value),
        ],
      );
      String? expected;
      for (final String? value in values) {
        if (expected == null && value != null && value.isNotEmpty) {
          expected = value;
        }
      }

      expect(findFirstScannedText(capture), expected);
    }
  });

  testWidgets('scanning fills the code and the server', (
    WidgetTester tester,
  ) async {
    final FixedQrCodeScanner scanner = FixedQrCodeScanner(
      encodePairingInvitation(_galleryInvitation),
    );
    final RecordingPairingRepository pairing = RecordingPairingRepository(
      hostingProblem: null,
    );
    final AppNavigation navigation = await pumpJoinWithScanner(
      tester,
      scanner,
      pairingRepository: pairing,
    );

    await tapVisible(tester, find.text('Scan QR code'));
    await pumpFrames(tester);

    expect(scanner.scanCount, 1);
    expect(findFieldText('Pairing code', '4F7-K2Q'), findsOneWidget);
    expect(find.text('App server address'), findsNothing);

    await tapVisible(tester, find.textContaining('Pair this'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, isA<PairingDoneRoute>());
    expect(pairing.joinServerAddresses, <String?>[
      _galleryInvitation.serverAddress,
    ]);
  }, variant: _onPhones);

  testWidgets('a QR code that is not a pairing code is explained', (
    WidgetTester tester,
  ) async {
    await pumpJoinWithScanner(
      tester,
      FixedQrCodeScanner('https://example.com/menu'),
      pairingRepository: RecordingPairingRepository(hostingProblem: null),
    );

    await tapVisible(tester, find.text('Scan QR code'));
    await pumpFrames(tester);

    expect(
      findFieldText('Pairing code', 'This is not a pairing code'),
      findsOneWidget,
    );
  }, variant: _onPhones);

  testWidgets('test_scan_property_cancelled_scan_keeps_typed_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9962);

    for (int i = 0; i < 3; i += 1) {
      final String typed = randomWordPhrase(random);
      await pumpJoinWithScanner(
        tester,
        FixedQrCodeScanner(null),
        pairingRepository: RecordingPairingRepository(hostingProblem: null),
      );
      await enterFieldText(tester, label: 'Pairing code', text: typed);

      await tapVisible(tester, find.text('Scan QR code'));
      await pumpFrames(tester);

      final EditableText field = tester.widget(
        find.descendant(
          of: findFieldInput('Pairing code'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, typed);
    }
  }, variant: _onPhones);
}
