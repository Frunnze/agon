import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

StepStatus mapStepStatusFromNode(node.StepStatus status) {
  return switch (status) {
    node.StepStatus.waiting => StepStatus.waiting,
    node.StepStatus.running => StepStatus.running,
    node.StepStatus.waitingForApproval => StepStatus.waitingForApproval,
    node.StepStatus.waitingForPerson => StepStatus.waitingForPerson,
    node.StepStatus.done => StepStatus.done,
    node.StepStatus.failed => StepStatus.failed,
    node.StepStatus.skipped => StepStatus.skipped,
  };
}

RunStatus mapRunStatusFromNode(node.RunStatus status) {
  return switch (status) {
    node.RunStatus.queued => RunStatus.queued,
    node.RunStatus.running => RunStatus.running,
    node.RunStatus.waitingForApproval => RunStatus.waitingForApproval,
    node.RunStatus.failed => RunStatus.failed,
    node.RunStatus.cancelled => RunStatus.cancelled,
    node.RunStatus.done => RunStatus.done,
  };
}

ChatAuthor mapChatAuthorFromNode(node.ChatAuthor author) {
  return switch (author) {
    node.ChatAuthor.you => ChatAuthor.you,
    node.ChatAuthor.agent => ChatAuthor.agent,
    node.ChatAuthor.tool => ChatAuthor.tool,
  };
}

EarlierRound mapEarlierRoundFromNode(node.EarlierRound round) {
  return EarlierRound(
    status: mapStepStatusFromNode(round.status),
    startedAt: round.startedAt,
    finishedAt: round.finishedAt,
    result: round.result,
    outcome: round.outcome,
  );
}

RunStep mapRunStepFromNode(node.RunStep step) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: mapStepStatusFromNode(step.status),
    startedAt: step.startedAt,
    finishedAt: step.finishedAt,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: <EarlierRound>[
      for (final node.EarlierRound round in step.earlierRounds)
        mapEarlierRoundFromNode(round),
    ],
  );
}

LoopRounds mapLoopRoundsFromNode(node.LoopRounds loopRounds) {
  return LoopRounds(
    from: loopRounds.from,
    to: loopRounds.to,
    rounds: loopRounds.rounds,
  );
}

RunNote mapRunNoteFromNode(node.RunNote note) {
  return RunNote(at: note.at, text: note.text);
}

LogLine mapLogLineFromNode(node.LogLine line) {
  return LogLine(
    at: line.at,
    stepName: line.stepName,
    text: line.text,
    isError: line.isError,
  );
}

ChatMessage mapChatMessageFromNode(node.ChatMessage message) {
  return ChatMessage(
    at: message.at,
    author: mapChatAuthorFromNode(message.author),
    text: message.text,
    isError: message.isError,
    waitingToSend: message.waitingToSend,
  );
}

RunFailure mapRunFailureFromNode(node.RunFailure failure) {
  return RunFailure(
    stepName: failure.stepName,
    runner: failure.runner,
    reason: failure.reason,
    retryRunsOnSameRunner: failure.retryRunsOnSameRunner,
  );
}

Run mapRunFromNode(node.Run run) {
  final node.RunFailure? wireFailure = run.failure;
  final RunFailure? failure = wireFailure == null
      ? null
      : mapRunFailureFromNode(wireFailure);

  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: mapRunStatusFromNode(run.status),
    steps: <RunStep>[
      for (final node.RunStep step in run.steps) mapRunStepFromNode(step),
    ],
    log: <LogLine>[
      for (final node.LogLine line in run.log) mapLogLineFromNode(line),
    ],
    chat: <ChatMessage>[
      for (final node.ChatMessage message in run.chat)
        mapChatMessageFromNode(message),
    ],
    failure: failure,
    link: mapRunnerLinkFromNode(run.link),
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
    loopRounds: <LoopRounds>[
      for (final node.LoopRounds loopRounds in run.loopRounds)
        mapLoopRoundsFromNode(loopRounds),
    ],
    notes: <RunNote>[
      for (final node.RunNote note in run.notes) mapRunNoteFromNode(note),
    ],
  );
}

Run mapRunViewFromNode(node.RunView view) {
  final Run run = mapRunFromNode(view.run);
  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: run.status,
    steps: run.steps,
    log: run.log,
    chat: run.chat,
    failure: run.failure,
    link: mapRunnerLinkFromNode(view.link),
    linkLostAt: view.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}
