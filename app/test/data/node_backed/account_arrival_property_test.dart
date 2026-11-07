import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/account_arrival_rig.dart';

const int _largestSignalCount = 4;
const int _largestWaitCount = 3;
const int _largestSourceCount = 4;

final class _ArrivalWatch {
  final List<node.AccountSummary> arrivals = <node.AccountSummary>[];

  void record(node.AccountSummary account) {
    arrivals.add(account);
  }
}

_ArrivalWatch _watchArrival(AccountArrival arrival) {
  final _ArrivalWatch watch = _ArrivalWatch();
  unawaited(arrival.waitForAccount().then(watch.record));
  return watch;
}

Future<void> _answerEveryCheck(
  HeldNodeTransport transport,
  StatusReply reply,
) async {
  for (final HeldNodeReply held in transport.listUnanswered()) {
    held.answer(reply.replyJson);
  }
  await settleAccountChecks();
}

void main() {
  test('test_account_arrival_property_sends_nothing_until_waited', () async {
    final Random random = seededRandom(72501);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SignalSource signals = SignalSource();
      final HeldNodeTransport transport = HeldNodeTransport();
      final AccountArrival arrival = AccountArrival(
        channel: transport.channel,
        accountSignals: signals,
      );
      final int earlySignals = random.nextInt(_largestSignalCount);
      for (int j = 0; j < earlySignals; j += 1) {
        signals.signal();
      }
      await settleAccountChecks();
      expect(transport.heldReplies, isEmpty);

      _watchArrival(arrival);
      signals.signal();
      await settleAccountChecks();

      expect(transport.heldReplies.length, 1);
      signals.dispose();
    }
  });

  test('test_account_arrival_property_asks_only_its_own_channel', () async {
    final Random random = seededRandom(72502);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SignalSource> signals = <SignalSource>[
        SignalSource(),
        SignalSource(),
      ];
      final List<HeldNodeTransport> transports = <HeldNodeTransport>[
        HeldNodeTransport(),
        HeldNodeTransport(),
      ];
      final List<int> signalCounts = <int>[
        random.nextInt(_largestSignalCount),
        random.nextInt(_largestSignalCount),
      ];
      for (int j = 0; j < signals.length; j += 1) {
        _watchArrival(
          AccountArrival(
            channel: transports[j].channel,
            accountSignals: signals[j],
          ),
        );
      }

      for (int j = 0; j < signals.length; j += 1) {
        for (int k = 0; k < signalCounts[j]; k += 1) {
          signals[j].signal();
        }
      }
      await settleAccountChecks();

      for (int j = 0; j < signals.length; j += 1) {
        expect(transports[j].heldReplies.length, signalCounts[j]);
        signals[j].dispose();
      }
    }
  });

  test('test_account_arrival_property_hears_every_merged_signal', () async {
    final Random random = seededRandom(72503);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int sourceCount = 1 + random.nextInt(_largestSourceCount);
      final List<SignalSource> sources = <SignalSource>[
        for (int j = 0; j < sourceCount; j += 1) SignalSource(),
      ];
      final SignalSource unrelated = SignalSource();
      final HeldNodeTransport transport = HeldNodeTransport();
      _watchArrival(
        AccountArrival(
          channel: transport.channel,
          accountSignals: Listenable.merge(sources),
        ),
      );
      final int signalCount = random.nextInt(_largestSignalCount);

      for (int j = 0; j < signalCount; j += 1) {
        pickOne(random, sources).signal();
        unrelated.signal();
      }
      await settleAccountChecks();

      expect(transport.heldReplies.length, signalCount);
      for (final SignalSource source in sources) {
        source.dispose();
      }
      unrelated.dispose();
    }
  });

  test('test_wait_for_account_property_waiting_again_asks_once_per_signal_'
      'and_stops_after_arrival', () async {
    final Random random = seededRandom(72504);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SignalSource signals = SignalSource();
      final HeldNodeTransport transport = HeldNodeTransport();
      final AccountArrival arrival = AccountArrival(
        channel: transport.channel,
        accountSignals: signals,
      );
      final int waitCount = 1 + random.nextInt(_largestWaitCount);
      final List<_ArrivalWatch> watches = <_ArrivalWatch>[
        for (int j = 0; j < waitCount; j += 1) _watchArrival(arrival),
      ];
      final StatusReply reply = buildStatusReply(
        random,
        StatusReplyKind.withAccount,
      );

      signals.signal();
      await settleAccountChecks();
      expect(transport.heldReplies.length, 1);
      await _answerEveryCheck(transport, reply);
      final int lateSignals = random.nextInt(_largestSignalCount);
      for (int j = 0; j < lateSignals; j += 1) {
        signals.signal();
      }
      await settleAccountChecks();

      expect(transport.heldReplies.length, 1);
      for (final _ArrivalWatch watch in watches) {
        expect(watch.arrivals.length, 1);
        expect(
          describeAccount(watch.arrivals.single),
          describeAccountJson(reply.accountJson),
        );
      }
      signals.dispose();
    }
  });

  test('test_wait_for_account_property_node_problems_stay_inside_and_'
      'waiting_goes_on', () async {
    final Random random = seededRandom(72505);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SignalSource signals = SignalSource();
      final HeldNodeTransport transport = HeldNodeTransport();
      final _ArrivalWatch watch = _watchArrival(
        AccountArrival(channel: transport.channel, accountSignals: signals),
      );
      final List<Object> escaped = <Object>[];
      final int failedChecks = random.nextInt(_largestSignalCount);

      for (int j = 0; j < failedChecks; j += 1) {
        signalCatchingEscapes(signals, escaped);
        final StatusReplyKind kind = pickOne(random, <StatusReplyKind>[
          StatusReplyKind.withoutAccount,
          StatusReplyKind.nodeProblem,
        ]);
        await _answerEveryCheck(transport, buildStatusReply(random, kind));
        expect(watch.arrivals, isEmpty);
      }
      signalCatchingEscapes(signals, escaped);
      final StatusReply accountReply = buildStatusReply(
        random,
        StatusReplyKind.withAccount,
      );
      await _answerEveryCheck(transport, accountReply);

      expect(escaped, isEmpty);
      expect(
        describeAccount(watch.arrivals.single),
        describeAccountJson(accountReply.accountJson),
      );
      signals.dispose();
    }
  });

  test('test_wait_for_account_property_stops_asking_once_arrived', () async {
    final Random random = seededRandom(72506);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SignalSource signals = SignalSource();
      final HeldNodeTransport transport = HeldNodeTransport();
      final _ArrivalWatch watch = _watchArrival(
        AccountArrival(channel: transport.channel, accountSignals: signals),
      );
      signals.signal();
      await settleAccountChecks();
      await _answerEveryCheck(
        transport,
        buildStatusReply(random, StatusReplyKind.withAccount),
      );
      final int checksAtArrival = transport.heldReplies.length;

      final int lateSignals = 1 + random.nextInt(_largestSignalCount);
      for (int j = 0; j < lateSignals; j += 1) {
        signals.signal();
      }
      await settleAccountChecks();

      expect(transport.heldReplies.length, checksAtArrival);
      expect(watch.arrivals.length, 1);
      signals.dispose();
    }
  });
}
