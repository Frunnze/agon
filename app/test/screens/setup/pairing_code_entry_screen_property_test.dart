import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_qr_code_scanner.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_pairing_repository.dart';
import '../../support/widget_harness.dart';

const String _codeLabel = 'Pairing code';
const String _scanLabel = 'Scan QR code';
const String _pairLabelStart = 'Pair this';
const String _scannedCode = '4F7-K2Q';
const String _typedCode = '9QX 3MD';
const String _brokenServerProblem =
    'This pairing code has a broken server address';
const List<String> _brokenServerAddresses = <String>[
  'relay.acme.dev',
  'ftp://relay.acme.dev',
  'https://',
  ' ',
  '',
];
const List<String> _usableServerAddresses = <String>[
  'https://relay.acme.dev',
  'http://192.168.1.20:7000',
  'peer://k7f2q9xz3m',
];
const TargetPlatformVariant _onPhones = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.iOS,
  TargetPlatform.android,
});

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

PairingRepository _keepGalleryPairing(AppDependencies base) {
  return base.pairingRepository;
}

Future<AppNavigation> _pumpScanningScreen(
  WidgetTester tester, {
  required Size size,
  required String serverAddress,
  required PairingRepository Function(AppDependencies base) pairing,
}) {
  final AppDependencies base = buildGalleryDependencies();
  final String scannedText = encodePairingInvitation(
    PairingInvitation(code: _scannedCode, serverAddress: serverAddress),
  );
  final AppDependencies dependencies = replaceRepositories(
    base,
    qrCodeScanner: FixedQrCodeScanner(scannedText),
    pairingRepository: pairing(base),
  );

  return pumpApp(
    tester,
    size: size,
    route: const PairingCodeEntryRoute(DeviceRole.runner),
    dependencies: dependencies,
  );
}

Future<void> _scanThenPump(WidgetTester tester) async {
  await tapVisible(tester, find.text(_scanLabel));
  await pumpFrames(tester);
}

Future<void> _pairThenPump(WidgetTester tester) async {
  await tapVisible(tester, find.textContaining(_pairLabelStart));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_scan_property_a_broken_server_address_is_explained', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      await _pumpScanningScreen(
        tester,
        size: size,
        serverAddress: pickOne(random, _brokenServerAddresses),
        pairing: _keepGalleryPairing,
      );

      await _scanThenPump(tester);

      expect(tester.takeException(), isNull, reason: '$size');
      expect(findFieldText(_codeLabel, _brokenServerProblem), findsOneWidget);
      expect(findFieldText(_codeLabel, _scannedCode), findsNothing);
    }
  }, variant: _onPhones);

  testWidgets('test_join_property_pairing_after_a_broken_scan_still_works', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      final AppNavigation navigation = await _pumpScanningScreen(
        tester,
        size: size,
        serverAddress: pickOne(random, _brokenServerAddresses),
        pairing: _keepGalleryPairing,
      );
      await _scanThenPump(tester);
      await enterFieldText(tester, label: _codeLabel, text: _typedCode);

      await _pairThenPump(tester);

      expect(tester.takeException(), isNull, reason: '$size');
      expect(navigation.currentRoute, isA<PairingDoneRoute>());
    }
  }, variant: _onPhones);

  testWidgets('test_scan_property_a_usable_server_address_is_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      final String serverAddress = pickOne(random, _usableServerAddresses);
      final RecordingPairingRepository recording = RecordingPairingRepository(
        hostingProblem: null,
      );
      await _pumpScanningScreen(
        tester,
        size: size,
        serverAddress: serverAddress,
        pairing: (AppDependencies base) => recording,
      );
      await _scanThenPump(tester);

      await _pairThenPump(tester);

      expect(tester.takeException(), isNull, reason: '$size');
      expect(recording.joinServerAddresses, <String?>[serverAddress]);
    }
  }, variant: _onPhones);
}
