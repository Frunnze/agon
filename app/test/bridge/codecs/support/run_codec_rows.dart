import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

import '../../support/random_branching_json.dart';
import '../../support/random_run_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> runConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'log_line',
      buildJson: randomLogLineJson,
      decode: LogLine.fromJson,
    ),
    rebuild: _rebuildLogLine,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'chat_message',
      buildJson: randomChatMessageJson,
      decode: ChatMessage.fromJson,
    ),
    rebuild: _rebuildChatMessage,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'current_step',
      buildJson: randomCurrentStepJson,
      decode: CurrentStep.fromJson,
    ),
    rebuild: _rebuildCurrentStep,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_progress',
      buildJson: randomRunProgressJson,
      decode: RunProgress.fromJson,
    ),
    rebuild: _rebuildRunProgress,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_view',
      buildJson: randomRunViewJson,
      decode: RunView.fromJson,
    ),
    rebuild: _rebuildRunView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'earlier_round',
      buildJson: randomEarlierRoundJson,
      decode: EarlierRound.fromJson,
    ),
    rebuild: _rebuildEarlierRound,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'loop_rounds',
      buildJson: randomLoopRoundsJson,
      decode: LoopRounds.fromJson,
    ),
    rebuild: _rebuildLoopRounds,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_note',
      buildJson: randomRunNoteJson,
      decode: RunNote.fromJson,
    ),
    rebuild: _rebuildRunNote,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_step',
      buildJson: randomRunStepJson,
      decode: RunStep.fromJson,
    ),
    rebuild: _rebuildRunStep,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_failure',
      buildJson: randomRunFailureJson,
      decode: RunFailure.fromJson,
    ),
    rebuild: _rebuildRunFailure,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run',
      buildJson: randomRunJson,
      decode: Run.fromJson,
    ),
    rebuild: _rebuildRun,
  ),
];

JsonEncodable _rebuildLogLine(JsonEncodable value) {
  final LogLine line = value as LogLine;
  return LogLine(
    at: line.at,
    stepName: line.stepName,
    text: line.text,
    isError: line.isError,
  );
}

JsonEncodable _rebuildChatMessage(JsonEncodable value) {
  final ChatMessage message = value as ChatMessage;
  return ChatMessage(
    at: message.at,
    author: message.author,
    text: message.text,
    isError: message.isError,
    waitingToSend: message.waitingToSend,
  );
}

JsonEncodable _rebuildCurrentStep(JsonEncodable value) {
  final CurrentStep step = value as CurrentStep;
  return CurrentStep(
    number: step.number,
    name: step.name,
    runner: step.runner,
    status: step.status,
  );
}

JsonEncodable _rebuildRunProgress(JsonEncodable value) {
  final RunProgress progress = value as RunProgress;
  return RunProgress(
    runId: progress.runId,
    number: progress.number,
    status: progress.status,
    link: progress.link,
    startedAt: progress.startedAt,
    finishedAt: progress.finishedAt,
    stepCount: progress.stepCount,
    currentStep: progress.currentStep,
  );
}

JsonEncodable _rebuildRunView(JsonEncodable value) {
  final RunView view = value as RunView;
  return RunView(
    run: view.run,
    progress: view.progress,
    link: view.link,
    linkLostAt: view.linkLostAt,
  );
}

JsonEncodable _rebuildEarlierRound(JsonEncodable value) {
  final EarlierRound round = value as EarlierRound;
  return EarlierRound(
    status: round.status,
    startedAt: round.startedAt,
    finishedAt: round.finishedAt,
    result: round.result,
    outcome: round.outcome,
  );
}

JsonEncodable _rebuildLoopRounds(JsonEncodable value) {
  final LoopRounds loopRounds = value as LoopRounds;
  return LoopRounds(
    from: loopRounds.from,
    to: loopRounds.to,
    rounds: loopRounds.rounds,
  );
}

JsonEncodable _rebuildRunNote(JsonEncodable value) {
  final RunNote note = value as RunNote;
  return RunNote(at: note.at, text: note.text);
}

JsonEncodable _rebuildRunStep(JsonEncodable value) {
  final RunStep step = value as RunStep;
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: step.status,
    startedAt: step.startedAt,
    finishedAt: step.finishedAt,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

JsonEncodable _rebuildRunFailure(JsonEncodable value) {
  final RunFailure failure = value as RunFailure;
  return RunFailure(
    stepName: failure.stepName,
    runner: failure.runner,
    reason: failure.reason,
    retryRunsOnSameRunner: failure.retryRunsOnSameRunner,
  );
}

JsonEncodable _rebuildRun(JsonEncodable value) {
  final Run run = value as Run;
  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: run.status,
    steps: run.steps,
    log: run.log,
    chat: run.chat,
    failure: run.failure,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}
