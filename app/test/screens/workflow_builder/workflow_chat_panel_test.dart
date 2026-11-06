import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/workflow_builder/builder_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder/workflow_change_chat.dart';
import 'package:agent_orchestration/screens/workflow_builder/workflow_chat_panel.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const WorkflowId _workflowId = GalleryWorkflowIds.featurePipeline;

final class _PendingChanges {
  final List<Completer<Workflow>> pendingAnswers = <Completer<Workflow>>[];

  Future<Workflow> changeWorkflow(
    WorkflowId workflowId,
    String request,
    AgentKind agent,
  ) {
    final Completer<Workflow> answer = Completer<Workflow>();
    pendingAnswers.add(answer);
    return answer.future;
  }
}

Workflow _emptyWorkflow() {
  return Workflow(
    id: _workflowId,
    name: 'flow',
    availability: const AllWorkspaces(),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required WorkflowChangeChat chat,
  required double width,
  VoidCallback? onClosed,
}) async {
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: WorkflowChatPanel(chat: chat, onClosed: onClosed ?? () {}),
  );
}

double _randomPanelWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Finder _findSendButton() {
  return find.text(sendChangeLabel);
}

void main() {
  testWidgets('test_workflow_chat_panel_property_shows_every_message', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _PendingChanges changes = _PendingChanges();
      final WorkflowChangeChat chat = WorkflowChangeChat(
        workflowId: _workflowId,
        greeting: openWorkflowGreeting,
        changeWorkflow: changes.changeWorkflow,
      );
      final AgentKind agent = pickOne(random, AgentKind.values);
      chat.chooseAgent(agent);
      final String request = 'add ${randomWordPhrase(random)} step';
      final Future<void> sending = chat.send(request);
      changes.pendingAnswers.single.complete(_emptyWorkflow());
      await sending;

      await _pumpPanel(tester, chat: chat, width: _randomPanelWidth(random));

      expect(find.text(chatPanelTitle), findsOneWidget);
      expect(find.text(openWorkflowGreeting), findsOneWidget);
      expect(find.text(request), findsOneWidget);
      expect(find.text(changeDoneReply), findsOneWidget);
      expect(find.text(agent.label), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
      chat.dispose();
    }
  });

  testWidgets('test_workflow_chat_panel_property_working_hides_the_composer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _PendingChanges changes = _PendingChanges();
      final WorkflowChangeChat chat = WorkflowChangeChat(
        workflowId: _workflowId,
        greeting: draftedWorkflowGreeting,
        changeWorkflow: changes.changeWorkflow,
      );
      final AgentKind agent = pickOne(random, AgentKind.values);
      chat.chooseAgent(agent);
      await _pumpPanel(tester, chat: chat, width: _randomPanelWidth(random));
      expect(_findSendButton(), findsOneWidget);

      final Future<void> sending = chat.send(
        'add ${randomWordPhrase(random)} step',
      );
      await tester.pump();

      expect(find.text(describeChangeInProgress(agent)), findsOneWidget);
      expect(_findSendButton(), findsNothing);
      changes.pendingAnswers.single.complete(_emptyWorkflow());
      await sending;
      await tester.pump();
      expect(find.text(describeChangeInProgress(agent)), findsNothing);
      expect(_findSendButton(), findsOneWidget);
      chat.dispose();
    }
  });

  testWidgets('test_workflow_chat_panel_property_picker_chooses_agent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowChangeChat chat = WorkflowChangeChat(
        workflowId: _workflowId,
        greeting: openWorkflowGreeting,
        changeWorkflow: _PendingChanges().changeWorkflow,
      );
      int closeCount = 0;
      await _pumpPanel(
        tester,
        chat: chat,
        width: _randomPanelWidth(random),
        onClosed: () => closeCount += 1,
      );
      final AgentKind chosen = pickOne(random, AgentKind.values);

      final Finder picker = find.byType(SelectField<AgentKindChoice>);
      tester
          .widget<SelectField<AgentKindChoice>>(picker)
          .onChanged(AgentKindChoice(chosen));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(chat.agent, chosen);
      expect(closeCount, 1);
      chat.dispose();
    }
  });

  test('test_describe_change_in_progress_property_starts_with_agent', () {
    for (final AgentKind agent in AgentKind.values) {
      expect(describeChangeInProgress(agent), startsWith(agent.label));
    }
  });

  test('test_describe_change_in_progress_property_ends_with_ellipsis', () {
    for (final AgentKind agent in AgentKind.values) {
      expect(describeChangeInProgress(agent), endsWith('…'));
    }
  });

  test('test_describe_change_in_progress_property_differs_per_agent', () {
    final Set<String> descriptions = <String>{
      for (final AgentKind agent in AgentKind.values)
        describeChangeInProgress(agent),
    };

    expect(descriptions, hasLength(AgentKind.values.length));
  });

  testWidgets('test_person_message_bubble_property_hugs_the_right_edge', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomPanelWidth(random);
      final String text = randomWordPhrase(random);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: PersonMessageBubble(text: 'say $text'),
      );

      final Rect bubble = tester.getRect(find.byType(Container).last);
      expect(bubble.right, closeTo(width, 0.5), reason: 'width $width');
      expect(bubble.width, lessThanOrEqualTo(width * 0.85 + 0.5));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_agent_reply_property_names_the_agent_above_its_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentKind agent = pickOne(random, AgentKind.values);
      final String words = 'reply ${randomWordPhrase(random)}';
      await pumpScrollableAtWidth(
        tester,
        width: _randomPanelWidth(random),
        child: AgentReply(agent: agent, text: words),
      );

      final Rect label = tester.getRect(find.text(agent.label));
      final Rect reply = tester.getRect(find.text(words));
      expect(label.bottom, lessThanOrEqualTo(reply.top));
      expect(label.left, reply.left);
    }
  });

  testWidgets('test_person_message_bubble_property_long_words_wrap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomPanelWidth(random);
      final String longText = List<String>.generate(
        12,
        (int index) => randomWordPhrase(random),
      ).join(' ');
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: PersonMessageBubble(text: 'say $longText'),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      final Rect bubble = tester.getRect(find.byType(Container).last);
      expect(bubble.left, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('test_agent_reply_property_long_replies_wrap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomPanelWidth(random);
      final String longReply = List<String>.generate(
        12,
        (int index) => randomWordPhrase(random),
      ).join(' ');
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: AgentReply(
          agent: pickOne(random, AgentKind.values),
          text: 'reply $longReply',
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(
        tester.getSize(find.byType(AgentReply)).width,
        lessThanOrEqualTo(width),
      );
    }
  });

  testWidgets('test_change_in_progress_line_property_icon_and_words_share', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomPanelWidth(random);
      final AgentKind agent = pickOne(random, AgentKind.values);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ChangeInProgressLine(agent: agent),
      );

      final Rect line = tester.getRect(find.byType(ChangeInProgressLine));
      final Rect words = tester.getRect(
        find.text(describeChangeInProgress(agent)),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(words.top, greaterThanOrEqualTo(line.top));
      expect(words.bottom, lessThanOrEqualTo(line.bottom));
      expect(words.right, lessThanOrEqualTo(width));
    }
  });
}
