import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';

import 'live_run_views.dart';

node.EarlierRound buildNodeEarlierRound(EarlierRound round) {
  return node.EarlierRound(
    status: node.StepStatus.values.byName(round.status.name),
    startedAt: round.startedAt,
    finishedAt: round.finishedAt,
    result: round.result,
    outcome: round.outcome,
  );
}

node.RunStep buildNodeRunStep(RunStep step) {
  return node.RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: node.StepStatus.values.byName(step.status.name),
    startedAt: step.startedAt,
    finishedAt: step.finishedAt,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: <node.EarlierRound>[
      for (final EarlierRound round in step.earlierRounds)
        buildNodeEarlierRound(round),
    ],
  );
}

node.LoopRounds buildNodeLoopRounds(LoopRounds loopRounds) {
  return node.LoopRounds(
    from: loopRounds.from,
    to: loopRounds.to,
    rounds: loopRounds.rounds,
  );
}

node.RunNote buildNodeRunNote(RunNote note) {
  return node.RunNote(at: note.at, text: note.text);
}

node.LogLine buildNodeLogLine(LogLine line) {
  return node.LogLine(
    at: line.at,
    stepName: line.stepName,
    text: line.text,
    isError: line.isError,
  );
}

node.ChatMessage buildNodeChatMessage(ChatMessage message) {
  return node.ChatMessage(
    at: message.at,
    author: node.ChatAuthor.values.byName(message.author.name),
    text: message.text,
    isError: message.isError,
    waitingToSend: message.waitingToSend,
  );
}

node.RunFailure buildNodeRunFailure(RunFailure failure) {
  return node.RunFailure(
    stepName: failure.stepName,
    runner: failure.runner,
    reason: failure.reason,
    retryRunsOnSameRunner: failure.retryRunsOnSameRunner,
  );
}

node.Run buildNodeRun(Run run) {
  final RunFailure? failure = run.failure;
  final node.RunFailure? nodeFailure = failure == null
      ? null
      : buildNodeRunFailure(failure);

  return node.Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: node.RunStatus.values.byName(run.status.name),
    steps: <node.RunStep>[
      for (final RunStep step in run.steps) buildNodeRunStep(step),
    ],
    log: <node.LogLine>[
      for (final LogLine line in run.log) buildNodeLogLine(line),
    ],
    chat: <node.ChatMessage>[
      for (final ChatMessage message in run.chat)
        buildNodeChatMessage(message),
    ],
    failure: nodeFailure,
    link: node.RunnerLink.values.byName(run.link.name),
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
    loopRounds: <node.LoopRounds>[
      for (final LoopRounds loopRounds in run.loopRounds)
        buildNodeLoopRounds(loopRounds),
    ],
    notes: <node.RunNote>[
      for (final RunNote note in run.notes) buildNodeRunNote(note),
    ],
  );
}

ShownRecord describeEarlierRound(EarlierRound round) {
  return <Object?>[
    round.status,
    round.startedAt,
    round.finishedAt,
    round.result,
    round.outcome,
  ];
}

ShownRecord describeWholeStep(RunStep step) {
  return <Object?>[step.status, ...describeStepBesidesStatus(step)];
}

ShownRecord describeLoopRounds(LoopRounds loopRounds) {
  return <Object?>[loopRounds.from, loopRounds.to, loopRounds.rounds];
}

ShownRecord describeRunNote(RunNote note) => <Object?>[note.at, note.text];

ShownRecord describeRunFailure(RunFailure failure) {
  return <Object?>[
    failure.stepName,
    failure.runner,
    failure.reason,
    failure.retryRunsOnSameRunner,
  ];
}

ShownRecord describeRunBesidesLink(Run run) {
  final RunFailure? failure = run.failure;
  return <Object?>[
    run.id,
    run.taskId,
    run.number,
    run.status,
    <ShownRecord>[
      for (final RunStep step in run.steps) describeWholeStep(step),
    ],
    describeLog(run.log),
    describeChat(run.chat),
    if (failure == null) null else describeRunFailure(failure),
    run.agentSession,
    run.worktreeBranch,
    run.startedBy,
    run.startedAt,
    run.finishedAt,
    <ShownRecord>[
      for (final LoopRounds loopRounds in run.loopRounds)
        describeLoopRounds(loopRounds),
    ],
    <ShownRecord>[for (final RunNote note in run.notes) describeRunNote(note)],
  ];
}

ShownRecord describeEveryRunField(Run run) {
  return <Object?>[...describeRunBesidesLink(run), run.link, run.linkLostAt];
}
