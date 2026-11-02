import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';

const int _largestFetchCount = 8;

void main() {
  test('test_accept_if_newest_property_accepted_fetches_only_grow', () {
    final Random random = seededRandom(9998);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int fetchCount = 1 + random.nextInt(_largestFetchCount);
      final List<int> fetches = <int>[
        for (int j = 0; j < fetchCount; j += 1) sequence.startFetch(),
      ];
      fetches.shuffle(random);

      int newestAccepted = 0;
      for (final int fetch in fetches) {
        final bool isAccepted = sequence.acceptIfNewest(fetch);
        expect(isAccepted, fetch > newestAccepted);
        if (isAccepted) {
          newestAccepted = fetch;
        }
      }
      expect(newestAccepted, fetchCount);
    }
  });

  test('test_start_fetch_property_numbers_strictly_increase', () {
    final Random random = seededRandom(9999);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int fetchCount = random.nextInt(_largestFetchCount);
      int previous = 0;
      for (int j = 0; j < fetchCount; j += 1) {
        final int fetch = sequence.startFetch();
        expect(fetch, greaterThan(previous));
        previous = fetch;
      }
    }
  });

  test('test_record_local_change_property_only_later_fetches_count', () {
    final Random random = seededRandom(10001);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int earlierCount = random.nextInt(_largestFetchCount);
      final List<int> earlier = <int>[
        for (int j = 0; j < earlierCount; j += 1) sequence.startFetch(),
      ];

      sequence.recordLocalChange();
      final int later = sequence.startFetch();

      for (final int fetch in earlier) {
        expect(sequence.acceptIfNewest(fetch), isFalse);
      }
      expect(sequence.acceptIfNewest(later), isTrue);
    }
  });
}
