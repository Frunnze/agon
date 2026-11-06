import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/random_inputs.dart';

const double _narrowestDesktopWidth = 1100;
const double _widestDesktopWidth = 2200;

Size _pickDesktopSize(Random random) {
  final double width = randomWidth(
    random,
    least: _narrowestDesktopWidth,
    most: _widestDesktopWidth,
  );
  return Size(width, tallDesktopSize.height);
}

Finder _findChatField() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField &&
        widget.decoration?.hintText == chatRequestExample,
  );
}

Future<void> _openPipelineForEditing(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: workflowsSectionRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(
    const WorkflowBuilderRoute(pipelineId, opening: BuilderOpening.forEditing),
  );
  await pumpFrames(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_workflow_builder_property_after_drafting_chat_greets', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openPipelineBuilder(
        tester,
        size: _pickDesktopSize(random),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.text(chatPanelTitle), findsOneWidget);
      expect(find.text(draftedWorkflowGreeting), findsOneWidget);
      expect(find.text('Drafted from your description'), findsNothing);
      expect(_findChatField(), findsOneWidget);
    }
  });

  testWidgets('test_workflow_builder_property_chat_changes_the_diagram', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await openPipelineBuilder(
        tester,
        size: _pickDesktopSize(random),
        dependencies: dependencies,
      );
      final int agentCountBefore = readPipeline(dependencies).agents.length;
      final String request = 'add ${randomWordPhrase(random)} step';

      await tester.enterText(_findChatField(), request);
      await _tapText(tester, 'Send');

      final Workflow changed = readPipeline(dependencies);
      expect(changed.agents.length, agentCountBefore + 1);
      expect(changed.agents.last.task, request);
      expect(findDiagramNode('requested-step'), findsOneWidget);
      expect(find.text(request), findsOneWidget);
      expect(find.text(changeDoneReply), findsOneWidget);
    }
  });

  testWidgets('test_workflow_builder_property_ask_an_agent_reopens_chat', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openPipelineForEditing(
        tester,
        size: _pickDesktopSize(random),
        dependencies: buildGalleryDependencies(),
      );
      expect(find.byType(WorkflowChatPanel), findsNothing);

      await selectDiagramNode(tester, 'backend');
      expect(find.text('Agent settings'), findsOneWidget);
      await _tapText(tester, askAnAgentLabel);

      expect(find.byType(WorkflowChatPanel), findsOneWidget);
      expect(find.text(openWorkflowGreeting), findsOneWidget);
      expect(find.text('Agent settings'), findsNothing);
      await _tapText(tester, 'Done');
      expect(find.byType(WorkflowChatPanel), findsNothing);
    }
  });

  testWidgets('test_workflow_builder_property_phones_start_with_chat_closed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double phoneWidth = randomWidth(random, least: 360, most: 430);
      await openPipelineBuilder(
        tester,
        size: Size(phoneWidth, phoneSize.height),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.byType(WorkflowChatPanel), findsNothing);
      await _tapText(tester, askAnAgentLabel);
      expect(find.byType(WorkflowChatPanel), findsOneWidget);
      expect(find.text(draftedWorkflowGreeting), findsOneWidget);
    }
  });
}
