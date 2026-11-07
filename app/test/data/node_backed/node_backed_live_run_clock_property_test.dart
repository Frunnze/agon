import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const int _clockIterations = 12;
const int _waitLimit = 400;
const Duration _waitStep = Duration(milliseconds: 1);
const String _stepName = 'build';
const String _holdingRunner = 'runner-1';

typedef _Fixture = ({
  SimulatedWorkNode node,
  NodeBackedTaskRepository repository,
  DateTime now,
});

_Fixture _buildFixture(Random random) {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final DateTime now = randomPreciseMoment(random);
  final NodeBackedTaskRepository repository = NodeBackedTaskRepository(
    clock: FixedClock(now),
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: workspaces,
    livePollInterval: Duration.zero,
    jobRepository: NodeBackedJobRepository(
      channel: buildSimulatedChannel(simulated.answer),
      workspaceRepository: workspaces,
      clock: const SystemClock(),
    ),
  );
  return (node: simulated, repository: repository, now: now);
}

Future<Run> _startHeldRun(Random random, _Fixture fixture) async {
  final Task task = await fixture.repository.createTask(
    randomTaskDraft(random),
  );
  final Run started = await fixture.repository.startTask(task.id);
  fixture.node.runs[started.id.value]!['steps'] = <Object?>[
    <String, Object?>{
      'name': _stepName,
      'agent_id': null,
      'runner': _holdingRunner,
      'status': 'waiting',
      'started_at': null,
      'finished_at': null,
      'result': null,
    },
  ];
  return fixture.repository.refreshRun(started.id);
}

Future<Run> _watchUntil(
  _Fixture fixture,
  Run run,
  List<WireRecord> events,
  bool Function(Run run) isReached,
) async {
  fixture.node.liveLinks[run.id.value] = 'direct';
  fixture.node.liveEvents[run.id.value] = events;
  fixture.repository.watchRun(run.id);
  for (int i = 0; i < _waitLimit; i += 1) {
    final Run watched = fixture.repository.findRun(run.id);
    if (isReached(watched)) {
      fixture.repository.stopWatchingRun(run.id);
      return watched;
    }
    await Future<void>.delayed(_waitStep);
  }
  fail('the live run did not catch up in time');
}

WireRecord _statusEvent(String status) {
  return <String, Object?>{
    'kind': 'step_status_changed',
    'step_name': _stepName,
    'status': status,
  };
}

void main() {
  test(
    'test_apply_live_view_property_step_times_come_from_the_clock',
    () async {
      final Random random = seededRandom(88521);

      for (int i = 0; i < _clockIterations; i += 1) {
        final _Fixture fixture = _buildFixture(random);
        final Run run = await _startHeldRun(random, fixture);

        final Run watched = await _watchUntil(fixture, run, <WireRecord>[
          _statusEvent('running'),
        ], (Run watched) => watched.status == RunStatus.running);

        expect(watched.steps.single.startedAt, fixture.now.toUtc());
        expect(watched.steps.single.finishedAt, isNull);
        fixture.repository.dispose();
      }
    },
  );

  test('test_apply_live_view_property_live_failure_fails_the_run', () async {
    final Random random = seededRandom(88522);

    for (int i = 0; i < _clockIterations; i += 1) {
      final _Fixture fixture = _buildFixture(random);
      final Run run = await _startHeldRun(random, fixture);
      final WireRecord failure = randomRunFailureJson(random);
      failure['step_name'] = _stepName;

      final Run watched = await _watchUntil(fixture, run, <WireRecord>[
        _statusEvent('running'),
        <String, Object?>{'kind': 'failed', 'failure': failure},
      ], (Run watched) => watched.failure != null);

      expect(watched.status, RunStatus.failed);
      expect(watched.finishedAt, fixture.now.toUtc());
      expect(watched.failure?.runner?.value, _holdingRunner);
      expect(watched.steps.single.status, StepStatus.failed);
      fixture.repository.dispose();
    }
  });

  test(
    'test_apply_live_view_property_results_and_lines_land_together',
    () async {
      final Random random = seededRandom(88523);

      for (int i = 0; i < _clockIterations; i += 1) {
        final _Fixture fixture = _buildFixture(random);
        final Run run = await _startHeldRun(random, fixture);
        final WireRecord line = randomLogLineJson(random);
        final String result = 'result ${randomText(random)}';

        final Run watched = await _watchUntil(fixture, run, <WireRecord>[
          _statusEvent('running'),
          <String, Object?>{'kind': 'log_appended', 'line': line},
          <String, Object?>{
            'kind': 'step_result_recorded',
            'step_name': _stepName,
            'result': result,
            'outcome': null,
          },
          _statusEvent('done'),
        ], (Run watched) => watched.status == RunStatus.done);

        expect(watched.steps.single.result, result);
        expect(watched.steps.single.finishedAt, fixture.now.toUtc());
        expect(watched.finishedAt, fixture.now.toUtc());
        expect(watched.log.map((LogLine logged) => logged.text), <Object?>[
          line['text'],
        ]);
        fixture.repository.dispose();
      }
    },
  );
}
