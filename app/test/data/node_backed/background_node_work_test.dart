import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';

const int _settlingTurns = 10;
const String _nodeProblem = 'could not reach the app server';

final class _ScriptedWork {
  _ScriptedWork({required this.plannedFailure});

  final Error? plannedFailure;
  int runs = 0;

  Future<void> run() async {
    runs += 1;
    await Future<void>.delayed(Duration.zero);
    final Error? failure = plannedFailure;
    if (failure != null) {
      throw failure;
    }
  }

  Future<int> runCountingRuns() async {
    await run();
    return runs;
  }
}

Future<List<Object>> _collectEscapedProblems(BackgroundNodeWork work) async {
  final List<Object> escaped = <Object>[];
  runZonedGuarded(
    () => startBackgroundNodeWork(work),
    (Object problem, StackTrace _) => escaped.add(problem),
  );
  for (int turn = 0; turn < _settlingTurns; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  return escaped;
}

Error? _pickNodeOutcome(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return StateError('$_nodeProblem ${randomText(random)}');
}

Error _pickProgrammingFailure(Random random) {
  final List<Error> failures = <Error>[
    ArgumentError(randomText(random)),
    UnsupportedError(randomText(random)),
    RangeError(randomText(random)),
  ];
  return pickOne(random, failures);
}

void main() {
  test(
    'test_start_background_node_work_property_node_failures_stay_inside',
    () async {
      final Random random = seededRandom(9994);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _ScriptedWork work = _ScriptedWork(
          plannedFailure: _pickNodeOutcome(random),
        );

        final List<Object> escaped = await _collectEscapedProblems(work.run);

        expect(work.runs, 1);
        expect(escaped, isEmpty);
      }
    },
  );

  test(
    'test_start_background_node_work_property_other_failures_escape',
    () async {
      final Random random = seededRandom(9995);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Error failure = _pickProgrammingFailure(random);
        final _ScriptedWork work = _ScriptedWork(plannedFailure: failure);

        final List<Object> escaped = await _collectEscapedProblems(work.run);

        expect(work.runs, 1);
        expect(escaped, <Object>[failure]);
      }
    },
  );

  test(
    'test_start_background_node_work_property_any_answer_type_stays_inside',
    () async {
      final Random random = seededRandom(9996);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _ScriptedWork work = _ScriptedWork(
          plannedFailure: _pickNodeOutcome(random),
        );

        final List<Object> escaped = await _collectEscapedProblems(
          work.runCountingRuns,
        );

        expect(work.runs, 1);
        expect(escaped, isEmpty);
      }
    },
  );
}
