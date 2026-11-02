import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/confirmation.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/unavailable_once_biometric_confirmation.dart';

void main() {
  testWidgets('the approve button names this device\'s confirmation', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = replaceRepositories(
      buildGalleryDependencies(),
      biometricConfirmation: const ApprovingBiometricConfirmation(
        methodName: 'fingerprint',
      ),
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingApprovalRoute(),
      dependencies: dependencies,
    );

    expect(find.text('Approve with fingerprint'), findsOneWidget);
    expect(find.text('Approve with Touch ID'), findsNothing);
  });

  testWidgets('approving works again after the lock was missing', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = replaceRepositories(
      buildGalleryDependencies(),
      biometricConfirmation: UnavailableOnceBiometricConfirmation(),
    );
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const PairingApprovalRoute(),
      dependencies: dependencies,
    );

    final List<Object> escapedProblems = <Object>[];
    await runZonedGuarded(
      () => tapVisible(tester, find.text('Approve with Touch ID')),
      (Object problem, StackTrace _) => escapedProblems.add(problem),
    );
    await pumpFrames(tester);
    expect(escapedProblems.single, isA<BiometricConfirmationUnavailable>());

    await tapVisible(tester, find.text('Approve with Touch ID'));
    await pumpFrames(tester);

    expect(dependencies.pairingRepository.findPendingRequest(), isNull);
    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
  });
}
