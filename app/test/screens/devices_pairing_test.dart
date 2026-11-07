import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';

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
  testWidgets('pair a device leads to the code and then the approval', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: phoneSize,
      dependencies: buildGalleryDependencies(),
    );

    await tapVisible(tester, find.text('Pair a device'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const PairingCodeRoute());

    await tapVisible(tester, find.text('Check mac-mini'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const PairingApprovalRoute());
  });

  testWidgets('pair a device shows a fresh code when none is active', (
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
        startedPairingRendezvousProblem: null,
      ),
    );
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: phoneSize,
      dependencies: dependencies,
    );

    await tapVisible(tester, find.text('Pair a device'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const PairingCodeRoute());
    expect(find.text('This code expired.'), findsNothing);
    expect(find.text('9QX-3MD'), findsOneWidget);
  });

  testWidgets('cancel withdraws the code and returns to devices', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: phoneSize,
      dependencies: dependencies,
    );
    await tapVisible(tester, find.text('Pair a device'));
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    expect(dependencies.pairingRepository.findActiveSession(), isNull);
    await tapVisible(tester, find.text('Pair a device'));
    await pumpFrames(tester);
    expect(find.text('9QX-3MD'), findsOneWidget);
  });

  testWidgets('cancel on an expired code only closes the page', (
    WidgetTester tester,
  ) async {
    final AppDependencies base = buildGalleryDependencies();
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: phoneSize,
      dependencies: replaceRepositories(
        base,
        pairingRepository: FakePairingRepository(
          session: null,
          request: null,
          clock: FixedClock(galleryNow),
          deviceRepository: base.deviceRepository as FakeDeviceRepository,
          joinOutcome: galleryPairingOutcome,
          startedPairingRendezvousProblem: null,
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
