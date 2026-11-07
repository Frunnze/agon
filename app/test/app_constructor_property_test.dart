import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

import 'support/app_harness.dart';
import 'support/random_inputs.dart';
import 'support/widget_harness.dart';

const int _firstSeed = 9490090;

final class _SilentRunWindowOpener implements RunWindowOpener {
  @override
  void openRunWindow({required RunId runId, required String title}) {}
}

AgentOrchestrationApp _buildRandomApp(Random random, {Key? key}) {
  RunWindowOpener? runWindowOpener;
  if (random.nextBool()) {
    runWindowOpener = _SilentRunWindowOpener();
  }
  final AppSection section = pickOne(random, AppSection.values);
  return AgentOrchestrationApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(initialRoute: SectionRoute(section)),
    messengerKey: GlobalKey<ScaffoldMessengerState>(),
    runWindowOpener: runWindowOpener,
    key: key,
  );
}

Key? _randomKey(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return ValueKey<String>(randomText(random));
}

void main() {
  test(
    'test_agent_orchestration_app_constructor_property_keeps_every_field',
    () {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AgentOrchestrationApp original = _buildRandomApp(random);
        final AgentOrchestrationApp copy = AgentOrchestrationApp(
          dependencies: original.dependencies,
          navigation: original.navigation,
          messengerKey: original.messengerKey,
          runWindowOpener: original.runWindowOpener,
        );

        expect(identical(copy.dependencies, original.dependencies), isTrue);
        expect(identical(copy.navigation, original.navigation), isTrue);
        expect(identical(copy.messengerKey, original.messengerKey), isTrue);
        expect(
          identical(copy.runWindowOpener, original.runWindowOpener),
          isTrue,
        );
      }
    },
  );

  test(
    'test_agent_orchestration_app_constructor_property_keeps_the_given_key',
    () {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Key? key = _randomKey(random);
        final AgentOrchestrationApp app = _buildRandomApp(random, key: key);

        expect(app.key, key);
      }
    },
  );

  testWidgets(
    'test_agent_orchestration_app_constructor_property_new_inputs_win',
    (WidgetTester tester) async {
      final Random random = seededRandom(_firstSeed + 2);
      useViewSize(tester, const Size(widestWidth, desktopHeight));

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AgentOrchestrationApp app = _buildRandomApp(random);
        await tester.pumpWidget(app);
        await tester.pump(settleTime);

        final AppShell shell = tester.widget<AppShell>(find.byType(AppShell));
        expect(tester.takeException(), isNull);
        expect(identical(shell.dependencies, app.dependencies), isTrue);
        expect(identical(shell.navigation, app.navigation), isTrue);
        expect(identical(shell.runWindowOpener, app.runWindowOpener), isTrue);
        expect(app.messengerKey.currentState, isNotNull);
      }
    },
  );
}
