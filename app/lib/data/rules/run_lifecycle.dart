import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';

const String oneAgentStepName = 'agent';
const String _baseBranch = 'main';

const Set<RunStatus> _activeRunStatuses = <RunStatus>{
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
};

const Set<RunStatus> _retryableRunStatuses = <RunStatus>{
  RunStatus.failed,
  RunStatus.cancelled,
};

const Set<StepStatus> _finishedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
};

bool isRunActive(Run run) => _activeRunStatuses.contains(run.status);

DeviceId? _pinnedRunner(RunnerTarget target) {
  if (target is SpecificRunner) {
    return target.deviceId;
  }
  return null;
}

List<RunStep> _planSteps(Task task, Workflow? workflow) {
  if (workflow == null) {
    return <RunStep>[
      RunStep(
        name: oneAgentStepName,
        agentId: null,
        runner: _pinnedRunner(task.runsOn),
        status: StepStatus.waiting,
        startedAt: null,
        finishedAt: null,
        result: null,
        outcome: null,
        loopSource: null,
        earlierRounds: const <EarlierRound>[],
      ),
    ];
  }

  return <RunStep>[
    for (final WorkflowAgent agent in workflow.agents)
      RunStep(
        name: agent.name,
        agentId: agent.id,
        runner: _pinnedRunner(agent.runsOn),
        status: StepStatus.waiting,
        startedAt: null,
        finishedAt: null,
        result: null,
        outcome: null,
        loopSource: null,
        earlierRounds: const <EarlierRound>[],
      ),
  ];
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
        RunStep(
          name: step.name,
          agentId: step.agentId,
          runner: step.runner,
          status: StepStatus.running,
          startedAt: at,
          finishedAt: null,
          result: null,
          outcome: null,
          loopSource: null,
          earlierRounds: const <EarlierRound>[],
        ),
      );
    } else {
      started.add(
        RunStep(
          name: step.name,
          agentId: step.agentId,
          runner: step.runner,
          status: StepStatus.waiting,
          startedAt: null,
          finishedAt: null,
          result: null,
          outcome: null,
          loopSource: null,
          earlierRounds: const <EarlierRound>[],
        ),
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

RunStep _skipStep(RunStep step, DateTime at) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: StepStatus.skipped,
    startedAt: step.startedAt,
    finishedAt: at,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

Run buildCancelledRun(Run run, DateTime at) {
  if (!isRunActive(run)) {
    throw StateError('Run ${run.number} is not active');
  }

  final List<RunStep> steps = <RunStep>[];
  for (final RunStep step in run.steps) {
    if (_finishedStepStatuses.contains(step.status)) {
      steps.add(step);
    } else {
      steps.add(_skipStep(step, at));
    }
  }

  return run.withProgress(
    nextStatus: RunStatus.cancelled,
    nextSteps: steps,
    nextFinishedAt: at,
  );
}

Run buildRetriedRun({
  required Run run,
  required RunId runId,
  required int number,
  required DeviceId startedBy,
  required DateTime at,
}) {
  if (!_retryableRunStatuses.contains(run.status)) {
    throw StateError('Run ${run.number} cannot be retried');
  }

  final List<RunStep> steps = _startFirstUnfinishedStep(run.steps, at);

  return Run(
    id: runId,
    taskId: run.taskId,
    number: number,
    status: RunStatus.running,
    steps: steps,
    log: const <LogLine>[],
    chat: const <ChatMessage>[],
    failure: null,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: startedBy,
    startedAt: at,
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: const <RunNote>[],
  );
}
