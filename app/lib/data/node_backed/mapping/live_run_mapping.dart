import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

bool _isSameLogLine(LogLine first, LogLine second) {
  return first.at == second.at &&
      first.stepName == second.stepName &&
      first.text == second.text;
}

bool _isSameChatMessage(ChatMessage first, ChatMessage second) {
  return first.at == second.at &&
      first.author == second.author &&
      first.text == second.text;
}

List<LogLine> _appendLogLine(List<LogLine> log, LogLine line) {
  for (final LogLine existing in log) {
    if (_isSameLogLine(existing, line)) {
      return log;
    }
  }
  return <LogLine>[...log, line];
}

List<ChatMessage> _appendChatMessage(
  List<ChatMessage> chat,
  ChatMessage message,
) {
  for (final ChatMessage existing in chat) {
    if (_isSameChatMessage(existing, message)) {
      return chat;
    }
  }
  return <ChatMessage>[...chat, message];
}

List<RunStep> _changeStepStatus(
  List<RunStep> steps,
  node.StepStatusChanged change,
) {
  final StepStatus status = mapStepStatusFromNode(change.status);
  return <RunStep>[
    for (final RunStep step in steps)
      if (step.name == change.stepName) step.withStatus(status) else step,
  ];
}

Run applyLiveRunView({required Run run, required node.WatchView view}) {
  List<RunStep> steps = run.steps;
  List<LogLine> log = run.log;
  List<ChatMessage> chat = run.chat;
  RunFailure? failure = run.failure;
  String? agentSession = run.agentSession;
  String? worktreeBranch = run.worktreeBranch;

  for (final node.RunEvent event in view.events) {
    switch (event) {
      case node.StepStatusChanged():
        steps = _changeStepStatus(steps, event);
      case node.LogAppended(:final line):
        log = _appendLogLine(log, mapLogLineFromNode(line));
      case node.ChatAppended(:final message):
        chat = _appendChatMessage(chat, mapChatMessageFromNode(message));
      case node.SessionStarted(:final String session):
        agentSession = session;
      case node.WorktreeCreated(:final String branch):
        worktreeBranch = branch;
      case node.RunFailed(failure: final failedWith):
        failure = mapRunFailureFromNode(failedWith);
      case node.LinkChanged():
      case node.StepResultRecorded():
      case node.RunFinished():
        continue;
    }
  }

  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: run.status,
    steps: steps,
    log: log,
    chat: chat,
    failure: failure,
    link: mapRunnerLinkFromNode(view.link),
    linkLostAt: view.linkLostAt,
    agentSession: agentSession,
    worktreeBranch: worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
  );
}
