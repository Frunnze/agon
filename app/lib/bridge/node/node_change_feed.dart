import 'dart:async';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

typedef ChangeFeedRecovery = void Function();

final class NodeChangeFeed {
  const NodeChangeFeed({
    required this.channel,
    required this.retryDelay,
    required this.onRecovered,
  });

  final NodeCommandChannel channel;
  final Duration retryDelay;
  final ChangeFeedRecovery onRecovered;

  Stream<ChangeNotification> watchChanges({required int afterSequence}) {
    if (afterSequence < 0) {
      throw ArgumentError.value(
        afterSequence,
        'afterSequence',
        'a sequence is zero or more',
      );
    }

    final StreamController<ChangeNotification> notifications =
        StreamController<ChangeNotification>();
    final _ListenerPause listenerPause = _ListenerPause();
    notifications.onListen = () => unawaited(
      _pollWhileListened(notifications, afterSequence, listenerPause),
    );
    notifications.onResume = listenerPause.end;
    notifications.onCancel = listenerPause.end;
    return notifications.stream;
  }

  Future<void> _pollWhileListened(
    StreamController<ChangeNotification> notifications,
    int afterSequence,
    _ListenerPause listenerPause,
  ) async {
    int nextAfterSequence = afterSequence;
    bool isRecovering = false;
    while (notifications.hasListener) {
      if (notifications.isPaused) {
        await listenerPause.waitForEnd();
        continue;
      }

      final EventsResponse events;
      try {
        events = await channel.execute(
          PollEventsCommand(after: nextAfterSequence),
        );
      } on NodeCommandFailure catch (failure, stackTrace) {
        notifications.addError(failure, stackTrace);
        isRecovering = true;
        await Future<void>.delayed(retryDelay);
        continue;
      } on Object catch (problem, stackTrace) {
        notifications.addError(problem, stackTrace);
        break;
      }

      if (!notifications.hasListener) {
        break;
      }

      if (isRecovering) {
        isRecovering = false;
        onRecovered();
      }
      for (final ChangeNotification notification in events.notifications) {
        notifications.add(notification);
      }
      nextAfterSequence = events.latestSequence;
    }
    await notifications.close();
  }
}

final class _ListenerPause {
  Completer<void>? _ending;

  Future<void> waitForEnd() {
    final Completer<void> ending = Completer<void>();
    _ending = ending;
    return ending.future;
  }

  void end() {
    final Completer<void>? ending = _ending;
    _ending = null;
    ending?.complete();
  }
}
