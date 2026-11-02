import 'dart:developer' as developer;

const String _logName = 'node_synchronization';

void logNodeSynchronizationProblem(Object problem, StackTrace stackTrace) {
  developer.log(
    'Could not follow a node change: $problem',
    name: _logName,
    error: problem,
    stackTrace: stackTrace,
  );
}

void logLiveRunProblem(Object problem, StackTrace stackTrace) {
  developer.log(
    'Could not follow a live run: $problem',
    name: _logName,
    error: problem,
    stackTrace: stackTrace,
  );
}
