import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

enum StepStatus { waiting, running, waitingForApproval, done, failed, skipped }

final class RunStep {
  const RunStep({
    required this.name,
    required this.agentId,
    required this.runner,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
  });

  final String name;
  final WorkflowAgentId? agentId;
  final DeviceId? runner;
  final StepStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  RunStep withStatus(StepStatus nextStatus) {
    return RunStep(
      name: name,
      agentId: agentId,
      runner: runner,
      status: nextStatus,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

enum RunStatus { queued, running, waitingForApproval, failed, cancelled, done }

final class LogLine {
  const LogLine({
    required this.at,
    required this.stepName,
    required this.text,
    required this.isError,
  });

  final DateTime at;
  final String stepName;
  final String text;
  final bool isError;
}

enum ChatAuthor { you, agent, tool }

final class ChatMessage {
  const ChatMessage({
    required this.at,
    required this.author,
    required this.text,
    required this.isError,
    required this.waitingToSend,
  });

  final DateTime at;
  final ChatAuthor author;
  final String text;
  final bool isError;
  final bool waitingToSend;
}

final class RunFailure {
  const RunFailure({
    required this.stepName,
    required this.runner,
    required this.reason,
    required this.retryRunsOnSameRunner,
  });

  final String stepName;
  final DeviceId? runner;
  final String reason;
  final bool retryRunsOnSameRunner;
}

final class Run {
  Run({
    required this.id,
    required this.taskId,
    required this.number,
    required this.status,
    required List<RunStep> steps,
    required List<LogLine> log,
    required List<ChatMessage> chat,
    required this.failure,
    required this.link,
    required this.linkLostAt,
    required this.agentSession,
    required this.worktreeBranch,
    required this.startedBy,
    required this.startedAt,
    required this.finishedAt,
  }) : steps = List<RunStep>.unmodifiable(steps),
       log = List<LogLine>.unmodifiable(log),
       chat = List<ChatMessage>.unmodifiable(chat);

  final RunId id;
  final TaskId taskId;
  final int number;
  final RunStatus status;
  final List<RunStep> steps;
  final List<LogLine> log;
  final List<ChatMessage> chat;
  final RunFailure? failure;
  final RunnerLink link;
  final DateTime? linkLostAt;
  final String? agentSession;
  final String? worktreeBranch;
  final DeviceId startedBy;
  final DateTime startedAt;
  final DateTime? finishedAt;

  Run withProgress({
    required RunStatus nextStatus,
    required List<RunStep> nextSteps,
    required DateTime? nextFinishedAt,
  }) {
    return Run(
      id: id,
      taskId: taskId,
      number: number,
      status: nextStatus,
      steps: nextSteps,
      log: log,
      chat: chat,
      failure: failure,
      link: link,
      linkLostAt: linkLostAt,
      agentSession: agentSession,
      worktreeBranch: worktreeBranch,
      startedBy: startedBy,
      startedAt: startedAt,
      finishedAt: nextFinishedAt,
    );
  }
}
