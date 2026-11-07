import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

final class RunReadSequence {
  int _latestStarted = 0;
  final Map<RunId, int> _newestAcceptedReads = <RunId, int>{};
  final Map<TaskId, int> _taskRemovals = <TaskId, int>{};

  int startRead() {
    _latestStarted += 1;
    return _latestStarted;
  }

  bool acceptIfNewest(Run run, int read) {
    final int newestAccepted = _newestAcceptedReads[run.id] ?? 0;
    final int taskRemoval = _taskRemovals[run.taskId] ?? 0;
    if (read <= newestAccepted || read <= taskRemoval) {
      return false;
    }
    _newestAcceptedReads[run.id] = read;
    return true;
  }

  void recordTaskRemoval(TaskId taskId) {
    _taskRemovals[taskId] = startRead();
  }
}
