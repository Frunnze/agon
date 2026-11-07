import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/finished_local_change.dart';

const int _largestStepCount = 12;
const int _raceIterations = 60;
const int _nothingShown = 0;

enum _RaceStep { startFetch, changeLocally, answerOne }

final class _PendingFetch {
  _PendingFetch({required this.startOrder});

  final int startOrder;
  final Completer<int?> reply = Completer<int?>();
  int? answeredValue;

  void answer(int? value) {
    answeredValue = value;
    reply.complete(value);
  }
}

final class _RaceRecord {
  final List<_PendingFetch> started = <_PendingFetch>[];
  int startedCount = 0;
  int lastLocalChangeOrder = -1;
  int lastLocalValue = _nothingShown;

  int expectShownValue() {
    int expectedValue = lastLocalValue;
    int newestOrder = lastLocalChangeOrder;
    for (final _PendingFetch fetch in started) {
      final int? answeredValue = fetch.answeredValue;
      if (answeredValue != null && fetch.startOrder > newestOrder) {
        newestOrder = fetch.startOrder;
        expectedValue = answeredValue;
      }
    }
    return expectedValue;
  }
}

int? _randomReply(Random random, int value) {
  if (random.nextBool()) {
    return null;
  }
  return value;
}

final class _ShownValueStore {
  final FetchSequence fetches = FetchSequence();
  final List<int> acceptedFetches = <int>[];
  int shownValue = _nothingShown;

  Future<void> fetch(Future<int?> reply) async {
    final int fetch = fetches.startFetch();
    final int? fetchedValue = await reply;
    if (fetchedValue == null || !fetches.acceptIfNewest(fetch)) {
      return;
    }
    acceptedFetches.add(fetch);
    shownValue = fetchedValue;
  }

  void changeLocally(int value) {
    finishLocalChangeAtOnce(fetches);
    shownValue = value;
  }
}

Future<void> _letRepliesArrive() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'test_accept_if_newest_property_late_replies_never_hide_newer_ones',
    () async {
      final Random random = seededRandom(72412);
      for (int i = 0; i < _raceIterations; i += 1) {
        final _ShownValueStore store = _ShownValueStore();
        final _RaceRecord record = _RaceRecord();
        final List<_PendingFetch> pending = <_PendingFetch>[];
        final List<Future<void>> fetching = <Future<void>>[];
        int nextValue = _nothingShown + 1;
        final int stepCount = random.nextInt(_largestStepCount);
        for (int j = 0; j < stepCount; j += 1) {
          final _RaceStep step = pickOne(random, _RaceStep.values);
          if (step == _RaceStep.startFetch) {
            final _PendingFetch fetch = _PendingFetch(
              startOrder: record.startedCount,
            );
            record.startedCount += 1;
            record.started.add(fetch);
            pending.add(fetch);
            fetching.add(store.fetch(fetch.reply.future));
          }
          if (step == _RaceStep.changeLocally) {
            store.changeLocally(nextValue);
            record.lastLocalChangeOrder = record.startedCount;
            record.lastLocalValue = nextValue;
            record.startedCount += 1;
          }
          if (step == _RaceStep.answerOne && pending.isNotEmpty) {
            final int position = random.nextInt(pending.length);
            pending.removeAt(position).answer(_randomReply(random, nextValue));
          }
          nextValue += 1;
          await _letRepliesArrive();
        }
        pending.shuffle(random);
        for (final _PendingFetch fetch in pending) {
          fetch.answer(_randomReply(random, nextValue));
          nextValue += 1;
          await _letRepliesArrive();
        }
        await Future.wait(fetching);

        final List<int> sortedAccepted = List<int>.of(store.acceptedFetches);
        sortedAccepted.sort();
        expect(store.acceptedFetches, sortedAccepted);
        expect(store.shownValue, record.expectShownValue());
      }
    },
  );
}
