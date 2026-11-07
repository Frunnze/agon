import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../../../support/workflow_repositories.dart';

const String seededChatRunPrefix = 'seeded-run-';
const String otherChatRunPrefix = 'other-run-';
const String missingChatRunPrefix = 'missing-run-';
const int otherChatRunCount = 3;
const int _largestConversationCount = 5;
const int _largestMessageCount = 4;
const List<String> blankChatTexts = <String>[
  '',
  ' ',
  '\t',
  '\n',
  '\r\n',
  '\u00a0',
  '\u2028',
  '\u3000',
  ' \t \n ',
];

ChatMessage randomChatMessage(Random random) {
  return ChatMessage(
    at: randomUtcMoment(random),
    author: pickOne(random, ChatAuthor.values),
    text: randomText(random),
    isError: random.nextBool(),
    waitingToSend: random.nextBool(),
  );
}

Conversation randomConversation(Random random, RunId runId) {
  final List<ChatMessage> messages = <ChatMessage>[];
  final int count = random.nextInt(_largestMessageCount);
  for (int i = 0; i < count; i += 1) {
    messages.add(randomChatMessage(random));
  }
  return Conversation(
    runId: runId,
    messages: messages,
    link: pickOne(random, RunnerLink.values),
    linkLostAt: random.nextBool() ? null : randomUtcMoment(random),
    agentActivity: pickOne(random, AgentActivity.values),
  );
}

List<Conversation> randomConversations(Random random) {
  final List<Conversation> conversations = <Conversation>[];
  final int count = random.nextInt(_largestConversationCount);
  for (int i = 0; i < count; i += 1) {
    final RunId runId = RunId('$seededChatRunPrefix$i');
    conversations.add(randomConversation(random, runId));
  }
  return conversations;
}

RunId pickChatRunId(Random random, List<Conversation> seeded) {
  if (seeded.isEmpty || random.nextInt(3) == 0) {
    return RunId('$otherChatRunPrefix${random.nextInt(otherChatRunCount)}');
  }
  return pickOne(random, seeded).runId;
}

RunId randomMissingChatRunId(Random random) {
  return RunId('$missingChatRunPrefix${randomText(random)}');
}

Run randomRunWithId(Random random, RunId runId) {
  final Map<String, Object?> runJson = randomRunJson(random);
  runJson['id'] = runId.value;
  return mapRunFromNode(node.Run.fromJson(runJson));
}

FakeTaskRepository buildTaskRepositoryWithRuns(List<Run> runs) {
  return FakeTaskRepository(
    tasks: const <Task>[],
    runs: runs,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: buildGalleryWorkflowRepository(),
  );
}

FakeTaskRepository buildChatTaskRepository(Random random) {
  final List<Run> runs = <Run>[];
  for (int i = 0; i < otherChatRunCount; i += 1) {
    runs.add(randomRunWithId(random, RunId('$otherChatRunPrefix$i')));
  }
  return buildTaskRepositoryWithRuns(runs);
}

String randomChatMessageText(Random random) {
  final String padding = pickOne(random, blankChatTexts);
  return '$padding${randomText(random)}x$padding';
}

List<String> listChatTexts(List<ChatMessage> messages) {
  final List<String> texts = <String>[];
  for (final ChatMessage message in messages) {
    texts.add(message.text);
  }
  return texts;
}

void expectSameConversation(Conversation actual, Conversation expected) {
  expect(actual.runId, expected.runId);
  expect(actual.messages, orderedEquals(expected.messages));
  expect(actual.link, expected.link);
  expect(actual.linkLostAt, expected.linkLostAt);
  expect(actual.agentActivity, expected.agentActivity);
}
