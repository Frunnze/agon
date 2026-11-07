import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/agent_kind_label.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';

const String _baseBranch = 'main';

const Set<RunStatus> _retryableRunStatuses = <RunStatus>{
  RunStatus.failed,
  RunStatus.cancelled,
};

bool isRunActive(Run run) => !isRunFinished(run.status);

DeviceId? _pinnedRunner(RunnerTarget target) {
  if (target is SpecificRunner) {
    return target.deviceId;
  }
  return null;
}

RunStep _planWaitingStep({
  required String name,
  required WorkflowAgentId? agentId,
  required RunnerTarget runsOn,
}) {
  return RunStep(
    name: name,
    agentId: agentId,
    runner: _pinnedRunner(runsOn),
    status: StepStatus.waiting,
    startedAt: null,
    finishedAt: null,
    result: null,
    outcome: null,
    loopSource: null,
    earlierRounds: const <EarlierRound>[],
  );
}

RunStep _planOneAgentStep(Task task) {
  final TaskDoer doer = task.doer;
  if (doer is! OneAgentDoer) {
    throw ArgumentError.value(task.id.value, 'task', 'Needs its workflow');
  }

  return _planWaitingStep(
    name: labelAgentKind(doer.agent),
    agentId: null,
    runsOn: task.runsOn,
  );
}

List<RunStep> _planSteps(Task task, Workflow? workflow) {
  if (workflow == null) {
    return <RunStep>[_planOneAgentStep(task)];
  }

  return <RunStep>[
    for (final WorkflowAgent agent in workflow.agents)
      _planWaitingStep(
        name: agent.name,
        agentId: agent.id,
        runsOn: agent.runsOn,
      ),
  ];
}

RunStep _requeueStep(
  RunStep step, {
  required StepStatus status,
  required DateTime? startedAt,
}) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: status,
    startedAt: startedAt,
    finishedAt: null,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

List<RunStep> _startFirstUnfinishedStep(List<RunStep> steps, DateTime at) {
  final List<RunStep> started = <RunStep>[];
  bool hasStartedOne = false;

  for (final RunStep step in steps) {
    if (step.status == StepStatus.done) {
      started.add(step);
    } else if (!hasStartedOne) {
      hasStartedOne = true;
      started.add(
        _requeueStep(step, status: StepStatus.running, startedAt: at),
      );
    } else {
      started.add(
        _requeueStep(step, status: StepStatus.waiting, startedAt: null),
      );
    }
  }

  return started;
}

String describeRunBranch(Task task, int runNumber) {
  if (task.schedule == null) {
    return describeTaskBranch(task.title);
  }
  return describeJobRunBranch(task.title, runNumber);
}

Run createRun({
  required RunId runId,
  required Task task,
  required Workflow? workflow,
  required int number,
  required DeviceId startedBy,
  required DateTime at,
}) {
  final List<RunStep> steps = _startFirstUnfinishedStep(
    _planSteps(task, workflow),
    at,
  );
  final String branch = describeRunBranch(task, number);

  return Run(
    id: runId,
    taskId: task.id,
    number: number,
    status: RunStatus.running,
    steps: steps,
    log: <LogLine>[
      LogLine(
        at: at,
        stepName: steps.first.name,
        text: 'Created worktree $branch from $_baseBranch',
        isError: false,
      ),
    ],
    chat: const <ChatMessage>[],
    failure: null,
    link: RunnerLink.direct,
    linkLostAt: null,
    agentSession: null,
    worktreeBranch: branch,
    startedBy: startedBy,
    startedAt: at,
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: const <RunNote>[],
  );
}

Run buildCancelledRun(Run run, DateTime at) {
  if (!isRunActive(run)) {
    throw StateError('Run ${run.number} is not active');
  }

  return run.withProgress(
    nextStatus: RunStatus.cancelled,
    nextSteps: skipUnfinishedSteps(run.steps, at),
    nextFinishedAt: at,
  );
}

Run buildRetriedRun(Run run, DateTime at) {
  if (!_retryableRunStatuses.contains(run.status)) {
    throw StateError('Run ${run.number} cannot be retried');
  }

  final List<RunStep> steps = _startFirstUnfinishedStep(run.steps, at);

  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: RunStatus.running,
    steps: steps,
    log: run.log,
    chat: run.chat,
    failure: null,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: null,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}
