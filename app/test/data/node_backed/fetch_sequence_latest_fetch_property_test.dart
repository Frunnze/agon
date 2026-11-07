import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/finished_local_change.dart';

const int _largestStepCount = 16;

enum _Event { startFetch, finishChangeAtOnce, switchWorkspace, landFetch }

typedef _Listing = ({int changeCount, int workspace});

typedef _PendingFetch = ({int fetch, _Listing snapshot});

final class _ModelRepository {
  final FetchSequence fetches = FetchSequence();
  final List<_PendingFetch> pending = <_PendingFetch>[];
  int nodeChangeCount = 0;
  int currentWorkspace = 0;
  _Listing shown = (changeCount: 0, workspace: 0);

  void startFetch() {
    final _Listing snapshot = (
      changeCount: nodeChangeCount,
      workspace: currentWorkspace,
    );
    pending.add((fetch: fetches.startFetch(), snapshot: snapshot));
  }

  void changeLocally() {
    nodeChangeCount += 1;
    finishLocalChangeAtOnce(fetches);
    shown = (changeCount: nodeChangeCount, workspace: shown.workspace);
  }

  void switchWorkspace() {
    currentWorkspace += 1;
    startFetch();
  }

  void landFetch(int position) {
    final _PendingFetch landed = pending.removeAt(position);
    if (fetches.acceptIfNewest(landed.fetch)) {
      shown = landed.snapshot;
      return;
    }
    if (fetches.isLatestFetch(landed.fetch)) {
      startFetch();
    }
  }
}

void _takeEvent(Random random, _ModelRepository model) {
  switch (pickOne(random, _Event.values)) {
    case _Event.startFetch:
      model.startFetch();
    case _Event.finishChangeAtOnce:
      model.changeLocally();
    case _Event.switchWorkspace:
      model.switchWorkspace();
    case _Event.landFetch:
      if (model.pending.isNotEmpty) {
        model.landFetch(random.nextInt(model.pending.length));
      }
  }
}

void main() {
  test('test_is_latest_fetch_property_only_the_newest_started_fetch', () {
    final Random random = seededRandom(76501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final List<int> started = <int>[];
      final int stepCount = 1 + random.nextInt(_largestStepCount);
      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextBool()) {
          started.add(sequence.startFetch());
        } else {
          finishLocalChangeAtOnce(sequence);
        }
      }

      for (final int fetch in started) {
        expect(sequence.isLatestFetch(fetch), fetch == started.last);
      }
    }
  });

  test('test_is_latest_fetch_property_judging_fetches_never_moves_it', () {
    final Random random = seededRandom(76502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FetchSequence sequence = FetchSequence();
      final int fetchCount = 1 + random.nextInt(_largestStepCount);
      final List<int> started = <int>[
        for (int j = 0; j < fetchCount; j += 1) sequence.startFetch(),
      ];
      for (int j = 0; j < random.nextInt(_largestStepCount); j += 1) {
        finishLocalChangeAtOnce(sequence);
        sequence.acceptIfNewest(pickOne(random, started));
      }

      expect(sequence.isLatestFetch(started.last), isTrue);
      expect(sequence.isLatestFetch(started.last + 1), isFalse);
    }
  });

  test('test_is_latest_fetch_property_retrying_it_ends_on_the_node_state', () {
    final Random random = seededRandom(76503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ModelRepository model = _ModelRepository();
      final int stepCount = random.nextInt(_largestStepCount);
      for (int step = 0; step < stepCount; step += 1) {
        _takeEvent(random, model);
      }
      while (model.pending.isNotEmpty) {
        model.landFetch(random.nextInt(model.pending.length));
      }

      expect(model.shown.changeCount, model.nodeChangeCount);
      expect(model.shown.workspace, model.currentWorkspace);
    }
  });
}
