import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

final class RetryRefusingTaskRepository implements TaskRepository {
  RetryRefusingTaskRepository({
    required this.stored,
    required this.refusal,
    required this.refusalArrival,
  });

  final TaskRepository stored;
  final Object refusal;
  final Future<void> refusalArrival;
  int retryAttempts = 0;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Task> listTasks() => stored.listTasks();

  @override
  Task findTask(TaskId taskId) => stored.findTask(taskId);

  @override
  List<Run> listRuns(TaskId taskId) => stored.listRuns(taskId);

  @override
  Run findRun(RunId runId) => stored.findRun(runId);

  @override
  Future<Task> createTask(TaskDraft draft) => stored.createTask(draft);

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) {
    return stored.updateTask(taskId, draft);
  }

  @override
  Future<Run> startTask(TaskId taskId) => stored.startTask(taskId);

  @override
  Future<Run> cancelRun(RunId runId) => stored.cancelRun(runId);

  @override
  Future<Run> retryRun(RunId runId) async {
    retryAttempts += 1;
    await refusalArrival;
    return Future<Run>.error(refusal);
  }

  @override
  Future<void> deleteTask(TaskId taskId) => stored.deleteTask(taskId);

  @override
  void watchRun(RunId runId) => stored.watchRun(runId);

  @override
  void stopWatchingRun(RunId runId) => stored.stopWatchingRun(runId);
}
