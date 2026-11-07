import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'planned_refusal.dart';

const String refusalCloseLabel = 'Close';

typedef OpenRefusingPage = Future<void> Function(
  WidgetTester tester, {
  required Size size,
  required PlannedRefusal refusal,
});

typedef PerformPersonAction = Future<void> Function(WidgetTester tester);

typedef ExpectActionSucceeded = void Function(WidgetTester tester);

enum RefusalPlace { dialogOverPage, bannerOnPage }

final class RefusedActionCase {
  const RefusedActionCase({
    required this.functionName,
    required this.actionLabel,
    required this.place,
    required this.openPage,
    required this.performAction,
    required this.expectSucceeded,
  });

  final String functionName;
  final String actionLabel;
  final RefusalPlace place;
  final OpenRefusingPage openPage;
  final PerformPersonAction performAction;
  final ExpectActionSucceeded expectSucceeded;
}

String describeRefusalTitle(String actionLabel) => '$actionLabel did not work';

Size randomActionWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, desktopHeight);
}

Future<void> tapButtonLabelled(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

Future<void> _closeShownRefusal(
  WidgetTester tester,
  RefusedActionCase actionCase,
  PlannedRefusal refusal,
) async {
  if (actionCase.place == RefusalPlace.dialogOverPage) {
    await tapButtonLabelled(tester, refusalCloseLabel);
    return;
  }
  refusal.problem = null;
  await actionCase.performAction(tester);
}

Future<Object?> _performReportingFailure(
  RefusedActionCase actionCase,
  WidgetTester tester,
) async {
  try {
    await actionCase.performAction(tester);
  } on Object catch (failure) {
    return failure;
  }
  return null;
}

void registerRefusedActionProperties(
  RefusedActionCase actionCase, {
  required int seed,
}) {
  final String testPrefix = 'test_${actionCase.functionName}_property';
  final String refusalTitle = describeRefusalTitle(actionCase.actionLabel);

  testWidgets('${testPrefix}_a_refusal_is_shown_in_plain_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomActionWindowSize(random);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      final PlannedRefusal refusal = PlannedRefusal();
      await tester.pumpWidget(const SizedBox.shrink());
      await actionCase.openPage(tester, size: size, refusal: refusal);
      refusal.attempts = 0;
      refusal.problem = planned.problem;

      await actionCase.performAction(tester);

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(refusal.attempts, 1);
      expect(find.text(refusalTitle), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
      await _closeShownRefusal(tester, actionCase, refusal);
      refusal.problem = null;
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text(refusalTitle), findsNothing);
    }
  });

  testWidgets('${testPrefix}_unexplained_problems_are_not_hidden', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      await tester.pumpWidget(const SizedBox.shrink());
      await actionCase.openPage(
        tester,
        size: randomActionWindowSize(random),
        refusal: refusal,
      );
      refusal.problem = randomUnexplainedProblem(random);

      final List<Object> escapedProblems = <Object>[];
      final Object? performFailure = await runZonedGuarded<Future<Object?>>(
        () => _performReportingFailure(actionCase, tester),
        (Object problem, StackTrace _) => escapedProblems.add(problem),
      );

      refusal.problem = null;
      expect(performFailure, isNull);
      expect(escapedProblems, <Matcher>[isA<FormatException>()]);
      expect(find.text(refusalTitle), findsNothing);
    }
  });

  testWidgets('${testPrefix}_without_a_refusal_it_still_succeeds', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomActionWindowSize(random);
      final PlannedRefusal refusal = PlannedRefusal();
      await tester.pumpWidget(const SizedBox.shrink());
      await actionCase.openPage(tester, size: size, refusal: refusal);
      refusal.attempts = 0;

      await actionCase.performAction(tester);

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(refusal.attempts, greaterThan(0));
      expect(find.text(refusalTitle), findsNothing);
      actionCase.expectSucceeded(tester);
    }
  });
}
