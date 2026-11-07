import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../../bridge/support/random_moments.dart';
import '../../../../bridge/support/random_typed_values.dart';
import '../../../../support/random_inputs.dart';
import '../../../models/support/random_run_records.dart';

const int _largestRunNumber = 1000;
const int largestNewRecordCount = 5;
const String newRecordMark = '\u0000new';
const Duration oneMicrosecond = Duration(microseconds: 1);

typedef ShownRecord = List<Object?>;

Run buildLiveRun(
  Random random, {
  required List<RunStep> steps,
  required List<LogLine> log,
  required List<ChatMessage> chat,
}) {
  return Run(
    id: randomRunId(random),
    taskId: randomTaskId(random),
    number: random.nextInt(_largestRunNumber),
    status: pickOne(random, RunStatus.values),
    steps: steps,
    log: log,
    chat: chat,
    failure: random.nextBool() ? null : randomRunFailure(random),
    link: pickOne(random, RunnerLink.values),
    linkLostAt: randomOptionalMoment(random),
    agentSession: randomOptionalHostileText(random),
    worktreeBranch: randomOptionalHostileText(random),
    startedBy: randomDeviceId(random),
    startedAt: randomPreciseMoment(random),
    finishedAt: randomOptionalMoment(random),
    loopRounds: randomRecordsOf(random, randomLoopRounds),
    notes: randomRecordsOf(random, randomRunNote),
  );
}

Run randomLiveRun(Random random) {
  return buildLiveRun(
    random,
    steps: randomRecordsOf(random, randomRunStep),
    log: randomRecordsOf(random, randomLogLine),
    chat: randomRecordsOf(random, randomChatMessage),
  );
}

node.WatchView buildLiveView(List<node.RunEvent> events) {
  return node.WatchView(
    link: node.RunnerLink.direct,
    linkLostAt: null,
    problem: null,
    events: events,
  );
}

node.LogAppended buildLogEvent(LogLine line) {
  return node.LogAppended(
    line: node.LogLine(
      at: line.at,
      stepName: line.stepName,
      text: line.text,
      isError: line.isError,
    ),
  );
}

node.ChatAppended buildChatEvent(ChatMessage message) {
  return node.ChatAppended(
    message: node.ChatMessage(
      at: message.at,
      author: node.ChatAuthor.values.byName(message.author.name),
      text: message.text,
      isError: message.isError,
      waitingToSend: message.waitingToSend,
    ),
  );
}

List<ShownRecord> describeLog(List<LogLine> log) {
  return <ShownRecord>[
    for (final LogLine line in log)
      <Object?>[line.at, line.stepName, line.text, line.isError],
  ];
}

List<ShownRecord> describeChat(List<ChatMessage> chat) {
  return <ShownRecord>[
    for (final ChatMessage message in chat)
      <Object?>[
        message.at,
        message.author,
        message.text,
        message.isError,
        message.waitingToSend,
      ],
  ];
}

ShownRecord describeStepBesidesStatus(RunStep step) {
  final List<ShownRecord> earlierRounds = <ShownRecord>[
    for (final EarlierRound round in step.earlierRounds)
      <Object?>[
        round.status,
        round.startedAt,
        round.finishedAt,
        round.result,
        round.outcome,
      ],
  ];
  return <Object?>[
    step.name,
    step.agentId,
    step.runner,
    step.startedAt,
    step.finishedAt,
    step.result,
    step.outcome,
    step.loopSource,
    earlierRounds,
  ];
}

Run randomLiveRunWithRecords(Random random) {
  return buildLiveRun(
    random,
    steps: const <RunStep>[],
    log: <LogLine>[
      randomLogLine(random),
      ...randomRecordsOf(random, randomLogLine),
    ],
    chat: <ChatMessage>[
      randomChatMessage(random),
      ...randomRecordsOf(random, randomChatMessage),
    ],
  );
}
