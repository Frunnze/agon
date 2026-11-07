import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_node_replies.dart' show simulatedOutageMessage;
import 'support/simulated_work_node.dart';

const int _sequenceIterations = 20;
const int _messagesPerRun = 6;
const String _refreshCommandName = 'show_run';
const String _sendCommandName = 'send_chat_message';
const List<String> _refreshFailureTexts = <String>[
  simulatedOutageMessage,
  'the app server answered 503: the app server is busy',
  'run gone-run was not found',
];

final class _RefreshOutage {
  _RefreshOutage({required this.simulated});

  final SimulatedWorkNode simulated;
  String? failureText;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String? plannedFailure = failureText;
    final bool isFailingRefresh =
        plannedFailure != null && command['command'] == _refreshCommandName;
    if (isFailingRefresh) {
      return encodeErrorReply(plannedFailure);
    }
    return simulated.answer(inputJson);
  }
}

typedef _Fixture = ({
  SimulatedWorkNode node,
  _RefreshOutage outage,
  NodeBackedTaskRepository tasks,
  NodeBackedChatRepository chat,
});

_Fixture _buildFixture() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final _RefreshOutage outage = _RefreshOutage(simulated: simulated);
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedTaskRepository tasks = NodeBackedTaskRepository(
    clock: const SystemClock(),
    channel: buildSimulatedChannel(outage.answer),
    workspaceRepository: workspaces,
    livePollInterval: Duration.zero,
    jobRepository: NodeBackedJobRepository(
      channel: buildSimulatedChannel(outage.answer),
      workspaceRepository: workspaces,
      clock: const SystemClock(),
    ),
  );
  final NodeBackedChatRepository chat = NodeBackedChatRepository(
    channel: buildSimulatedChannel(outage.answer),
    runSource: tasks,
    workspaceRepository: workspaces,
  );
  return (node: simulated, outage: outage, tasks: tasks, chat: chat);
}

Future<Run> _startRandomRun(Random random, _Fixture fixture) async {
  final Task task = await fixture.tasks.createTask(randomTaskDraft(random));
  return fixture.tasks.startTask(task.id);
}

void _planRandomRefresh(Random random, _Fixture fixture) {
  fixture.outage.failureText = random.nextBool()
      ? pickOne(random, _refreshFailureTexts)
      : null;
}

String _randomMessageText(Random random) => ' said ${randomText(random)} ';

List<String> _listNodeChatTexts(SimulatedWorkNode simulated, RunId runId) {
  final WireRecord run = simulated.runs[runId.value]!;
  return <String>[
    for (final Object? message in run['chat']! as List<Object?>)
      (message! as WireRecord)['text']! as String,
  ];
}

int _countSends(SimulatedWorkNode simulated) {
  return simulated.receivedCommands
      .where((String name) => name == _sendCommandName)
      .length;
}

List<String> _listShownTexts(_Fixture fixture, RunId runId) {
  final Conversation conversation = fixture.chat.findConversation(runId);
  return <String>[
    for (final ChatMessage message in conversation.messages) message.text,
  ];
}

void main() {
  test(
    'test_send_message_property_failed_refresh_still_returns_the_message',
    () async {
      final Random random = seededRandom(80711);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Fixture fixture = _buildFixture();
        final Run run = await _startRandomRun(random, fixture);

        for (int message = 0; message < _messagesPerRun; message += 1) {
          _planRandomRefresh(random, fixture);
          final String text = _randomMessageText(random);
          final ChatMessage sent = await fixture.chat.sendMessage(
            run.id,
            text,
          );

          expect(sent.author, ChatAuthor.you);
          expect(sent.text, text.trim());
          expect(sent.isError, isFalse);
        }
      }
    },
  );

  test(
    'test_send_message_property_failed_refresh_sends_each_message_once',
    () async {
      final Random random = seededRandom(80712);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Fixture fixture = _buildFixture();
        final Run run = await _startRandomRun(random, fixture);
        final List<String> sentTexts = <String>[];

        for (int message = 0; message < _messagesPerRun; message += 1) {
          _planRandomRefresh(random, fixture);
          final String text = _randomMessageText(random);
          await fixture.chat.sendMessage(run.id, text);
          sentTexts.add(text.trim());

          expect(_listNodeChatTexts(fixture.node, run.id), sentTexts);
          expect(_countSends(fixture.node), sentTexts.length);
        }
      }
    },
  );

  test(
    'test_send_message_property_next_refresh_catches_up_after_a_failure',
    () async {
      final Random random = seededRandom(80713);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Fixture fixture = _buildFixture();
        final Run run = await _startRandomRun(random, fixture);
        final List<String> sentTexts = <String>[];
        final List<String> shownBeforeFailures = _listShownTexts(
          fixture,
          run.id,
        );

        for (int message = 0; message < _messagesPerRun; message += 1) {
          fixture.outage.failureText = pickOne(random, _refreshFailureTexts);
          final String text = _randomMessageText(random);
          await fixture.chat.sendMessage(run.id, text);
          sentTexts.add(text.trim());

          expect(_listShownTexts(fixture, run.id), shownBeforeFailures);
        }

        fixture.outage.failureText = null;
        await fixture.tasks.refreshRun(run.id);
        expect(_listShownTexts(fixture, run.id), sentTexts);
      }
    },
  );
}
