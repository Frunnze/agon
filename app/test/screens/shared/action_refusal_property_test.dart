import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';

const String _startActionLabel = 'Start action';

Future<void> _pumpActionStarter(
  WidgetTester tester, {
  required Size size,
  required String title,
  required String actionLabel,
  required PersonAction action,
  required List<ActionOutcome> outcomes,
}) async {
  useViewSize(tester, size);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      Builder(
        builder: (BuildContext context) => GestureDetector(
          onTap: () => unawaited(
            runShowingRefusal(
              context: context,
              title: title,
              actionLabel: actionLabel,
              action: action,
            ).then(outcomes.add),
          ),
          child: const Text(_startActionLabel),
        ),
      ),
      platform: platformMeantByWidth(size.width),
    ),
  );
}

Future<void> _startAction(WidgetTester tester) async {
  await tester.tap(find.text(_startActionLabel));
  await pumpFrames(tester);
}

void main() {
  test(
    'test_catch_refusal_property_explained_problems_become_refusals',
    () async {
      final Random random = seededRandom(91001);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ExplainedRefusal planned = randomExplainedRefusal(random);
        final String actionLabel = randomWordPhrase(random);

        final SubmitRefusal? refusal = await catchRefusal(
          actionLabel: actionLabel,
          action: () => Future<void>.error(planned.problem),
        );

        expect(refusal?.actionLabel, actionLabel);
        expect(refusal?.explanation, planned.explanation);
      }
    },
  );

  test('test_catch_refusal_property_success_has_no_refusal_and_runs_'
      'once', () async {
    final Random random = seededRandom(91002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PlannedRefusal planned = PlannedRefusal();

      final SubmitRefusal? refusal = await catchRefusal(
        actionLabel: randomText(random),
        action: () => planned.refuseOr(Future<void>.value),
      );

      expect(refusal, isNull);
      expect(planned.attempts, 1);
    }
  });

  test('test_catch_refusal_property_unexplained_problems_escape', () async {
    final Random random = seededRandom(91003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormatException problem = randomUnexplainedProblem(random);

      final Future<SubmitRefusal?> caught = catchRefusal(
        actionLabel: randomText(random),
        action: () => Future<void>.error(problem),
      );

      await expectLater(caught, throwsA(same(problem)));
    }
  });

  testWidgets('test_run_showing_refusal_property_refusal_dialog_shows_'
      'title_label_and_reason', (WidgetTester tester) async {
    final Random random = seededRandom(91004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ActionOutcome> outcomes = <ActionOutcome>[];
      final Size size = randomActionWindowSize(random);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      final String title = 'title ${randomWordPhrase(random)}';
      final String actionLabel = 'action ${randomWordPhrase(random)}';
      await _pumpActionStarter(
        tester,
        size: size,
        title: title,
        actionLabel: actionLabel,
        action: () => Future<void>.error(planned.problem),
        outcomes: outcomes,
      );

      await _startAction(tester);

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text(title), findsOneWidget);
      expect(find.text(describeRefusalTitle(actionLabel)), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
      final Rect dialogArea = tester.getRect(find.byType(AppDialog));
      expect(dialogArea.right, lessThanOrEqualTo(size.width));
      await tapButtonLabelled(tester, refusalCloseLabel);
      expect(find.byType(ActionRefusalDialog), findsNothing);
      expect(outcomes, <ActionOutcome>[ActionOutcome.refused]);
    }
  });

  testWidgets('test_run_showing_refusal_property_success_opens_no_dialog', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ActionOutcome> outcomes = <ActionOutcome>[];
      final PlannedRefusal planned = PlannedRefusal();
      await _pumpActionStarter(
        tester,
        size: randomActionWindowSize(random),
        title: randomWordPhrase(random),
        actionLabel: randomWordPhrase(random),
        action: () => planned.refuseOr(Future<void>.value),
        outcomes: outcomes,
      );

      await _startAction(tester);

      expect(tester.takeException(), isNull);
      expect(planned.attempts, 1);
      expect(find.byType(ActionRefusalDialog), findsNothing);
      expect(outcomes, <ActionOutcome>[ActionOutcome.done]);
    }
  });

  testWidgets('test_run_showing_refusal_property_unexplained_problems_'
      'escape_without_a_dialog', (WidgetTester tester) async {
    final Random random = seededRandom(91006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ActionOutcome> outcomes = <ActionOutcome>[];
      final FormatException problem = randomUnexplainedProblem(random);
      await _pumpActionStarter(
        tester,
        size: randomActionWindowSize(random),
        title: randomWordPhrase(random),
        actionLabel: randomWordPhrase(random),
        action: () => Future<void>.error(problem),
        outcomes: outcomes,
      );

      final List<Object> escapedProblems = <Object>[];
      await runZonedGuarded(
        () => _startAction(tester),
        (Object escaped, StackTrace _) => escapedProblems.add(escaped),
      );

      expect(escapedProblems, <Object>[same(problem)]);
      expect(find.byType(ActionRefusalDialog), findsNothing);
      expect(outcomes, isEmpty);
    }
  });

  testWidgets('test_action_refusal_dialog_build_property_long_reasons_fit_'
      'and_close', (WidgetTester tester) async {
    final Random random = seededRandom(91007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ActionOutcome> outcomes = <ActionOutcome>[];
      final Size size = randomActionWindowSize(random);
      final String longReason = List<String>.filled(
        1 + random.nextInt(60),
        randomWordPhrase(random),
      ).join(' ');
      await _pumpActionStarter(
        tester,
        size: size,
        title: randomWordPhrase(random),
        actionLabel: randomWordPhrase(random),
        action: () => Future<void>.error(StateError(longReason)),
        outcomes: outcomes,
      );

      await _startAction(tester);

      expect(tester.takeException(), isNull, reason: 'size $size');
      final Rect dialogArea = tester.getRect(find.byType(AppDialog));
      expect(dialogArea.left, greaterThanOrEqualTo(0));
      expect(dialogArea.bottom, lessThanOrEqualTo(size.height));
      await tapButtonLabelled(tester, refusalCloseLabel);
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.byType(ActionRefusalDialog), findsNothing);
    }
  });

  test('test_action_refusal_dialog_constructor_property_keeps_its_'
      'fields', () {
    final Random random = seededRandom(91008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomText(random);
      final SubmitRefusal refusal = SubmitRefusal(
        actionLabel: randomText(random),
        explanation: randomText(random),
      );

      final ActionRefusalDialog dialog = ActionRefusalDialog(
        title: title,
        refusal: refusal,
      );

      expect(dialog.title, title);
      expect(dialog.refusal, same(refusal));
    }
  });

  testWidgets('test_action_refusal_dialog_build_property_title_stays_'
      'outside_the_banner', (WidgetTester tester) async {
    final Random random = seededRandom(91009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ActionOutcome> outcomes = <ActionOutcome>[];
      final String title = 'page ${randomWordPhrase(random)}';
      final String actionLabel = 'button ${randomWordPhrase(random)}';
      await _pumpActionStarter(
        tester,
        size: randomActionWindowSize(random),
        title: title,
        actionLabel: actionLabel,
        action: () => Future<void>.error(StateError(randomText(random))),
        outcomes: outcomes,
      );

      await _startAction(tester);

      expect(find.text(title), findsOneWidget);
      expect(find.text(describeRefusalTitle(title)), findsNothing);
      expect(find.text(describeRefusalTitle(actionLabel)), findsOneWidget);
      await tapButtonLabelled(tester, refusalCloseLabel);
    }
  });
}
