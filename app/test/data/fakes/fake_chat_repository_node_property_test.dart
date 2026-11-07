import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_work_node.dart';
import 'support/chat_inputs.dart';

const String _typePrefix = 'test_fake_chat_repository';
const String _thisDeviceText = 'this-device';
const int _sequenceIterations = 30;
const int _largestRunCount = 4;
const int _longestSequence = 8;

enum _Outcome { accepted, blankText, missingRun }

typedef _Pair = ({
  FakeChatRepository fake,
  NodeBackedChatRepository nodeBacked,
  List<RunId> runIds,
});

typedef _MessageView = ({String text, ChatAuthor author});

Future<_Pair> _buildPair(Random random) async {
  final SimulatedWorkNode simulated = SimulatedWorkNode(
    thisDeviceId: _thisDeviceText,
  );
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedTaskRepository nodeTasks = NodeBackedTaskRepository(
    clock: const SystemClock(),
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: workspaces,
    livePollInterval: Duration.zero,
    jobRepository: NodeBackedJobRepository(
      channel: buildSimulatedChannel(simulated.answer),
      workspaceRepository: workspaces,
      clock: const SystemClock(),
    ),
  );
  final List<RunId> runIds = <RunId>[];
  final List<Run> runs = <Run>[];
  final int runCount = random.nextInt(_largestRunCount);
  for (int i = 0; i < runCount; i += 1) {
    final String taskId = simulated.addTaskFromElsewhere(random);
    final RunId runId = RunId(simulated.addRunFromElsewhere(random, taskId));
    runIds.add(runId);
    runs.add(await nodeTasks.refreshRun(runId));
  }
  final FakeChatRepository fake = FakeChatRepository(
    conversations: const <Conversation>[],
    taskRepository: buildTaskRepositoryWithRuns(runs),
    clock: FixedClock(randomUtcMoment(random)),
  );
  final NodeBackedChatRepository nodeBacked = NodeBackedChatRepository(
    channel: buildSimulatedChannel(simulated.answer),
    runSource: nodeTasks,
    workspaceRepository: workspaces,
  );
  return (fake: fake, nodeBacked: nodeBacked, runIds: runIds);
}

RunId _pickRunId(Random random, _Pair pair) {
  if (pair.runIds.isEmpty || random.nextInt(4) == 0) {
    return randomMissingChatRunId(random);
  }
  return pickOne(random, pair.runIds);
}

String _pickText(Random random) {
  if (random.nextInt(4) == 0) {
    return pickOne(random, blankChatTexts);
  }
  return randomChatMessageText(random);
}

_Outcome _reportAccepted(ChatMessage sent) => _Outcome.accepted;

_Outcome _reportBlankText(Object error) => _Outcome.blankText;

_Outcome _reportMissingRun(Object error) => _Outcome.missingRun;

bool _isBlankTextRefusal(Object error) => error is ArgumentError;

bool _isMissingRunRefusal(Object error) => error is RecordNotFound;

Future<_Outcome> _send(ChatRepository repository, RunId runId, String text) {
  final Future<_Outcome> sent = repository
      .sendMessage(runId, text)
      .then(_reportAccepted);
  final Future<_Outcome> blankChecked = sent.catchError(
    _reportBlankText,
    test: _isBlankTextRefusal,
  );
  return blankChecked.catchError(
    _reportMissingRun,
    test: _isMissingRunRefusal,
  );
}

Future<void> _sendOnBoth(Random random, _Pair pair) async {
  final RunId runId = _pickRunId(random, pair);
  final String text = _pickText(random);

  final _Outcome fakeOutcome = await _send(pair.fake, runId, text);
  final _Outcome nodeOutcome = await _send(pair.nodeBacked, runId, text);

  expect(fakeOutcome, nodeOutcome, reason: runId.value);
}

List<_MessageView> _describeMessages(Conversation conversation) {
  final List<_MessageView> views = <_MessageView>[];
  for (final ChatMessage message in conversation.messages) {
    views.add((text: message.text, author: message.author));
  }
  return views;
}

void _expectSameConversations(_Pair pair) {
  for (final RunId runId in pair.runIds) {
    final Conversation fromFake = pair.fake.findConversation(runId);
    final Conversation fromNode = pair.nodeBacked.findConversation(runId);

    expect(
      _describeMessages(fromFake),
      orderedEquals(_describeMessages(fromNode)),
    );
    expect(fromFake.link, fromNode.link);
    expect(fromFake.linkLostAt, fromNode.linkLostAt);
    expect(fromFake.agentActivity, fromNode.agentActivity);
  }
}

void main() {
  test('${_typePrefix}_send_message_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(66201);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _sendOnBoth(random, pair);
      }
    }
  });

  test('${_typePrefix}_find_conversation_property_agrees_with_the_node_'
      'backed_repository', () async {
    final Random random = seededRandom(66202);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = random.nextInt(_longestSequence);

      _expectSameConversations(pair);
      for (int step = 0; step < stepCount; step += 1) {
        await _sendOnBoth(random, pair);
        _expectSameConversations(pair);
      }
    }
  });

  test('${_typePrefix}_find_conversation_property_missing_runs_are_'
      'refused_by_both', () async {
    final Random random = seededRandom(66203);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await _sendOnBoth(random, pair);
      }
      final RunId missing = randomMissingChatRunId(random);

      expect(
        () => pair.fake.findConversation(missing),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        () => pair.nodeBacked.findConversation(missing),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
