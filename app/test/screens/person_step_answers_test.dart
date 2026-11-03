import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/approvals/approvals_screen.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/screens/task_run/run_notes_section.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/count_badge.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/person_step_dependencies.dart';

const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const TaskRunRoute _runRoute = TaskRunRoute(GalleryRunIds.release42);
const String _limitNote = 'build-ios → plan reached its limit of 2 rounds';

Finder _findWrittenAnswerField() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField &&
        widget.decoration?.hintText == writtenAnswerHint,
  );
}

Future<void> _sendWrittenAnswer(WidgetTester tester, String answer) async {
  await tester.enterText(_findWrittenAnswerField(), answer);
  await tester.tap(find.widgetWithText(AppButton, sendAnswerLabel));
  await pumpFrames(tester);
}

int _countOpenQuestions(AppDependencies dependencies) {
  return dependencies.personStepRepository.listOpenPersonSteps().length;
}

void main() {
  testWidgets('approvals list the question with what came in', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: const <RunNote>[],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _approvalsRoute,
      dependencies: dependencies,
    );

    expect(find.text(questionsSectionTitle), findsOneWidget);
    expect(find.text(describeQuestionTitle(questionStepName)), findsOneWidget);
    expect(find.text(questionText), findsOneWidget);
    expect(find.text(whatCameInLabel), findsOneWidget);
    expect(find.text(buildResultText), findsOneWidget);
    expect(find.textContaining('release #42 · asked'), findsOneWidget);
    expect(find.textContaining('1 question and'), findsOneWidget);
  });

  testWidgets('the approvals badge counts waiting questions too', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: const <RunNote>[],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _approvalsRoute,
      dependencies: dependencies,
    );
    final int pendingApprovals = dependencies.approvalRepository
        .listPendingApprovals()
        .length;

    final CountBadge badge = tester.widget<CountBadge>(
      find.byType(CountBadge),
    );

    expect(badge.count, pendingApprovals + 1);
  });

  testWidgets('a choice button answers the question from approvals', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: const <RunNote>[],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _approvalsRoute,
      dependencies: dependencies,
    );

    await tester.tap(find.widgetWithText(AppButton, 'approved'));
    await pumpFrames(tester);

    expect(_countOpenQuestions(dependencies), 0);
    expect(find.text(questionText), findsNothing);
  });

  testWidgets('an answer naming no choice shows the choices', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: const <RunNote>[],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _approvalsRoute,
      dependencies: dependencies,
    );

    await _sendWrittenAnswer(tester, 'approve it');

    expect(
      find.text('The answer names none of the choices: approved, changes'),
      findsOneWidget,
    );
    expect(_countOpenQuestions(dependencies), 1);
  });

  testWidgets('an empty written answer is not sent', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: const <RunNote>[],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _approvalsRoute,
      dependencies: dependencies,
    );

    await _sendWrittenAnswer(tester, '   ');

    expect(find.text(emptyAnswerProblem), findsOneWidget);
    expect(_countOpenQuestions(dependencies), 1);
  });

  testWidgets('the run page answers the question with free text', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: const <RunNote>[],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _runRoute,
      dependencies: dependencies,
    );
    expect(find.text('Waiting for you'), findsOneWidget);
    expect(find.text(questionText), findsOneWidget);

    await _sendWrittenAnswer(tester, ' Changes ');

    expect(_countOpenQuestions(dependencies), 0);
    expect(find.text(questionText), findsNothing);
  });

  testWidgets('the run page shows rounds, earlier rounds and notes', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithQuestion(
      notes: <RunNote>[RunNote(at: galleryToday(14, 6), text: _limitNote)],
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _runRoute,
      dependencies: dependencies,
    );

    expect(find.textContaining('round 2'), findsOneWidget);
    expect(find.text(runNotesTitle), findsOneWidget);
    expect(find.text(_limitNote), findsOneWidget);
    expect(
      find.text('Built 2.4 (1179) but the icons were wrong.'),
      findsNothing,
    );

    final Finder toggle = find.text('Show 1 earlier round');
    final Finder rowSubtitle = find.textContaining('round 2');
    final Rect toggleBox = tester.getRect(toggle);
    final Rect subtitleBox = tester.getRect(rowSubtitle);
    expect(toggleBox.top, greaterThanOrEqualTo(subtitleBox.bottom));
    expect(toggleBox.top - subtitleBox.bottom, lessThan(16));
    expect(toggleBox.left, closeTo(subtitleBox.left, 1));
    final Text toggleText = tester.widget<Text>(toggle);
    expect(toggleText.style?.decoration, isNot(TextDecoration.underline));

    await tapVisible(tester, toggle);
    await pumpFrames(tester);

    expect(find.text('Hide 1 earlier round'), findsOneWidget);
    expect(find.textContaining('Round 1 · Done'), findsOneWidget);
    expect(
      find.text('Built 2.4 (1179) but the icons were wrong.'),
      findsOneWidget,
    );
  });
}
