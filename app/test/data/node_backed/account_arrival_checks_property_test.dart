import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/account_arrival_rig.dart';

const int _largestSignalCount = 5;
const String _statusCommandName = 'status';

final class _WaitingArrival {
  _WaitingArrival() {
    final AccountArrival arrival = AccountArrival(
      channel: transport.channel,
      accountSignals: signals,
    );
    unawaited(arrival.waitForAccount().then(_record));
  }

  final SignalSource signals = SignalSource();
  final HeldNodeTransport transport = HeldNodeTransport();
  final List<node.AccountSummary> arrivals = <node.AccountSummary>[];
  final List<Object> escaped = <Object>[];

  void signalTimes(int signalCount) {
    for (int i = 0; i < signalCount; i += 1) {
      signalCatchingEscapes(signals, escaped);
    }
  }

  void _record(node.AccountSummary account) {
    arrivals.add(account);
  }
}

StatusReplyKind _pickReplyKind(Random random) {
  return pickOne(random, StatusReplyKind.values);
}

String? _findFirstAccount(List<StatusReply> repliesInAnswerOrder) {
  for (final StatusReply reply in repliesInAnswerOrder) {
    final Map<String, Object?>? accountJson = reply.accountJson;
    if (accountJson != null) {
      return describeAccountJson(accountJson);
    }
  }
  return null;
}

void main() {
  test(
    'test_check_for_account_property_each_signal_sends_one_status_command',
    () async {
      final Random random = seededRandom(72601);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _WaitingArrival waiting = _WaitingArrival();
        final int signalCount = random.nextInt(_largestSignalCount);

        waiting.signalTimes(signalCount);
        await settleAccountChecks();

        expect(waiting.transport.heldReplies.length, signalCount);
        for (final HeldNodeReply held in waiting.transport.heldReplies) {
          expect(held.readCommandName(), _statusCommandName);
        }
        waiting.signals.dispose();
      }
    },
  );

  test(
    'test_check_for_account_property_keeps_listening_without_an_account',
    () async {
      final Random random = seededRandom(72602);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _WaitingArrival waiting = _WaitingArrival();
        final int signalCount = 1 + random.nextInt(_largestSignalCount);

        for (int j = 0; j < signalCount; j += 1) {
          waiting.signalTimes(1);
          await settleAccountChecks();
          final StatusReply reply = buildStatusReply(
            random,
            StatusReplyKind.withoutAccount,
          );
          waiting.transport.listUnanswered().single.answer(reply.replyJson);
          await settleAccountChecks();
        }

        expect(waiting.transport.heldReplies.length, signalCount);
        expect(waiting.arrivals, isEmpty);
        expect(waiting.escaped, isEmpty);
        waiting.signals.dispose();
      }
    },
  );

  test(
    'test_check_for_account_property_signal_returns_before_the_reply',
    () async {
      final Random random = seededRandom(72603);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _WaitingArrival waiting = _WaitingArrival();
        final int signalCount = 1 + random.nextInt(_largestSignalCount);

        waiting.signalTimes(signalCount);
        await settleAccountChecks();

        expect(waiting.transport.listUnanswered().length, signalCount);
        expect(waiting.arrivals, isEmpty);
        for (final HeldNodeReply held in waiting.transport.listUnanswered()) {
          held.answer(
            buildStatusReply(random, StatusReplyKind.withAccount).replyJson,
          );
        }
        await settleAccountChecks();
        expect(waiting.arrivals.length, 1);
        waiting.signals.dispose();
      }
    },
  );

  test(
    'test_complete_when_account_exists_property_first_account_reply_wins',
    () async {
      final Random random = seededRandom(72604);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _WaitingArrival waiting = _WaitingArrival();
        final int signalCount = 1 + random.nextInt(_largestSignalCount);
        waiting.signalTimes(signalCount);
        await settleAccountChecks();
        final List<HeldNodeReply> answerOrder = List<HeldNodeReply>.of(
          waiting.transport.heldReplies,
        );
        answerOrder.shuffle(random);
        final List<StatusReply> replies = <StatusReply>[];

        for (final HeldNodeReply held in answerOrder) {
          final StatusReply reply = buildStatusReply(
            random,
            _pickReplyKind(random),
          );
          replies.add(reply);
          held.answer(reply.replyJson);
          await settleAccountChecks();
        }

        final String? expectedAccount = _findFirstAccount(replies);
        expect(waiting.escaped, isEmpty);
        if (expectedAccount == null) {
          expect(waiting.arrivals, isEmpty);
        } else {
          expect(describeAccount(waiting.arrivals.single), expectedAccount);
        }
        waiting.signals.dispose();
      }
    },
  );

  test('test_complete_when_account_exists_property_arrives_with_the_node_'
      'account', () async {
    final Random random = seededRandom(72605);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _WaitingArrival waiting = _WaitingArrival();
      final StatusReply reply = buildStatusReply(
        random,
        StatusReplyKind.withAccount,
      );

      waiting.signalTimes(1);
      await settleAccountChecks();
      waiting.transport.heldReplies.single.answer(reply.replyJson);
      await settleAccountChecks();

      expect(
        describeAccount(waiting.arrivals.single),
        describeAccountJson(reply.accountJson),
      );
      waiting.signals.dispose();
    }
  });

  test('test_complete_when_account_exists_property_late_replies_change_'
      'nothing', () async {
    final Random random = seededRandom(72606);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _WaitingArrival waiting = _WaitingArrival();
      final int signalCount = 2 + random.nextInt(_largestSignalCount);
      waiting.signalTimes(signalCount);
      await settleAccountChecks();
      final List<HeldNodeReply> held = waiting.transport.listUnanswered();
      final HeldNodeReply first = held.removeAt(random.nextInt(held.length));
      final StatusReply arrivedReply = buildStatusReply(
        random,
        StatusReplyKind.withAccount,
      );
      first.answer(arrivedReply.replyJson);
      await settleAccountChecks();

      for (final HeldNodeReply lateReply in held) {
        lateReply.answer(
          buildStatusReply(random, _pickReplyKind(random)).replyJson,
        );
        await settleAccountChecks();
      }
      waiting.signalTimes(random.nextInt(_largestSignalCount));
      await settleAccountChecks();

      expect(waiting.escaped, isEmpty);
      expect(waiting.transport.heldReplies.length, signalCount);
      expect(
        describeAccount(waiting.arrivals.single),
        describeAccountJson(arrivedReply.accountJson),
      );
      waiting.signals.dispose();
    }
  });
}
