import 'dart:async';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

const int _sequenceBeforeAnyChange = 0;

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

  Future<void> start() async {
    final node.EventsResponse latest = await executeNodeCommand(
      _channel,
      node.PollEventsCommand(after: _sequenceBeforeAnyChange),
    );
    for (final NodeSynchronized repository in _repositories) {
      await repository.load();
    }

    final NodeChangeFeed feed = NodeChangeFeed(
      channel: _channel,
      retryDelay: _retryDelay,
      onRecovered: _recheckAppServerInBackground,
    );
    _changeSubscription = feed
        .watchChanges(afterSequence: latest.latestSequence)
        .asyncMap(_applyChange)
        .listen(null, onError: _handleFeedProblem);
  }

  Future<void> stop() async {
    await _changeSubscription?.cancel();
    _changeSubscription = null;
  }

  Future<void> _applyChange(node.ChangeNotification notification) async {
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
