import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/run_follow_ups.dart';
import 'package:agent_orchestration/data/rules/run_reports.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

bool _isSameLogLine(LogLine first, LogLine second) {
  return first.at == second.at &&
      first.stepName == second.stepName &&
      first.text == second.text &&
      first.isError == second.isError;
}

bool _isSameChatMessage(ChatMessage first, ChatMessage second) {
  return first.at == second.at &&
      first.author == second.author &&
      first.text == second.text &&
      first.isError == second.isError &&
      first.waitingToSend == second.waitingToSend;
}

List<LogLine> _appendLogLine(List<LogLine> log, LogLine line) {
  for (final LogLine existing in log) {
    if (_isSameLogLine(existing, line)) {
      return log;
    }
  }
  return <LogLine>[...log, line];
}

bool _hasChatMessage(List<ChatMessage> chat, ChatMessage message) {
  return chat.any((ChatMessage existing) {
    return _isSameChatMessage(existing, message);
  });
}

Run _changeStepStatus(Run run, node.StepStatusChanged change, DateTime at) {
  if (!canChangeRunStep(run, change.stepName)) {
    return run;
  }
  return applyStepStatus(
    run: run,
    stepName: change.stepName,
    status: mapStepStatusFromNode(change.status),
    at: at,
  );
}

Run _recordStepResult(Run run, node.StepResultRecorded recorded) {
  if (!canChangeRunStep(run, recorded.stepName)) {
    return run;
  }
  return recordStepResult(
    run: run,
    stepName: recorded.stepName,
    result: recorded.result,
    outcome: recorded.outcome,
  );
}

Run _failStep(Run run, node.RunFailed failed, DateTime at) {
  final RunFailure failure = mapRunFailureFromNode(failed.failure);
  if (!canFailRunStep(run, failure.stepName)) {
    return run;
  }
  return failRunStep(run: run, failure: failure, at: at);
}

Run _wakeForMessage(Run run, ChatMessage message) {
  if (!wakesRunForFollowUp(run, message)) {
    return run;
  }
  return reopenRunForFollowUp(run);
}

Run applyLiveRunView({
  required Run run,
  required node.WatchView view,
  required DateTime at,
}) {
  Run progress = run;
  List<LogLine> log = run.log;
  List<ChatMessage> chat = run.chat;
  String? agentSession = run.agentSession;
  String? worktreeBranch = run.worktreeBranch;

  for (final node.RunEvent event in view.events) {
    switch (event) {
      case node.StepStatusChanged():
        progress = _changeStepStatus(progress, event, at);
      case node.StepResultRecorded():
        progress = _recordStepResult(progress, event);
      case node.RunFailed():
        progress = _failStep(progress, event, at);
      case node.RunFinished():
        progress = finishReportingRunnerSteps(progress, at);
      case node.LogAppended(:final line):
        log = _appendLogLine(log, mapLogLineFromNode(line));
      case node.ChatAppended(:final message):
        final ChatMessage chatMessage = mapChatMessageFromNode(message);
        if (!_hasChatMessage(chat, chatMessage)) {
          progress = _wakeForMessage(progress, chatMessage);
          chat = <ChatMessage>[...chat, chatMessage];
        }
      case node.SessionStarted(:final String session):
        agentSession = session;
      case node.WorktreeCreated(:final String branch):
        worktreeBranch = branch;
      case node.LinkChanged():
        continue;
    }
  }

  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: progress.status,
    steps: progress.steps,
    log: log,
    chat: chat,
    failure: progress.failure,
    link: mapRunnerLinkFromNode(view.link),
    linkLostAt: view.linkLostAt,
    agentSession: agentSession,
    worktreeBranch: worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: progress.finishedAt,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}
