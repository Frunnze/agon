import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';

const int _largestDelayTurns = 5;

final class _DelayedWork {
  _DelayedWork({required this.delayTurns, required this.failure});

  final int delayTurns;
  final Object? failure;
  int runs = 0;
  bool isFinished = false;

  Future<void> run() async {
    runs += 1;
    for (int turn = 0; turn < delayTurns; turn += 1) {
      await Future<void>.delayed(Duration.zero);
    }
    isFinished = true;
    final Object? plannedFailure = failure;
    if (plannedFailure != null) {
      Error.throwWithStackTrace(plannedFailure, StackTrace.current);
    }
  }
}

Object _randomNodeFailure(Random random) {
  final String text = randomText(random);
  return switch (random.nextInt(3)) {
    0 => StateError(text),
    1 => AppServerRefusal(status: 400 + random.nextInt(200), reason: text),
    _ => RecordNotFound(kind: 'run', identifier: text),
  };
}

Object _randomProgrammingFailure(Random random) {
  final String text = randomText(random);
  return switch (random.nextInt(3)) {
    0 => ArgumentError(text),
    1 => FormatException(text),
    _ => UnsupportedError(text),
  };
}

_DelayedWork _planWork(Random random, Object? failure) {
  return _DelayedWork(
    delayTurns: random.nextInt(_largestDelayTurns),
    failure: failure,
  );
}

void main() {
  test(
    'test_run_logging_node_failures_property_completes_after_the_work_ends',
    () async {
      final Random random = seededRandom(80721);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? failure = random.nextBool()
            ? null
            : _randomNodeFailure(random);
        final _DelayedWork work = _planWork(random, failure);

        await runLoggingNodeFailures(work.run);

        expect(work.runs, 1);
        expect(work.isFinished, isTrue);
      }
    },
  );

  test(
    'test_run_logging_node_failures_property_node_failures_stay_inside',
    () async {
      final Random random = seededRandom(80722);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _DelayedWork work = _planWork(
          random,
          _randomNodeFailure(random),
        );

        await expectLater(runLoggingNodeFailures(work.run), completes);
        expect(work.runs, 1);
      }
    },
  );

  test(
    'test_run_logging_node_failures_property_other_failures_reach_the_caller',
    () async {
      final Random random = seededRandom(80723);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Object failure = _randomProgrammingFailure(random);
        final _DelayedWork work = _planWork(random, failure);

        await expectLater(
          runLoggingNodeFailures(work.run),
          throwsA(same(failure)),
        );
        expect(work.runs, 1);
      }
    },
  );
}
