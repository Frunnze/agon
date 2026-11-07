import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/finished_local_change.dart';

const int _largestStepCount = 12;
const int _nothingShown = 0;
const int _largestLocalChangeCount = 3;

enum _Step { startFetch, finishChangeAtOnce, accept }

typedef _StartedFetch = ({int fetch, int order});

final class _ReferenceSequence {
  int _eventCount = 0;
  int _newestOrder = -1;

  int recordStart() {
    final int order = _eventCount;
    _eventCount += 1;
    return order;
  }

  void finishChangeAtOnce() {
    _newestOrder = _eventCount;
    _eventCount += 1;
  }

  bool expectAccepted(int order) {
    if (order <= _newestOrder) {
      return false;
    }
    _newestOrder = order;
    return true;
  }
}

void main() {
  test('test_fetch_sequence_property_new_sequence_takes_its_first_reply', () {
    final Random random = seededRandom(72401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int fetchCount = 1 + random.nextInt(_largestStepCount);
      final List<int> fetches = <int>[
        for (int j = 0; j < fetchCount; j += 1) sequence.startFetch(),
      ];

      expect(sequence.acceptIfNewest(pickOne(random, fetches)), isTrue);
    }
  });

  test('test_fetch_sequence_property_first_fetch_is_after_nothing', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();

      expect(sequence.startFetch(), greaterThan(_nothingShown));
    }
  });

  test('test_fetch_sequence_property_sequences_do_not_share_state', () {
    final Random random = seededRandom(72403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence busy = FetchSequence();
      final FetchSequence quiet = FetchSequence();
      final int quietFetch = quiet.startFetch();
      final int stepCount = random.nextInt(_largestStepCount);
      for (int j = 0; j < stepCount; j += 1) {
        finishLocalChangeAtOnce(busy);
        busy.acceptIfNewest(busy.startFetch());
      }

      expect(quiet.acceptIfNewest(quietFetch), isTrue);
    }
  });

  test('test_start_fetch_property_unique_across_local_changes', () {
    final Random random = seededRandom(72404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final List<int> fetches = <int>[];
      final int stepCount = random.nextInt(_largestStepCount);
      for (int j = 0; j < stepCount; j += 1) {
        if (random.nextBool()) {
          finishLocalChangeAtOnce(sequence);
        }
        fetches.add(sequence.startFetch());
      }

      final List<int> sorted = List<int>.of(fetches);
      sorted.sort();
      expect(fetches, sorted);
      expect(fetches.toSet().length, fetches.length);
    }
  });

  test('test_start_fetch_property_newly_started_fetch_is_newest', () {
    final Random random = seededRandom(72405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int stepCount = random.nextInt(_largestStepCount);
      for (int j = 0; j < stepCount; j += 1) {
        final int fetch = sequence.startFetch();
        if (random.nextBool()) {
          sequence.acceptIfNewest(fetch);
        }
        if (random.nextBool()) {
          finishLocalChangeAtOnce(sequence);
        }
      }

      expect(sequence.acceptIfNewest(sequence.startFetch()), isTrue);
    }
  });

  test('test_start_fetch_property_unused_fetches_change_no_decision', () {
    final Random random = seededRandom(72406);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence plain = FetchSequence();
      final FetchSequence padded = FetchSequence();
      final int fetchCount = 1 + random.nextInt(_largestStepCount);
      final List<int> plainFetches = <int>[];
      final List<int> paddedFetches = <int>[];
      for (int j = 0; j < fetchCount; j += 1) {
        plainFetches.add(plain.startFetch());
        if (random.nextBool()) {
          padded.startFetch();
        }
        paddedFetches.add(padded.startFetch());
      }
      final List<int> answerOrder = <int>[
        for (int j = 0; j < fetchCount; j += 1) j,
      ];
      answerOrder.shuffle(random);

      for (final int position in answerOrder) {
        expect(
          padded.acceptIfNewest(paddedFetches[position]),
          plain.acceptIfNewest(plainFetches[position]),
        );
      }
    }
  });

  test(
    'test_finish_local_change_property_at_once_drops_every_earlier_fetch',
    () {
      final Random random = seededRandom(72407);
      for (int i = 0; i < propertyIterations; i += 1) {
        final FetchSequence sequence = FetchSequence();
        final int fetchCount = random.nextInt(_largestStepCount);
        final List<int> earlier = <int>[
          for (int j = 0; j < fetchCount; j += 1) sequence.startFetch(),
        ];
        earlier.shuffle(random);
        final int changeCount = 1 + random.nextInt(_largestLocalChangeCount);
        for (int j = 0; j < changeCount; j += 1) {
          finishLocalChangeAtOnce(sequence);
        }

        for (final int fetch in earlier) {
          expect(sequence.acceptIfNewest(fetch), isFalse);
        }
      }
    },
  );

  test(
    'test_finish_local_change_property_at_once_later_fetches_count_in_order',
    () {
      final Random random = seededRandom(72408);
      for (int i = 0; i < propertyIterations; i += 1) {
        final FetchSequence sequence = FetchSequence();
        finishLocalChangeAtOnce(sequence);
        final int fetchCount = 1 + random.nextInt(_largestStepCount);
        final List<int> later = <int>[
          for (int j = 0; j < fetchCount; j += 1) sequence.startFetch(),
        ];

        for (final int fetch in later) {
          expect(sequence.acceptIfNewest(fetch), isTrue);
        }
      }
    },
  );

  test(
    'test_finish_local_change_property_at_once_accepted_fetch_stays_old',
    () {
      final Random random = seededRandom(72409);
      for (int i = 0; i < propertyIterations; i += 1) {
        final FetchSequence sequence = FetchSequence();
        final int first = sequence.startFetch();
        final int second = sequence.startFetch();
        final bool acceptsSecondFirst = random.nextBool();
        sequence.acceptIfNewest(acceptsSecondFirst ? second : first);

        finishLocalChangeAtOnce(sequence);

        expect(sequence.acceptIfNewest(first), isFalse);
        expect(sequence.acceptIfNewest(second), isFalse);
      }
    },
  );

  test('test_accept_if_newest_property_follows_the_reference_model', () {
    final Random random = seededRandom(72410);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final _ReferenceSequence reference = _ReferenceSequence();
      final List<_StartedFetch> started = <_StartedFetch>[];
      final int stepCount = random.nextInt(_largestStepCount);
      for (int j = 0; j < stepCount; j += 1) {
        final _Step step = pickOne(random, _Step.values);
        if (step == _Step.startFetch) {
          final int fetch = sequence.startFetch();
          started.add((fetch: fetch, order: reference.recordStart()));
        }
        if (step == _Step.finishChangeAtOnce) {
          finishLocalChangeAtOnce(sequence);
          reference.finishChangeAtOnce();
        }
        if (step == _Step.accept && started.isNotEmpty) {
          final _StartedFetch chosen = pickOne(random, started);
          expect(
            sequence.acceptIfNewest(chosen.fetch),
            reference.expectAccepted(chosen.order),
          );
        }
      }
    }
  });

  test('test_accept_if_newest_property_second_accept_is_refused', () {
    final Random random = seededRandom(72411);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int fetchCount = 1 + random.nextInt(_largestStepCount);
      final List<int> fetches = <int>[
        for (int j = 0; j < fetchCount; j += 1) sequence.startFetch(),
      ];
      final int fetch = pickOne(random, fetches);

      sequence.acceptIfNewest(fetch);

      expect(sequence.acceptIfNewest(fetch), isFalse);
    }
  });
}
