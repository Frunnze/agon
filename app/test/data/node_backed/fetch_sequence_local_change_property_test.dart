import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/finished_local_change.dart';

const int _largestStepCount = 16;

typedef _FetchPair = ({int plainFetch, int changedFetch});

enum _Event { startFetch, landFetch, finishChangeAtOnce, startChange, finish }

typedef _PendingFetch = ({int fetch, int startedAt});

final class _OpenChange {
  _OpenChange({required this.change, required this.startedAt});

  final int change;
  final int startedAt;
  bool isOvertaken = false;
}

final class _ModelSequence {
  final FetchSequence fetches = FetchSequence();
  final List<_PendingFetch> pendingFetches = <_PendingFetch>[];
  final List<_OpenChange> openChanges = <_OpenChange>[];
  int reloads = 0;
  int moment = 0;

  Future<void> reload() async {
    reloads += 1;
  }

  void overtakeChangesStartedBefore(int startedAt) {
    for (final _OpenChange open in openChanges) {
      if (open.startedAt < startedAt) {
        open.isOvertaken = true;
      }
    }
  }

  void takeEvent(Random random, _Event event) {
    switch (event) {
      case _Event.startFetch:
        moment += 1;
        pendingFetches.add((fetch: fetches.startFetch(), startedAt: moment));
      case _Event.landFetch:
        if (pendingFetches.isEmpty) {
          return;
        }
        final _PendingFetch landed = pendingFetches.removeAt(
          random.nextInt(pendingFetches.length),
        );
        if (fetches.acceptIfNewest(landed.fetch)) {
          overtakeChangesStartedBefore(landed.startedAt);
        }
      case _Event.finishChangeAtOnce:
        finishLocalChangeAtOnce(fetches);
        moment += 1;
        overtakeChangesStartedBefore(moment);
      case _Event.startChange:
        moment += 1;
        openChanges.add(
          _OpenChange(change: fetches.startLocalChange(), startedAt: moment),
        );
      case _Event.finish:
        finishRandomChange(random);
    }
  }

  void finishRandomChange(Random random) {
    if (openChanges.isEmpty) {
      return;
    }
    final _OpenChange finished = openChanges.removeAt(
      random.nextInt(openChanges.length),
    );
    final int reloadsBefore = reloads;

    fetches.finishLocalChange(finished.change, reloadWhenOvertaken: reload);

    expect(reloads - reloadsBefore, finished.isOvertaken ? 1 : 0);
    moment += 1;
    overtakeChangesStartedBefore(moment);
  }
}

final class _LandingReload {
  _LandingReload(this.sequence);

  final FetchSequence sequence;
  final List<bool> answers = <bool>[];

  Future<void> reload() async {
    final int fetch = sequence.startFetch();
    await Future<void>.delayed(Duration.zero);
    answers.add(sequence.acceptIfNewest(fetch));
  }
}

void main() {
  test('test_start_local_change_property_refused_fetches_never_overtake', () {
    final Random random = seededRandom(80741);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ModelSequence model = _ModelSequence();
      final int olderCount = random.nextInt(_largestStepCount);
      final List<int> olderFetches = <int>[
        for (int k = 0; k < olderCount; k += 1) model.fetches.startFetch(),
      ];
      finishLocalChangeAtOnce(model.fetches);
      final int change = model.fetches.startLocalChange();
      final int laterCount = random.nextInt(_largestStepCount);
      for (int k = 0; k < laterCount; k += 1) {
        model.fetches.startFetch();
      }

      for (final int older in olderFetches) {
        expect(model.fetches.acceptIfNewest(older), isFalse);
      }
      model.fetches.finishLocalChange(
        change,
        reloadWhenOvertaken: model.reload,
      );

      expect(model.reloads, 0);
    }
  });

  test('test_start_local_change_property_never_changes_fetch_answers', () {
    final Random random = seededRandom(80742);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence plain = FetchSequence();
      final FetchSequence withChanges = FetchSequence();
      final List<_FetchPair> pendingFetchPairs = <_FetchPair>[];
      final int stepCount = 1 + random.nextInt(_largestStepCount);

      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextBool()) {
          withChanges.startLocalChange();
        }
        if (random.nextBool() || pendingFetchPairs.isEmpty) {
          pendingFetchPairs.add((
            plainFetch: plain.startFetch(),
            changedFetch: withChanges.startFetch(),
          ));
          continue;
        }
        final _FetchPair landed = pendingFetchPairs.removeAt(
          random.nextInt(pendingFetchPairs.length),
        );
        expect(
          withChanges.isLatestFetch(landed.changedFetch),
          plain.isLatestFetch(landed.plainFetch),
        );
        expect(
          withChanges.acceptIfNewest(landed.changedFetch),
          plain.acceptIfNewest(landed.plainFetch),
        );
      }
    }
  });

  test('test_start_local_change_property_later_fetches_still_land', () {
    final Random random = seededRandom(80743);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int changeCount = 1 + random.nextInt(_largestStepCount);
      for (int change = 0; change < changeCount; change += 1) {
        sequence.startLocalChange();
      }

      final int fetch = sequence.startFetch();

      expect(sequence.isLatestFetch(fetch), isTrue);
      expect(sequence.acceptIfNewest(fetch), isTrue);
    }
  });

  test('test_finish_local_change_property_reloads_exactly_when_overtaken', () {
    final Random random = seededRandom(80744);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ModelSequence model = _ModelSequence();
      final int stepCount = 1 + random.nextInt(_largestStepCount);

      for (int step = 0; step < stepCount; step += 1) {
        model.takeEvent(random, pickOne(random, _Event.values));
      }
      while (model.openChanges.isNotEmpty) {
        model.finishRandomChange(random);
      }
    }
  });

  test('test_finish_local_change_property_refuses_every_earlier_fetch', () {
    final Random random = seededRandom(80745);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ModelSequence model = _ModelSequence();
      final int stepCount = 1 + random.nextInt(_largestStepCount);
      for (int step = 0; step < stepCount; step += 1) {
        model.takeEvent(random, pickOne(random, _Event.values));
      }
      final int change = model.fetches.startLocalChange();

      model.fetches.finishLocalChange(
        change,
        reloadWhenOvertaken: model.reload,
      );

      for (final _PendingFetch pending in model.pendingFetches) {
        expect(model.fetches.acceptIfNewest(pending.fetch), isFalse);
      }
    }
  });

  test('test_finish_local_change_property_earlier_fetches_never_overtake', () {
    final Random random = seededRandom(80747);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ModelSequence model = _ModelSequence();
      final int earlierCount = 1 + random.nextInt(_largestStepCount);
      final List<int> earlierFetches = <int>[
        for (int k = 0; k < earlierCount; k += 1) model.fetches.startFetch(),
      ];
      final int change = model.fetches.startLocalChange();
      earlierFetches.shuffle(random);

      for (final int earlier in earlierFetches) {
        model.fetches.acceptIfNewest(earlier);
      }
      model.fetches.finishLocalChange(
        change,
        reloadWhenOvertaken: model.reload,
      );

      expect(model.reloads, 0);
    }
  });

  test('test_finish_local_change_property_the_reload_lands', () async {
    final Random random = seededRandom(80746);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final _LandingReload landing = _LandingReload(sequence);

      final int change = sequence.startLocalChange();
      final int overtakingCount = 1 + random.nextInt(_largestStepCount);
      for (int step = 0; step < overtakingCount; step += 1) {
        sequence.acceptIfNewest(sequence.startFetch());
      }
      sequence.finishLocalChange(change, reloadWhenOvertaken: landing.reload);
      await pumpEventQueue();

      expect(landing.answers, <bool>[true]);
    }
  });
}
