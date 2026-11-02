import 'dart:async';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/live_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

typedef LiveRunViewHandler = void Function(RunId runId, node.WatchView view);

final class NodeRunWatches {
  NodeRunWatches({
    required NodeCommandChannel channel,
    required Duration pollInterval,
    required LiveRunViewHandler onView,
  }) : _channel = channel,
       _pollInterval = pollInterval,
       _onView = onView;

  final NodeCommandChannel _channel;
  final Duration _pollInterval;
  final LiveRunViewHandler _onView;
  final Map<RunId, int> _watcherCounts = <RunId, int>{};

  void watch(RunId runId) {
    final int watchers = _watcherCounts[runId] ?? 0;
    _watcherCounts[runId] = watchers + 1;
    if (watchers == 0) {
      unawaited(_followRun(runId));
    }
  }

  void stopWatching(RunId runId) {
    final int watchers = _watcherCounts[runId] ?? 0;
    if (watchers > 1) {
      _watcherCounts[runId] = watchers - 1;
      return;
    }
    _watcherCounts.remove(runId);
    unawaited(_sendStop(runId));
  }

  void stopAll() {
    _watcherCounts.clear();
  }

  Future<void> _followRun(RunId runId) async {
    while (_watcherCounts.containsKey(runId)) {
      final node.WatchView? view = await _readLiveView(runId);
      if (view != null && _watcherCounts.containsKey(runId)) {
        _onView(runId, view);
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<node.WatchView?> _readLiveView(RunId runId) async {
    try {
      return await _channel.execute(node.WatchRunCommand(runId: runId));
    } on NodeCommandFailure catch (failure, stackTrace) {
      logLiveRunProblem(failure, stackTrace);
      return null;
    }
  }

  Future<void> _sendStop(RunId runId) async {
    try {
      await _channel.execute(node.StopWatchingRunCommand(runId: runId));
    } on NodeCommandFailure catch (failure, stackTrace) {
      logLiveRunProblem(failure, stackTrace);
    }
  }
}
