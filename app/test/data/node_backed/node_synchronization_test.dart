import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';

const int _sequenceIterations = 15;
const int _largestRepositoryCount = 5;
const int _settlingTurns = 40;
const int _firstSequence = 7;
const int _largestFailureCount = 3;
const String _unreachableProblem = 'the app server is unreachable';

final class _RecordingRepository implements NodeSynchronized {
  _RecordingRepository({required this.name, required this.loadOrder});

  final String name;
  final List<String> loadOrder;
  final List<Object?> appliedTopics = <Object?>[];
  bool isRefusingChanges = false;

  @override
  Future<void> load() async {
    loadOrder.add(name);
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    appliedTopics.add(topic.toJson());
    if (isRefusingChanges) {
      throw StateError('refused $name');
    }
  }
}

final class _ScriptedFeed {
  _ScriptedFeed({required this.batches});

  final List<Map<String, Object?>> batches;
  final List<int> polledAfter = <int>[];

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    polledAfter.add(command['after']! as int);
    if (polledAfter.length == 1) {
      return encodeSuccessReply(<String, Object?>{
        'notifications': <Object?>[],
        'latest_sequence': _firstSequence,
      });
    }
    final int batchIndex = polledAfter.length - 2;
    if (batchIndex < batches.length) {
      return encodeSuccessReply(batches[batchIndex]);
    }
    return encodeSuccessReply(<String, Object?>{
      'notifications': <Object?>[],
      'latest_sequence': _firstSequence,
    });
  }
}

final class _FailingFeed {
  _FailingFeed({required this.failureCount});

  final int failureCount;
  int _polls = 0;

  String answer(String inputJson) {
    _polls += 1;
    final bool isStartingPoll = _polls == 1;
    final bool isFailingPoll = !isStartingPoll && _polls <= failureCount + 1;
    if (isFailingPoll) {
      return encodeErrorReply(_unreachableProblem);
    }
    return encodeSuccessReply(<String, Object?>{
      'notifications': <Object?>[],
      'latest_sequence': _firstSequence,
    });
  }
}

final class _RecordingServerCheck {
  _RecordingServerCheck({required this.isRefusing});

  final bool isRefusing;
  int checks = 0;

  Future<void> recheck() async {
    checks += 1;
    if (isRefusing) {
      throw StateError(_unreachableProblem);
    }
  }
}

final class _AccountStatusScript {
  _AccountStatusScript({
    required this.status,
    required this.account,
    required this.checksWithoutAccount,
  });

  final Map<String, Object?> status;
  final Map<String, Object?> account;
  final int checksWithoutAccount;
  int statusChecks = 0;

  String answer(String inputJson) {
    statusChecks += 1;
    final bool hasAccount = statusChecks > checksWithoutAccount;
    return encodeSuccessReply(<String, Object?>{
      ...status,
      'account': hasAccount ? account : null,
    });
  }
}

List<Object?> _expectedTopics(List<Map<String, Object?>> batches) {
  final List<Object?> topics = <Object?>[];
  for (final Map<String, Object?> batch in batches) {
    for (final Object? notification
        in batch['notifications']! as List<Object?>) {
      topics.add((notification! as Map<String, Object?>)['topic']);
    }
  }
  return topics;
}

Future<void> _settle() async {
  for (int turn = 0; turn < _settlingTurns; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'test_start_property_loads_in_order_then_follows_every_change',
    () async {
      final Random random = seededRandom(9991);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final List<String> loadOrder = <String>[];
        final int repositoryCount =
            1 + random.nextInt(_largestRepositoryCount);
        final List<_RecordingRepository> repositories = <_RecordingRepository>[
          for (int j = 0; j < repositoryCount; j += 1)
            _RecordingRepository(name: 'repository-$j', loadOrder: loadOrder),
        ];
        repositories.first.isRefusingChanges = random.nextBool();
        final List<Map<String, Object?>> batches = <Map<String, Object?>>[
          randomEventsResponseJson(random),
          randomEventsResponseJson(random),
        ];
        final _ScriptedFeed feed = _ScriptedFeed(batches: batches);
        final NodeSynchronization synchronization = NodeSynchronization(
          channel: buildSimulatedChannel(feed.answer),
          repositoriesInLoadOrder: repositories,
          retryDelay: Duration.zero,
          recheckAppServer: _RecordingServerCheck(isRefusing: false).recheck,
        );

        await synchronization.start();
        await _settle();
        await synchronization.stop();

        expect(loadOrder, <String>[
          for (final _RecordingRepository repository in repositories)
            repository.name,
        ]);
        expect(feed.polledAfter.first, 0);
        expect(feed.polledAfter[1], _firstSequence);
        for (final _RecordingRepository repository in repositories) {
          expect(repository.appliedTopics, _expectedTopics(batches));
        }
      }
    },
  );

  test(
    'test_start_property_each_feed_problem_and_recovery_rechecks_the_server',
    () async {
      final Random random = seededRandom(9993);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final int failureCount = random.nextInt(_largestFailureCount + 1);
        final _RecordingServerCheck serverCheck = _RecordingServerCheck(
          isRefusing: random.nextBool(),
        );
        final _FailingFeed feed = _FailingFeed(failureCount: failureCount);
        final NodeSynchronization synchronization = NodeSynchronization(
          channel: buildSimulatedChannel(feed.answer),
          repositoriesInLoadOrder: <NodeSynchronized>[
            _RecordingRepository(name: 'repository', loadOrder: <String>[]),
          ],
          retryDelay: Duration.zero,
          recheckAppServer: serverCheck.recheck,
        );

        await synchronization.start();
        await _settle();
        await synchronization.stop();

        final int recoveryChecks = failureCount == 0 ? 0 : 1;
        expect(serverCheck.checks, failureCount + recoveryChecks);
      }
    },
  );

  test(
    'test_wait_for_account_property_completes_once_account_exists',
    () async {
      final Random random = seededRandom(9992);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final int checksWithoutAccount = random.nextInt(4);
        final _AccountStatusScript script = _AccountStatusScript(
          status: randomStatusViewJson(random),
          account: randomAccountSummaryJson(random),
          checksWithoutAccount: checksWithoutAccount,
        );
        final ChangeNotifier signals = ChangeNotifier();
        final AccountArrival arrival = AccountArrival(
          channel: buildSimulatedChannel(script.answer),
          accountSignals: signals,
        );
        node.AccountSummary? arrivedAccount;
        final Future<void> waiting = arrival.waitForAccount().then(
          (node.AccountSummary account) => arrivedAccount = account,
        );

        for (int check = 0; check <= checksWithoutAccount; check += 1) {
          expect(arrivedAccount, isNull);
          signals.notifyListeners();
          await _settle();
        }

        await waiting;
        expect(
          jsonEncode(arrivedAccount?.toJson()),
          jsonEncode(node.AccountSummary.fromJson(script.account).toJson()),
        );
        expect(script.statusChecks, checksWithoutAccount + 1);
        signals.notifyListeners();
        await _settle();
        expect(script.statusChecks, checksWithoutAccount + 1);
        signals.dispose();
      }
    },
  );
}
