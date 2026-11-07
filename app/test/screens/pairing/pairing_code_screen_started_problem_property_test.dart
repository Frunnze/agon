import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _freshFakeCode = '9QX-3MD';
const String _showNewCodeLabel = 'Show a new code';
const List<String> _visibleProblems = <String>[
  'no peer endpoint',
  'Ünïcødé relay',
  '中继服务器不可达',
  '<b>relay</b> & "quotes"',
];

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  if (random.nextBool()) {
    return pickOne(random, _visibleProblems);
  }
  return 'relay ${randomText(random)}';
}

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

AppDependencies _buildDependencies(String? startedPairingRendezvousProblem) {
  final AppDependencies base = buildGalleryDependencies();
  return replaceRepositories(
    base,
    pairingRepository: FakePairingRepository(
      session: null,
      request: null,
      clock: FixedClock(galleryNow),
      deviceRepository: base.deviceRepository as FakeDeviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: startedPairingRendezvousProblem,
    ),
  );
}

void main() {
  testWidgets('test_pairing_code_screen_build_property_'
      'shows_the_problem_reported_by_a_started_pairing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74911);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? problem = _randomProblem(random);
      final Size size = _randomWindowSize(random);
      await pumpApp(
        tester,
        size: size,
        route: const PairingCodeRoute(),
        dependencies: _buildDependencies(problem),
      );

      await tapVisible(tester, find.text(_showNewCodeLabel));
      await pumpFrames(tester);

      final int expectedBanners = problem == null ? 0 : 1;
      expect(find.text(_freshFakeCode), findsOneWidget, reason: 'size $size');
      expect(
        find.byType(RendezvousProblemBanner),
        findsNWidgets(expectedBanners),
        reason: 'size $size',
      );
      if (problem != null) {
        expect(find.text(problem), findsOneWidget, reason: 'size $size');
        expect(find.text(rendezvousProblemTitle), findsOneWidget);
      }
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });
}
