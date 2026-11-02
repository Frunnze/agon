import 'dart:async';

import 'package:agent_orchestration/data/node_backed.dart';

typedef BackgroundNodeWork = Future<void> Function();

void startBackgroundNodeWork(BackgroundNodeWork work) {
  unawaited(_runLoggingNodeFailures(work));
}

Future<void> _runLoggingNodeFailures(BackgroundNodeWork work) async {
  try {
    await work();
  } on Object catch (problem, stackTrace) {
    if (problem is! StateError) {
      rethrow;
    }
    logNodeSynchronizationProblem(problem, stackTrace);
  }
}
