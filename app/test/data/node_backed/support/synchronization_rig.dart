import 'dart:async';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/node/support/feed_poll_transport.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';

const int _startPollSequence = 0;
const int _largestRepositoryCount = 4;
const int _largestSequenceStep = 5;
const int _answerPatienceTurns = 200;
const int _settlingTurns = 12;

typedef ScriptedFeedAnswer = String Function();

final class RecordingSynchronizedRepository implements NodeSynchronized {
  bool isRefusingChanges = false;
  Completer<void>? heldChange;
  final List<Object?> appliedTopics = <Object?>[];

  @override
  Future<void> load() async {}

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    appliedTopics.add(topic.toJson());
    final Completer<void>? held = heldChange;
    if (held != null) {
      await held.future;
    }
    if (isRefusingChanges) {
      throw StateError('the repository refused a change');
    }
  }
}

final class AppServerRecheckCounter {
  int checks = 0;

  Future<void> recheck() async {
    checks += 1;
  }
}

final class SynchronizationNode {
  SynchronizationNode({required this.startSequence});

  int startSequence;
  final Stopwatch clock = Stopwatch()..start();
  final List<int> feedPollsAfter = <int>[];
  final List<Duration> feedPollTimes = <Duration>[];
  final List<ScriptedFeedAnswer> queuedFeedAnswers = <ScriptedFeedAnswer>[];

  Future<String> answer(String inputJson) async {
    final int afterSequence = readPolledAfterSequence(inputJson);
    if (afterSequence == _startPollSequence) {
      return encodeEventsReply(<Object?>[], latestSequence: startSequence);
    }

    feedPollsAfter.add(afterSequence);
    feedPollTimes.add(clock.elapsed);
    if (queuedFeedAnswers.isEmpty) {
      return encodeEventsReply(<Object?>[], latestSequence: afterSequence);
    }
    final ScriptedFeedAnswer nextAnswer = queuedFeedAnswers.removeAt(0);
    return nextAnswer();
  }
}

typedef ChangeBatch = ({
  String reply,
  List<Object?> topics,
  int latestSequence,
});

ChangeBatch buildChangeBatch(
  Random random, {
  required int afterSequence,
  required int notificationCount,
}) {
  final List<Object?> notifications = <Object?>[];
  final List<Object?> topics = <Object?>[];
  int sequence = afterSequence;
  for (int i = 0; i < notificationCount; i += 1) {
    sequence += 1 + random.nextInt(_largestSequenceStep);
    final Map<String, Object?> topic = randomChangeTopicJson(random);
    topics.add(topic);
    notifications.add(<String, Object?>{'sequence': sequence, 'topic': topic});
  }

  return (
    reply: encodeEventsReply(notifications, latestSequence: sequence),
    topics: topics,
    latestSequence: sequence,
  );
}

String answerWithFailure() => encodeErrorReply('the app server is away');

String answerWithBrokenTransport() {
  throw StateError('the node transport broke');
}

String answerWithMalformedEvents() {
  return encodeSuccessReply(<String, Object?>{'notifications': 'broken'});
}

const List<ScriptedFeedAnswer> feedEndingAnswers = <ScriptedFeedAnswer>[
  answerWithBrokenTransport,
  answerWithMalformedEvents,
];

final class SynchronizationRig {
  SynchronizationRig({
    required this.random,
    required this.node,
    required this.transport,
    required this.repositories,
    required this.serverChecks,
    required this.synchronization,
  });

  factory SynchronizationRig.build(
    Random random, {
    required Duration retryDelay,
  }) {
    final SynchronizationNode node = SynchronizationNode(
      startSequence: 1 + random.nextInt(_largestSequenceStep),
    );
    final FeedPollTransport transport = FeedPollTransport(answer: node.answer);
    final int repositoryCount = 1 + random.nextInt(_largestRepositoryCount);
    final List<RecordingSynchronizedRepository> repositories =
        <RecordingSynchronizedRepository>[
          for (int i = 0; i < repositoryCount; i += 1)
            RecordingSynchronizedRepository(),
        ];
    final AppServerRecheckCounter serverChecks = AppServerRecheckCounter();
    return SynchronizationRig(
      random: random,
      node: node,
      transport: transport,
      repositories: repositories,
      serverChecks: serverChecks,
      synchronization: NodeSynchronization(
        channel: NodeCommandChannel(transport: transport),
        repositoriesInLoadOrder: repositories,
        retryDelay: retryDelay,
        recheckAppServer: serverChecks.recheck,
      ),
    );
  }

  final Random random;
  final SynchronizationNode node;
  final FeedPollTransport transport;
  final List<RecordingSynchronizedRepository> repositories;
  final AppServerRecheckCounter serverChecks;
  final NodeSynchronization synchronization;
  final List<Object?> expectedTopics = <Object?>[];
  final List<String> violations = <String>[];
  bool isRunning = false;
  int lastKnownSequence = _startPollSequence;
  int expectedServerChecks = 0;

  Future<void> settle() => letFeedTurnsPass(_settlingTurns);

  Future<void> start() async {
    _chooseNextStartSequence();
    await synchronization.start();
    _rememberStarted();
    await settle();
  }

  Future<void> startTwiceAtOnce() async {
    _chooseNextStartSequence();
    await Future.wait(<Future<void>>[
      synchronization.start(),
      synchronization.start(),
    ]);
    _rememberStarted();
    await settle();
  }

  Future<void> stopDuringStart() async {
    _chooseNextStartSequence();
    final Future<void> starting = synchronization.start();
    await synchronization.stop();
    await starting;
    isRunning = false;
    await settle();
  }

  Future<void> stop() async {
    await synchronization.stop();
    isRunning = false;
    await settle();
  }

  Future<void> deliverBatch(int notificationCount) async {
    final ChangeBatch batch = buildChangeBatch(
      random,
      afterSequence: lastKnownSequence,
      notificationCount: notificationCount,
    );

    final bool isAnswered = await answerNextFeedPoll(() => batch.reply);
    if (!isAnswered) {
      return;
    }
    expectedTopics.addAll(batch.topics);
    lastKnownSequence = batch.latestSequence;
    if (_hasRefusingRepository()) {
      expectedServerChecks += notificationCount;
    }
  }

  Future<void> failOnePoll() async {
    final bool isAnswered = await answerNextFeedPoll(answerWithFailure);
    if (isAnswered) {
      expectedServerChecks += 2;
    }
  }

  Future<void> endTheFeed(ScriptedFeedAnswer endingAnswer) async {
    final int pollsBeforeEnd = node.feedPollsAfter.length;
    final bool isAnswered = await answerNextFeedPoll(endingAnswer);
    if (!isAnswered) {
      return;
    }

    expectedServerChecks += 1;
    final int resubscribedPoll = pollsBeforeEnd + 1;
    if (node.feedPollsAfter.length <= resubscribedPoll) {
      violations.add('the feed was not followed again after it ended');
      return;
    }
    final int resubscribedAfter = node.feedPollsAfter[resubscribedPoll];
    if (resubscribedAfter != lastKnownSequence) {
      violations.add(
        'followed again after $resubscribedAfter, '
        'not after $lastKnownSequence',
      );
    }
  }

  Future<bool> answerNextFeedPoll(ScriptedFeedAnswer answer) async {
    node.queuedFeedAnswers.add(answer);
    int turns = 0;
    while (node.queuedFeedAnswers.isNotEmpty && turns < _answerPatienceTurns) {
      await letFeedTurnsPass(1);
      turns += 1;
    }
    await settle();

    final bool isAnswered = node.queuedFeedAnswers.isEmpty;
    node.queuedFeedAnswers.clear();
    if (isAnswered != isRunning) {
      violations.add('running is $isRunning but answered is $isAnswered');
    }
    return isAnswered && isRunning;
  }

  Future<int> measureLargestPollsInFlight() async {
    transport.restartInFlightMeasure();
    await settle();
    return transport.largestPollsInFlight;
  }

  void _chooseNextStartSequence() {
    node.startSequence =
        lastKnownSequence + 1 + random.nextInt(_largestSequenceStep);
  }

  void _rememberStarted() {
    isRunning = true;
    lastKnownSequence = node.startSequence;
  }

  bool _hasRefusingRepository() {
    for (final RecordingSynchronizedRepository repository in repositories) {
      if (repository.isRefusingChanges) {
        return true;
      }
    }
    return false;
  }
}
