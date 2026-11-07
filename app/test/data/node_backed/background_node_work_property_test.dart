import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';

const int _settlingTurns = 30;
const int _largestDelayTurns = 5;
const int _largestWorkCount = 6;
const List<String> _recordKinds = <String>[
  'workspace',
  'project',
  'rule',
  'skill',
  'run',
];

enum _Outcome { success, nodeFailure, programmingFailure }

final class _PlannedWork {
  _PlannedWork({required this.delayTurns, required this.failure});

  final int delayTurns;
  final Object? failure;
  int runs = 0;
  bool isFinished = false;

  Future<void> runFailingAtOnce() {
    final Object? plannedFailure = failure;
    if (plannedFailure == null) {
      return run();
    }
    runs += 1;
    Error.throwWithStackTrace(plannedFailure, StackTrace.current);
  }

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

  BackgroundNodeWork pickRun(Random random) {
    if (random.nextBool()) {
      return runFailingAtOnce;
    }
    return run;
  }
}

final class _StatusWork {
  _StatusWork({required this.channel});

  final NodeCommandChannel channel;
  int runs = 0;

  Future<void> run() async {
    runs += 1;
    await executeNodeCommand(channel, const node.StatusCommand());
  }
}

Future<void> _settle() async {
  for (int turn = 0; turn < _settlingTurns; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<List<Object>> _collectEscapedProblems(
  List<BackgroundNodeWork> works,
) async {
  final List<Object> escaped = <Object>[];
  runZonedGuarded(() {
    for (final BackgroundNodeWork work in works) {
      startBackgroundNodeWork(work);
    }
  }, (Object problem, StackTrace _) => escaped.add(problem));
  await _settle();
  return escaped;
}

RecordNotFound _randomMissingRecord(Random random) {
  return RecordNotFound(
    kind: pickOne(random, _recordKinds),
    identifier: randomUuidText(random),
  );
}

String _randomNodeProblemMessage(Random random) {
  if (random.nextBool()) {
    final String kind = pickOne(random, _recordKinds);
    return '$kind ${randomUuidText(random)} was not found';
  }
  return 'could not reach the app server ${randomText(random)}';
}

Object? _planFailure(Random random, _Outcome outcome) {
  return switch (outcome) {
    _Outcome.success => null,
    _Outcome.nodeFailure =>
      random.nextBool()
          ? StateError(randomText(random))
          : _randomMissingRecord(random),
    _Outcome.programmingFailure => ArgumentError(randomText(random)),
  };
}

_PlannedWork _planWork(Random random, _Outcome outcome) {
  return _PlannedWork(
    delayTurns: random.nextInt(_largestDelayTurns),
    failure: _planFailure(random, outcome),
  );
}

void main() {
  test(
    'test_start_background_node_work_property_missing_records_stay_inside',
    () async {
      final Random random = seededRandom(72101);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PlannedWork work = _PlannedWork(
          delayTurns: random.nextInt(_largestDelayTurns),
          failure: _randomMissingRecord(random),
        );

        final List<Object> escaped = await _collectEscapedProblems(
          <BackgroundNodeWork>[work.pickRun(random)],
        );

        expect(work.runs, 1);
        expect(escaped, isEmpty);
      }
    },
  );

  test(
    'test_start_background_node_work_property_returns_before_work_finishes',
    () async {
      final Random random = seededRandom(72102);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PlannedWork work = _PlannedWork(
          delayTurns: 1 + random.nextInt(_largestDelayTurns),
          failure: null,
        );

        startBackgroundNodeWork(work.run);

        expect(work.runs, 1);
        expect(work.isFinished, isFalse);
        await _settle();
        expect(work.isFinished, isTrue);
      }
    },
  );

  test('test_run_logging_node_failures_property_every_node_reply_problem_'
      'stays_inside', () async {
    final Random random = seededRandom(72103);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = _randomNodeProblemMessage(random);
      final _StatusWork work = _StatusWork(
        channel: buildSimulatedChannel(
          (String inputJson) => encodeErrorReply(problem),
        ),
      );

      final List<Object> escaped = await _collectEscapedProblems(
        <BackgroundNodeWork>[work.run],
      );

      expect(work.runs, 1);
      expect(escaped, isEmpty, reason: problem);
    }
  });

  test('test_run_logging_node_failures_property_failing_at_once_is_sorted_'
      'like_failing_later', () async {
    final Random random = seededRandom(72104);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _Outcome outcome = pickOne(random, _Outcome.values);
      final Object? failure = _planFailure(random, outcome);
      final _PlannedWork atOnce = _PlannedWork(
        delayTurns: 0,
        failure: failure,
      );
      final _PlannedWork later = _PlannedWork(
        delayTurns: random.nextInt(_largestDelayTurns),
        failure: failure,
      );

      final List<Object> escapedAtOnce = await _collectEscapedProblems(
        <BackgroundNodeWork>[atOnce.runFailingAtOnce],
      );
      final List<Object> escapedLater = await _collectEscapedProblems(
        <BackgroundNodeWork>[later.run],
      );

      expect(escapedAtOnce, escapedLater);
    }
  });

  test('test_run_logging_node_failures_property_overlapping_work_lets_out_'
      'only_programming_failures', () async {
    final Random random = seededRandom(72105);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int workCount = 1 + random.nextInt(_largestWorkCount);
      final List<_PlannedWork> works = <_PlannedWork>[
        for (int j = 0; j < workCount; j += 1)
          _planWork(random, pickOne(random, _Outcome.values)),
      ];

      final List<Object> escaped = await _collectEscapedProblems(
        <BackgroundNodeWork>[
          for (final _PlannedWork work in works) work.pickRun(random),
        ],
      );

      final List<Object> programmingFailures = <Object>[];
      for (final _PlannedWork work in works) {
        final Object? failure = work.failure;
        if (failure is ArgumentError) {
          programmingFailures.add(failure);
        }
      }
      expect(escaped, unorderedEquals(programmingFailures));
      for (final _PlannedWork work in works) {
        expect(work.runs, 1);
      }
    }
  });
}
