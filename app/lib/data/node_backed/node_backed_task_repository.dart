import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/run_commands.dart' as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed/run_read_sequence.dart';
import 'package:agent_orchestration/data/node_backed/task_node_reads.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

const String _taskKind = 'task';
const String _runKind = 'run';

final class NodeBackedTaskRepository extends ChangeNotifier
    implements TaskRepository, RunSource, NodeSynchronized {
  NodeBackedTaskRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
    required Duration livePollInterval,
    required JobRepository jobRepository,
    required Clock clock,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository,
       _jobRepository = jobRepository,
       _clock = clock {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
    _liveWatches = NodeRunWatches(
      channel: channel,
      pollInterval: livePollInterval,
      onView: _applyLiveView,
    );
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final JobRepository _jobRepository;
  final Clock _clock;
  late final NodeRunWatches _liveWatches;
  final FetchSequence _taskFetches = FetchSequence();
  final RunReadSequence _runReads = RunReadSequence();
  List<Task> _tasks = const <Task>[];
  Map<RunId, Run> _runs = const <RunId, Run>{};

  @override
  List<Task> listTasks() => _tasks;

  @override
  Task findTask(TaskId taskId) {
    final List<Task> tasksAndJobs = <Task>[
      ..._tasks,
      ..._jobRepository.listJobs(),
    ];
    return findRecord(
      tasksAndJobs,
      matches: (Task task) => task.id == taskId,
      kind: _taskKind,
      identifier: taskId.value,
    );
  }

  @override
  List<Run> listRuns(TaskId taskId) {
    final List<Run> runs = <Run>[
      for (final Run run in _runs.values)
        if (run.taskId == taskId) run,
    ];
    runs.sort((Run first, Run second) => second.number - first.number);
    return List<Run>.unmodifiable(runs);
  }

  @override
  Run findRun(RunId runId) {
    final Run? run = _runs[runId];
    if (run == null) {
      throw RecordNotFound(kind: _runKind, identifier: runId.value);
    }
    return run;
  }

  @override
  Future<void> load() async {
    final int fetch = _taskFetches.startFetch();
    final int runRead = _runReads.startRead();
    final List<Task> tasks = await fetchCurrentWorkspaceTasks(
      channel: _channel,
      workspaceRepository: _workspaceRepository,
    );
    final List<Future<List<Run>>> runFetches = <Future<List<Run>>>[
      for (final Task task in tasks)
        fetchTaskRuns(channel: _channel, taskId: task.id),
    ];
    final List<List<Run>> runsOfEachTask = await Future.wait(runFetches);

    for (final List<Run> taskRuns in runsOfEachTask) {
      for (final Run run in taskRuns) {
        _storeRunIfNewest(run, runRead);
      }
    }

    if (_taskFetches.acceptIfNewest(fetch)) {
      _tasks = tasks;
    }
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    switch (topic) {
      case node.AreaChanged(area: node.ChangeArea.tasks):
        await load();
      case node.RunChanged(:final RunId runId):
        await _refreshRunAndTasks(runId);
      case node.AreaChanged():
        return;
    }
  }

  @override
  Future<Task> createTask(TaskDraft draft) async {
    final node.CreateTaskCommand command = node.CreateTaskCommand(
      task: mapTaskDraftToNode(
        draft: draft,
        workspaceId: _workspaceRepository.currentWorkspace().id,
      ),
      start: node.TaskStart.later,
    );
    final node.Task created = await executeNodeCommand(_channel, command);

    await _reloadTasks();
    return mapTaskFromNode(created);
  }

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) async {
    final node.UpdateTaskCommand command = node.UpdateTaskCommand(
      taskId: taskId,
      task: mapTaskDraftToNode(
        draft: draft,
        workspaceId: _workspaceRepository.currentWorkspace().id,
      ),
    );
    final node.Task updated = await executeNodeCommand(_channel, command);

    await _reloadTasks();
    return mapTaskFromNode(updated);
  }

  @override
  Future<Run> startTask(TaskId taskId) async {
    final int runRead = _runReads.startRead();
    final node.Run started = await executeNodeCommand(
      _channel,
      node.StartTaskCommand(taskId: taskId),
    );
    final Run run = mapRunFromNode(started);

    _storeRunIfNewest(run, runRead);
    await _reloadTasks();
    return run;
  }

  @override
  Future<Run> cancelRun(RunId runId) async {
    await executeNodeCommand(_channel, node.CancelRunCommand(runId: runId));
    return _refreshRunAndTasks(runId);
  }

  @override
  Future<Run> retryRun(RunId runId) async {
    await executeNodeCommand(_channel, node.RetryRunCommand(runId: runId));
    return _refreshRunAndTasks(runId);
  }

  @override
  Future<void> deleteTask(TaskId taskId) async {
    await executeNodeCommand(_channel, node.DeleteTaskCommand(taskId: taskId));

    _forgetRunsOfTask(taskId);
    notifyListeners();
    await _reloadTasks();
  }

  @override
  Future<Run> refreshRun(RunId runId) async {
    final int runRead = _runReads.startRead();
    final node.RunView view = await executeNodeCommand(
      _channel,
      node.ShowRunCommand(runId: runId),
    );

    _storeRunIfNewest(mapRunViewFromNode(view), runRead);
    notifyListeners();
    return findRun(runId);
  }

  @override
  void watchRun(RunId runId) {
    _liveWatches.watch(runId);
  }

  @override
  void stopWatchingRun(RunId runId) {
    _liveWatches.stopWatching(runId);
  }

  @override
  void dispose() {
    _liveWatches.stopAll();
    _workspaceRepository.removeListener(_loadAfterWorkspaceChange);
    super.dispose();
  }

  void _applyLiveView(RunId runId, node.WatchView view) {
    final Run? run = _runs[runId];
    if (run == null) {
      return;
    }
    final DateTime receivedAt = _clock.now().toUtc();
    _storeRun(applyLiveRunView(run: run, view: view, at: receivedAt));
    notifyListeners();
  }

  void _loadAfterWorkspaceChange() {
    startBackgroundNodeWork(load);
  }

  Future<Run> _refreshRunAndTasks(RunId runId) async {
    final Run run = await refreshRun(runId);
    await _reloadTasks();
    return run;
  }

  Future<void> _reloadTasks() async {
    final int fetch = _taskFetches.startFetch();
    final List<Task> tasks = await fetchCurrentWorkspaceTasks(
      channel: _channel,
      workspaceRepository: _workspaceRepository,
    );
    if (!_taskFetches.acceptIfNewest(fetch)) {
      return;
    }

    _tasks = tasks;
    notifyListeners();
  }

  void _storeRun(Run run) {
    _runs = Map<RunId, Run>.unmodifiable(<RunId, Run>{..._runs, run.id: run});
  }

  void _storeRunIfNewest(Run run, int read) {
    if (_runReads.acceptIfNewest(run, read)) {
      _storeRun(run);
    }
  }

  void _forgetRunsOfTask(TaskId taskId) {
    _runReads.recordTaskRemoval(taskId);
    _runs = Map<RunId, Run>.unmodifiable(<RunId, Run>{
      for (final Run run in _runs.values)
        if (run.taskId != taskId) run.id: run,
    });
  }
}
