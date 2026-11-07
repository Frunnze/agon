import 'dart:async';

import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

typedef BackgroundNodeWork = Future<void> Function();

void startBackgroundNodeWork(BackgroundNodeWork work) {
  unawaited(_runLoggingNodeFailures(work));
}

Future<void> _runLoggingNodeFailures(BackgroundNodeWork work) async {
  try {
    await work();
  } on Object catch (problem, stackTrace) {
    final bool isNodeFailure =
        problem is StateError || problem is RecordNotFound;
    if (!isNodeFailure) {
      rethrow;
    }
    logNodeSynchronizationProblem(problem, stackTrace);
  }
}
