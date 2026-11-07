import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

const String _taskKind = 'task';
const String _runKind = 'run';
const String _createdTaskPrefix = 'created-task-';
const String _createdRunPrefix = 'created-run-';

final class FakeTaskRepository extends ChangeNotifier
    implements TaskRepository {
  FakeTaskRepository({
    required List<Task> tasks,
    required List<Run> runs,
    required Clock clock,
    required DeviceId currentDeviceId,
    required WorkflowRepository workflowRepository,
  }) : _tasks = List<Task>.unmodifiable(tasks),
       _runs = List<Run>.unmodifiable(runs),
       _clock = clock,
       _currentDeviceId = currentDeviceId,
       _workflowRepository = workflowRepository;

  final Clock _clock;
  final DeviceId _currentDeviceId;
  final WorkflowRepository _workflowRepository;
  List<Task> _tasks;
  List<Run> _runs;
  final Map<RunId, int> _watcherCounts = <RunId, int>{};
  int _createdRecordCount = 0;

  @override
  List<Task> listTasks() {
    return List<Task>.unmodifiable(<Task>[
      for (final Task task in _tasks)
        if (task.schedule == null) task,
    ]);
  }

  List<Task> listTasksAndJobs() => _tasks;

  @override
  Task findTask(TaskId taskId) {
    return findRecord(
      _tasks,
      matches: (Task task) => task.id == taskId,
      kind: _taskKind,
      identifier: taskId.value,
    );
  }

  @override
  List<Run> listRuns(TaskId taskId) {
    final List<Run> runs = _runs
        .where((Run run) => run.taskId == taskId)
        .toList();
    runs.sort((Run first, Run second) => second.number - first.number);

    return List<Run>.unmodifiable(runs);
  }

  @override
  Run findRun(RunId runId) {
    return findRecord(
      _runs,
      matches: (Run run) => run.id == runId,
      kind: _runKind,
      identifier: runId.value,
    );
  }

  @override
  Future<Task> createTask(TaskDraft draft) async {
    final Set<String> takenIdentifiers = <String>{
      for (final Task stored in _tasks) stored.id.value,
    };
    final Task task = Task.fromDraft(
      id: TaskId(_nextFreeIdentifier(_createdTaskPrefix, takenIdentifiers)),
      draft: draft,
      schedule: null,
      status: TaskStatus.toDo,
      createdAt: _clock.now(),
    );

    _tasks = prependRecord(_tasks, task);
    notifyListeners();
    return task;
  }

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) async {
    final Task existing = findTask(taskId);
    final Task updated = Task.fromDraft(
      id: existing.id,
      draft: draft,
      schedule: null,
      status: existing.status,
      createdAt: existing.createdAt,
    );

    _replaceTask(updated);
    notifyListeners();
    return updated;
  }

  @override
  Future<Run> startTask(TaskId taskId) async {
    final Task task = findTask(taskId);
    _refuseSecondActiveRun(task);
    final Workflow? workflow = _findSignedWorkflowFor(task);

    final Run run = createRun(
      runId: _nextRunId(),
      task: task,
      workflow: workflow,
      number: _nextRunNumber(task.id),
      startedBy: _currentDeviceId,
      at: _clock.now(),
    );

    _runs = appendRecord(_runs, run);
    _replaceTask(task.withStatus(TaskStatus.running));
    notifyListeners();
    return run;
  }

  @override
  Future<Run> cancelRun(RunId runId) async {
    final Run cancelled = buildCancelledRun(findRun(runId), _clock.now());

    _replaceRun(cancelled);
    _replaceTask(findTask(cancelled.taskId).withStatus(TaskStatus.toDo));
    notifyListeners();
    return cancelled;
  }

  @override
  Future<Run> retryRun(RunId runId) async {
    final Run stoppedRun = findRun(runId);
    final Task task = findTask(stoppedRun.taskId);
    _refuseSecondActiveRun(task);
    final Run reopened = buildRetriedRun(stoppedRun, _clock.now());

    _replaceRun(reopened);
    _replaceTask(task.withStatus(TaskStatus.running));
    notifyListeners();
    return reopened;
  }

  @override
  Future<void> deleteTask(TaskId taskId) async {
    final Task task = findTask(taskId);
    final bool hasActiveRun = listRuns(taskId).any(isRunActive);
    if (hasActiveRun) {
      final String kind = task.schedule == null ? 'task' : 'job';
      throw StateError('The $kind is running. Cancel its run first.');
    }

    _tasks = removeRecord(
      _tasks,
      matches: (Task stored) => stored.id == taskId,
    );
    _runs = removeRecord(_runs, matches: (Run run) => run.taskId == taskId);
    notifyListeners();
  }

  @override
  void watchRun(RunId runId) {
    _watcherCounts[runId] = (_watcherCounts[runId] ?? 0) + 1;
  }

  @override
  void stopWatchingRun(RunId runId) {
    final int watchers = _watcherCounts[runId] ?? 0;
    if (watchers <= 1) {
      _watcherCounts.remove(runId);
      return;
    }
    _watcherCounts[runId] = watchers - 1;
  }

  bool isWatchingRun(RunId runId) => _watcherCounts.containsKey(runId);

  void storeTask(Task task) {
    final bool isKnown = _tasks.any((Task stored) => stored.id == task.id);
    if (isKnown) {
      _replaceTask(task);
    } else {
      _tasks = prependRecord(_tasks, task);
    }
    notifyListeners();
  }

  void _refuseSecondActiveRun(Task task) {
    final bool hasActiveRun = listRuns(task.id).any(isRunActive);
    if (hasActiveRun) {
      throw StateError('Task ${task.title} is already running');
    }
  }

  Workflow? _findSignedWorkflowFor(Task task) {
    final TaskDoer doer = task.doer;
    if (doer is! WorkflowDoer) {
      return null;
    }

    final Workflow workflow = _workflowRepository.findWorkflow(
      doer.workflowId,
    );
    final WorkflowChange? unsignedChange = _workflowRepository
        .findPendingChange(workflow.id);
    if (workflow.signature == null || unsignedChange != null) {
      throw StateError('Workflow ${workflow.name} is not signed');
    }
    return workflow;
  }

  RunId _nextRunId() {
    final Set<String> takenIdentifiers = <String>{
      for (final Run run in _runs) run.id.value,
    };
    return RunId(_nextFreeIdentifier(_createdRunPrefix, takenIdentifiers));
  }

  String _nextFreeIdentifier(String prefix, Set<String> takenIdentifiers) {
    while (true) {
      _createdRecordCount += 1;
      final String candidate = '$prefix$_createdRecordCount';
      if (!takenIdentifiers.contains(candidate)) {
        return candidate;
      }
    }
  }

  int _nextRunNumber(TaskId taskId) {
    int highestNumber = 0;

    for (final Run run in _runs) {
      if (run.taskId == taskId && run.number > highestNumber) {
        highestNumber = run.number;
      }
    }

    return highestNumber + 1;
  }

  void _replaceTask(Task task) {
    _tasks = replaceRecord(
      _tasks,
      matches: (Task candidate) => candidate.id == task.id,
      replacement: task,
    );
  }

  void _replaceRun(Run run) {
    _runs = replaceRecord(
      _runs,
      matches: (Run candidate) => candidate.id == run.id,
      replacement: run,
    );
  }
}
