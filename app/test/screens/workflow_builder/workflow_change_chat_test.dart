import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder/workflow_change_chat.dart';

import '../../support/random_inputs.dart';

const WorkflowId _workflowId = GalleryWorkflowIds.featurePipeline;
const List<String> _greetings = <String>[
  draftedWorkflowGreeting,
  openWorkflowGreeting,
];

final class _RecordedChange {
  const _RecordedChange({
    required this.workflowId,
    required this.request,
    required this.agent,
  });

  final WorkflowId workflowId;
  final String request;
  final AgentKind agent;
}

final class _ScriptedChanges {
  final List<_RecordedChange> recordedChanges = <_RecordedChange>[];
  final List<Completer<Workflow>> pendingAnswers = <Completer<Workflow>>[];

  Future<Workflow> changeWorkflow(
    WorkflowId workflowId,
    String request,
    AgentKind agent,
  ) {
    recordedChanges.add(
      _RecordedChange(workflowId: workflowId, request: request, agent: agent),
    );
    final Completer<Workflow> answer = Completer<Workflow>();
    pendingAnswers.add(answer);
    return answer.future;
  }
}

WorkflowChangeChat _openChat({
  required _ScriptedChanges changes,
  required String greeting,
}) {
  return WorkflowChangeChat(
    workflowId: _workflowId,
    greeting: greeting,
    changeWorkflow: changes.changeWorkflow,
  );
}

String _randomRequest(Random random) {
  return 'add ${randomWordPhrase(random)} step';
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

List<String> _readTexts(WorkflowChangeChat chat) {
  final List<String> texts = <String>[];
  for (final WorkflowChatMessage message in chat.messages) {
    texts.add(message.text);
  }
  return texts;
}

void main() {
  test('test_workflow_change_chat_property_opens_with_one_greeting', () {
    final Random random = seededRandom(7101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String greeting = pickOne(random, _greetings);
      final WorkflowChangeChat chat = _openChat(
        changes: _ScriptedChanges(),
        greeting: greeting,
      );

      expect(chat.messages, hasLength(1));
      final WorkflowChatMessage opening = chat.messages.single;
      expect(opening, isA<AgentMessage>());
      expect(opening.text, greeting);
      expect(chat.isWorking, isFalse);
      expect(chat.agent, AgentKind.claudeCode);
      chat.dispose();
    }
  });

  test('test_messages_property_cannot_be_changed_from_outside', () {
    final Random random = seededRandom(7102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowChangeChat chat = _openChat(
        changes: _ScriptedChanges(),
        greeting: pickOne(random, _greetings),
      );

      expect(
        () => chat.messages.add(PersonMessage(_randomRequest(random))),
        throwsUnsupportedError,
      );
      expect(chat.messages, hasLength(1));
      chat.dispose();
    }
  });

  test('test_messages_property_keep_the_order_they_were_written', () async {
    final Random random = seededRandom(7103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedChanges changes = _ScriptedChanges();
      final WorkflowChangeChat chat = _openChat(
        changes: changes,
        greeting: openWorkflowGreeting,
      );
      final List<String> requests = <String>[];
      final int requestCount = 1 + random.nextInt(4);

      for (int j = 0; j < requestCount; j += 1) {
        final String request = _randomRequest(random);
        requests.add(request);
        final Future<void> sending = chat.send(request);
        changes.pendingAnswers.last.complete(_emptyWorkflow());
        await sending;
      }

      final List<String> expectedTexts = <String>[openWorkflowGreeting];
      for (final String request in requests) {
        expectedTexts.add(request);
        expectedTexts.add(changeDoneReply);
      }
      expect(_readTexts(chat), expectedTexts);
      chat.dispose();
    }
  });

  test('test_choose_agent_property_the_next_change_uses_it', () async {
    final Random random = seededRandom(7104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedChanges changes = _ScriptedChanges();
      final WorkflowChangeChat chat = _openChat(
        changes: changes,
        greeting: openWorkflowGreeting,
      );
      final AgentKind chosen = pickOne(random, AgentKind.values);

      chat.chooseAgent(chosen);
      final Future<void> sending = chat.send(_randomRequest(random));
      changes.pendingAnswers.single.complete(_emptyWorkflow());
      await sending;

      expect(chat.agent, chosen);
      expect(changes.recordedChanges.single.agent, chosen);
      final AgentMessage reply = chat.messages.last as AgentMessage;
      expect(reply.agent, chosen);
      chat.dispose();
    }
  });

  test('test_choose_agent_property_tells_listeners_once', () {
    final Random random = seededRandom(7105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowChangeChat chat = _openChat(
        changes: _ScriptedChanges(),
        greeting: openWorkflowGreeting,
      );
      int notifications = 0;
      chat.addListener(() => notifications += 1);

      chat.chooseAgent(pickOne(random, AgentKind.values));

      expect(notifications, 1);
      expect(chat.messages, hasLength(1));
      chat.dispose();
    }
  });

  test('test_choose_agent_property_leaves_the_conversation_alone', () {
    final Random random = seededRandom(7106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String greeting = pickOne(random, _greetings);
      final WorkflowChangeChat chat = _openChat(
        changes: _ScriptedChanges(),
        greeting: greeting,
      );
      final int choiceCount = 1 + random.nextInt(5);

      for (int j = 0; j < choiceCount; j += 1) {
        chat.chooseAgent(pickOne(random, AgentKind.values));
      }

      expect(_readTexts(chat), <String>[greeting]);
      expect(chat.isWorking, isFalse);
      chat.dispose();
    }
  });

  test('test_send_property_shows_request_and_works_until_answered', () async {
    final Random random = seededRandom(7107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedChanges changes = _ScriptedChanges();
      final WorkflowChangeChat chat = _openChat(
        changes: changes,
        greeting: openWorkflowGreeting,
      );
      final String request = _randomRequest(random);

      final Future<void> sending = chat.send('  $request  ');

      expect(chat.isWorking, isTrue);
      expect(chat.messages.last, isA<PersonMessage>());
      expect(chat.messages.last.text, request);
      expect(changes.recordedChanges.single.request, request);
      expect(changes.recordedChanges.single.workflowId, _workflowId);
      changes.pendingAnswers.single.complete(_emptyWorkflow());
      await sending;
      expect(chat.isWorking, isFalse);
      expect(chat.messages.last.text, changeDoneReply);
      chat.dispose();
    }
  });

  test('test_send_property_a_refusal_becomes_the_agents_reply', () async {
    final Random random = seededRandom(7108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedChanges changes = _ScriptedChanges();
      final WorkflowChangeChat chat = _openChat(
        changes: changes,
        greeting: openWorkflowGreeting,
      );
      final String reason = randomWordPhrase(random);

      final Future<void> sending = chat.send(_randomRequest(random));
      changes.pendingAnswers.single.completeError(StateError(reason));
      await sending;

      expect(chat.isWorking, isFalse);
      expect(chat.messages.last, isA<AgentMessage>());
      expect(chat.messages.last.text, '$changeFailedReplyStart$reason');
      chat.dispose();
    }
  });

  test('test_send_property_refuses_blank_or_overlapping_requests', () async {
    final Random random = seededRandom(7109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedChanges changes = _ScriptedChanges();
      final WorkflowChangeChat chat = _openChat(
        changes: changes,
        greeting: openWorkflowGreeting,
      );
      final String blank = ' ' * random.nextInt(4);

      await expectLater(chat.send(blank), throwsArgumentError);
      expect(chat.messages, hasLength(1));
      final Future<void> sending = chat.send(_randomRequest(random));
      await expectLater(
        chat.send(_randomRequest(random)),
        throwsStateError,
      );
      expect(changes.recordedChanges, hasLength(1));
      changes.pendingAnswers.single.complete(_emptyWorkflow());
      await sending;
      chat.dispose();
    }
  });

  test('test_send_property_an_answer_after_closing_changes_nothing', () async {
    final Random random = seededRandom(7110);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedChanges changes = _ScriptedChanges();
      final WorkflowChangeChat chat = _openChat(
        changes: changes,
        greeting: openWorkflowGreeting,
      );

      final Future<void> sending = chat.send(_randomRequest(random));
      final List<String> textsBeforeClosing = _readTexts(chat);
      chat.dispose();
      if (random.nextBool()) {
        changes.pendingAnswers.single.complete(_emptyWorkflow());
      } else {
        changes.pendingAnswers.single.completeError(StateError('gone'));
      }
      await sending;

      expect(_readTexts(chat), textsBeforeClosing);
    }
  });
}
