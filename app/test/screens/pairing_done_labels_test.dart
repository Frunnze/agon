import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

const String _labelsTerm = 'Labels';
const List<String> _possibleLabels = <String>['mac', 'arm64', 'xcode', 'gpu'];

void main() {
  testWidgets('test_pairing_done_property_labels_shown_only_when_known', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> labels = <String>[
        for (final String label in _possibleLabels)
          if (random.nextBool()) label,
      ];
      final PairingOutcome outcome = PairingOutcome(
        deviceName: 'project',
        role: pickOne(random, <DeviceRole>[
          DeviceRole.clientAndRunner,
          DeviceRole.runner,
        ]),
        workspaceNames: const <String>['personal'],
        runnerLabels: labels,
        approverName: random.nextBool() ? null : 'air-laptop',
      );
      await pumpApp(
        tester,
        size: desktopSize,
        route: PairingDoneRoute(outcome),
        dependencies: buildGalleryDependencies(),
      );

      final String reason = 'labels $labels';
      expect(
        find.text(_labelsTerm).evaluate().isNotEmpty,
        labels.isNotEmpty,
        reason: reason,
      );
      for (final String label in labels) {
        expect(find.text(label), findsWidgets, reason: reason);
      }
    }
  });
}
