import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const int _sequenceIterations = 20;
const int _messagesPerRun = 6;

typedef _Fixture = ({
  SimulatedWorkNode node,
  NodeBackedTaskRepository tasks,
  NodeBackedChatRepository chat,
});

_Fixture _buildFixture() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedTaskRepository tasks = NodeBackedTaskRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: workspaces,
    livePollInterval: Duration.zero,
    jobRepository: NodeBackedJobRepository(
      channel: buildSimulatedChannel(simulated.answer),
      workspaceRepository: workspaces,
      clock: const SystemClock(),
    ),
  );
  final NodeBackedChatRepository chat = NodeBackedChatRepository(
    channel: buildSimulatedChannel(simulated.answer),
    runSource: tasks,
    workspaceRepository: workspaces,
  );
  return (node: simulated, tasks: tasks, chat: chat);
}

Future<Run> _startRandomRun(Random random, _Fixture fixture) async {
  final Task task = await fixture.tasks.createTask(randomTaskDraft(random));
  return fixture.tasks.startTask(task.id);
}

String _randomMessageText(Random random) => 'message ${randomText(random)}';

void main() {
  test('test_send_message_property_conversation_ends_with_message', () async {
    final Random random = seededRandom(9921);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final Run run = await _startRandomRun(random, fixture);
      final List<String> sentTexts = <String>[];

      for (int message = 0; message < _messagesPerRun; message += 1) {
        final String text = _randomMessageText(random);
        final ChatMessage sent = await fixture.chat.sendMessage(run.id, text);
        sentTexts.add(text.trim());

        expect(sent.author, ChatAuthor.you);
        expect(sent.text, text.trim());
        final Conversation conversation = fixture.chat.findConversation(
          run.id,
        );
        expect(
          conversation.messages.map((ChatMessage message) => message.text),
          sentTexts,
        );
      }
    }
  });

  test('test_send_message_property_blank_text_is_refused_locally', () async {
    final Random random = seededRandom(9922);
    final _Fixture fixture = _buildFixture();
    final Run run = await _startRandomRun(random, fixture);
    final int commandsBefore = fixture.node.receivedCommands.length;
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String blank = ' ' * random.nextInt(_messagesPerRun);
      await expectLater(
        fixture.chat.sendMessage(run.id, blank),
        throwsArgumentError,
      );
    }
    expect(fixture.node.receivedCommands.length, commandsBefore);
  });

  test('test_send_message_property_notifies_chat_listeners', () async {
    final Random random = seededRandom(9923);
    final _Fixture fixture = _buildFixture();
    final Run run = await _startRandomRun(random, fixture);
    int notifications = 0;
    fixture.chat.addListener(() => notifications += 1);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final int before = notifications;
      await fixture.chat.sendMessage(run.id, _randomMessageText(random));
      expect(notifications, greaterThan(before));
    }
  });

  test('test_build_conversation_from_run_property_keeps_chat_and_link', () {
    final Random random = seededRandom(9924);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = mapRunFromNode(node.Run.fromJson(randomRunJson(random)));
      final Conversation conversation = buildConversationFromRun(run);

      expect(conversation.runId, run.id);
      expect(conversation.messages, run.chat);
      expect(conversation.link, run.link);
      expect(conversation.linkLostAt, run.linkLostAt);
    }
  });

  test(
    'test_build_conversation_from_run_property_replying_while_a_step_runs',
    () {
      final Random random = seededRandom(9926);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = mapRunFromNode(
          node.Run.fromJson(randomRunJson(random)),
        );
        final bool hasRunningStep = run.steps.any(
          (RunStep step) => step.status == StepStatus.running,
        );
        final AgentActivity expectedActivity = hasRunningStep
            ? AgentActivity.replying
            : AgentActivity.idle;

        final Conversation conversation = buildConversationFromRun(run);

        expect(conversation.agentActivity, expectedActivity);
      }
    },
  );

  test('test_find_conversation_property_unknown_run_is_record_not_found', () {
    final Random random = seededRandom(9925);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => fixture.chat.findConversation(RunId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
