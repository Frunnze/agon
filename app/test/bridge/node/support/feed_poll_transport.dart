import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

import '../../support/random_account_json.dart';
import '../../support/scripted_node_transport.dart';

typedef FeedPollAnswer = Future<String> Function(String inputJson);

final class FeedPollTransport implements NodeTransport {
  FeedPollTransport({required this.answer});

  final FeedPollAnswer answer;
  int startedPolls = 0;
  int pollsInFlight = 0;
  int largestPollsInFlight = 0;

  void restartInFlightMeasure() => largestPollsInFlight = pollsInFlight;

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    startedPolls += 1;
    pollsInFlight += 1;
    largestPollsInFlight = max(largestPollsInFlight, pollsInFlight);
    await Future<void>.delayed(Duration.zero);

    try {
      return await answer(inputJson);
    } finally {
      pollsInFlight -= 1;
    }
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a feed poll transport is never stopped');
  }
}

String encodeEventsReply(
  List<Object?> notifications, {
  required int latestSequence,
}) {
  return encodeSuccessReply(<String, Object?>{
    'notifications': notifications,
    'latest_sequence': latestSequence,
  });
}

int readPolledAfterSequence(String inputJson) {
  final Map<String, Object?> poll =
      jsonDecode(inputJson) as Map<String, Object?>;
  return poll['after']! as int;
}

Future<String> answerFeedPollQuietly(String inputJson) async {
  final int afterSequence = readPolledAfterSequence(inputJson);
  return encodeEventsReply(<Object?>[], latestSequence: afterSequence);
}

NodeChangeFeed buildZeroRetryFeed(
  FeedPollTransport transport, {
  required ChangeFeedRecovery onRecovered,
}) {
  return NodeChangeFeed(
    channel: NodeCommandChannel(transport: transport),
    retryDelay: Duration.zero,
    onRecovered: onRecovered,
  );
}

void ignoreFeedRecovery() {}

void ignoreFeedProblem(Object problem) {}

Future<void> letFeedTurnsPass(int turns) async {
  for (int turn = 0; turn < turns; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

enum FeedPollKind { failure, notification, quiet }

final class RandomFeedPolls {
  RandomFeedPolls({
    required this.random,
    required this.kinds,
    required this.latestSequence,
  });

  final Random random;
  final List<FeedPollKind> kinds;
  int latestSequence;
  int failures = 0;
  final List<Object?> sentNotifications = <Object?>[];
  final List<int> polledAfter = <int>[];
  final List<int> latestSequenceBeforeEachPoll = <int>[];

  Future<String> answer(String inputJson) async {
    polledAfter.add(readPolledAfterSequence(inputJson));
    latestSequenceBeforeEachPoll.add(latestSequence);

    final FeedPollKind kind = kinds[random.nextInt(kinds.length)];
    if (kind == FeedPollKind.failure) {
      failures += 1;
      return encodeErrorReply('poll $failures failed');
    }

    final List<Object?> notifications = <Object?>[];
    if (kind == FeedPollKind.notification) {
      latestSequence += 1;
      notifications.add(<String, Object?>{
        'sequence': latestSequence,
        'topic': randomChangeTopicJson(random),
      });
    }
    sentNotifications.addAll(notifications);
    return encodeEventsReply(notifications, latestSequence: latestSequence);
  }
}
