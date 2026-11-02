import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

abstract interface class TaskRepository implements Listenable {
  List<Task> listTasks();

  Task findTask(TaskId taskId);

  List<Run> listRuns(TaskId taskId);

  Run findRun(RunId runId);

  Future<Task> createTask(TaskDraft draft);

  Future<Task> updateTask(TaskId taskId, TaskDraft draft);

  Future<Run> startTask(TaskId taskId);

  Future<Run> cancelRun(RunId runId);

  Future<Run> retryRun(RunId runId);

  Future<void> deleteTask(TaskId taskId);

  void watchRun(RunId runId);

  void stopWatchingRun(RunId runId);
}
