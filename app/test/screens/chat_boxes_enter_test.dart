import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/builder_harness.dart';
import '../support/message_keys.dart';
import '../support/person_step_dependencies.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const String _askHint = 'Ask the agent, e.g. add a test step after ios';
const String _askedChange = 'add a test step after ios';

Finder _findTextFieldHinted(String hint) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.hintText == hint,
  );
}

void main() {
  testWidgets('test_change_request_composer_property_enter_sends_the_note', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6201);
    final List<String> sentNotes = <String>[];
    const String example = 'For example: ask before pushing';

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, computerPlatformList);
      await pumpScrollableOnPlatform(
        tester,
        width: desktopWidth,
        platform: platform,
        child: ChangeRequestComposer(example: example, onSend: sentNotes.add),
      );
      final String note = '${randomWordPhrase(random)} ';
      await tester.enterText(_findTextFieldHinted(example), note);
      sentNotes.clear();

      final bool isHandled = await pressEnter(tester);

      final String trimmedNote = note.trim();
      final List<String> expectedNotes = <String>[
        if (trimmedNote.isNotEmpty) trimmedNote,
      ];
      expect(isHandled, isTrue, reason: '$platform "$note"');
      expect(sentNotes, expectedNotes, reason: '$platform "$note"');
    }
  });

  testWidgets('Enter answers the person step on computers', (
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

    await tester.enterText(_findTextFieldHinted(writtenAnswerHint), 'changes');
    final bool isHandled = await pressEnter(tester);
    await pumpFrames(tester);

    expect(isHandled, isTrue);
    expect(dependencies.personStepRepository.listOpenPersonSteps(), isEmpty);
  }, variant: onComputers);

  testWidgets('Enter asks the workflow agent on computers', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await tester.enterText(_findTextFieldHinted(_askHint), _askedChange);
    final bool isHandled = await pressEnter(tester);
    await pumpFrames(tester);

    final Workflow changed = readPipeline(dependencies);
    expect(isHandled, isTrue);
    expect(changed.agents.last.task, _askedChange);
  }, variant: onComputers);
}
