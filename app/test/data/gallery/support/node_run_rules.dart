import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

const Map<AgentKind, String> nodeOneAgentStepNames = <AgentKind, String>{
  AgentKind.claudeCode: 'claude-code',
  AgentKind.codex: 'codex',
  AgentKind.geminiCli: 'gemini-cli',
};

const Set<RunStatus> finishedRunStatuses = <RunStatus>{
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
};

const Set<StepStatus> finishedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
};

bool _hasStepWithStatus(List<RunStep> steps, StepStatus status) {
  return steps.any((RunStep step) => step.status == status);
}

RunStatus deriveNodeRunStatus(List<RunStep> steps) {
  final bool isAllWaiting = steps.every(
    (RunStep step) => step.status == StepStatus.waiting,
  );
  final bool isAllFinished = steps.every(
    (RunStep step) =>
        step.status == StepStatus.done || step.status == StepStatus.skipped,
  );

  if (_hasStepWithStatus(steps, StepStatus.failed)) {
    return RunStatus.failed;
  }
  if (_hasStepWithStatus(steps, StepStatus.waitingForApproval)) {
    return RunStatus.waitingForApproval;
  }
  if (isAllWaiting) {
    return RunStatus.queued;
  }
  if (isAllFinished) {
    return RunStatus.done;
  }
  return RunStatus.running;
}

TaskStatus findNodeTaskStatus(RunStatus runStatus) {
  switch (runStatus) {
    case RunStatus.queued || RunStatus.running:
      return TaskStatus.running;
    case RunStatus.waitingForApproval:
      return TaskStatus.waitingForApproval;
    case RunStatus.failed:
      return TaskStatus.failed;
    case RunStatus.cancelled:
      return TaskStatus.toDo;
    case RunStatus.done:
      return TaskStatus.done;
  }
}
