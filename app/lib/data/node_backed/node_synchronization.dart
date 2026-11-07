import 'dart:async';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

const int _sequenceBeforeAnyChange = 0;
const Duration _firstResubscribeDelay = Duration(seconds: 1);
const int _resubscribeDelayGrowth = 2;

typedef AppServerRecheck = Future<void> Function();

final class NodeSynchronization {
  NodeSynchronization({
    required NodeCommandChannel channel,
    required List<NodeSynchronized> repositoriesInLoadOrder,
    required Duration retryDelay,
    required AppServerRecheck recheckAppServer,
  }) : _channel = channel,
       _repositories = List<NodeSynchronized>.unmodifiable(
         repositoriesInLoadOrder,
       ),
       _retryDelay = retryDelay,
       _recheckAppServer = recheckAppServer;

  final NodeCommandChannel _channel;
  final List<NodeSynchronized> _repositories;
  final Duration _retryDelay;
  final AppServerRecheck _recheckAppServer;
  StreamSubscription<void>? _changeSubscription;
  Timer? _pendingResubscription;
  int _lifecycleRequestCount = 0;
  int _lastKnownSequence = _sequenceBeforeAnyChange;
  Duration _resubscribeDelay = _firstResubscribeDelay;

  Future<void> start() async {
    _lifecycleRequestCount += 1;
    final int thisStartRequest = _lifecycleRequestCount;
    await _stopFollowingChanges();

    final node.EventsResponse latest = await executeNodeCommand(
      _channel,
      node.PollEventsCommand(after: _sequenceBeforeAnyChange),
    );
    for (final NodeSynchronized repository in _repositories) {
      await repository.load();
    }

    final bool isSuperseded = thisStartRequest != _lifecycleRequestCount;
    if (isSuperseded) {
      return;
    }

    _lastKnownSequence = latest.latestSequence;
    _followChanges();
  }

  Future<void> stop() async {
    _lifecycleRequestCount += 1;
    await _stopFollowingChanges();
  }

  Future<void> _stopFollowingChanges() async {
    _pendingResubscription?.cancel();
    final Future<void>? cancelling = _changeSubscription?.cancel();
    _changeSubscription = null;
    await cancelling;
  }

  void _followChanges() {
    final NodeChangeFeed feed = NodeChangeFeed(
      channel: _channel,
      retryDelay: _retryDelay,
      onRecovered: _recheckAppServerInBackground,
    );
    _changeSubscription = feed
        .watchChanges(afterSequence: _lastKnownSequence)
        .asyncMap(_applyChange)
        .listen(
          null,
          onError: _handleFeedProblem,
          onDone: _followChangesAfterBackoff,
        );
  }

  void _followChangesAfterBackoff() {
    final Duration delay = _resubscribeDelay < _retryDelay
        ? _resubscribeDelay
        : _retryDelay;

    _resubscribeDelay = delay * _resubscribeDelayGrowth;
    _pendingResubscription = Timer(delay, _followChanges);
  }

  Future<void> _applyChange(node.ChangeNotification notification) async {
    _lastKnownSequence = notification.sequence;

    await Future.wait(<Future<void>>[
      for (final NodeSynchronized repository in _repositories)
        repository.applyChange(notification.topic),
    ]);
  }

  void _handleFeedProblem(Object problem, StackTrace stackTrace) {
    logNodeSynchronizationProblem(problem, stackTrace);
    _recheckAppServerInBackground();
  }

  void _recheckAppServerInBackground() {
    startBackgroundNodeWork(_recheckAppServer);
  }
}
