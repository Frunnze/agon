import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const int _liveIterations = 15;
const int _largestEventCount = 5;
const int _waitLimit = 400;
const Duration _waitStep = Duration(milliseconds: 1);

typedef _Fixture = ({
  SimulatedWorkNode node,
  NodeBackedTaskRepository repository,
});

_Fixture _buildFixture() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedTaskRepository repository = NodeBackedTaskRepository(
    clock: const SystemClock(),
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: workspaces,
    livePollInterval: Duration.zero,
    jobRepository: NodeBackedJobRepository(
      channel: buildSimulatedChannel(simulated.answer),
      workspaceRepository: workspaces,
      clock: const SystemClock(),
    ),
  );
  return (node: simulated, repository: repository);
}

Future<Run> _startRun(Random random, _Fixture fixture) async {
  final Task task = await fixture.repository.createTask(
    randomTaskDraft(random),
  );
  return fixture.repository.startTask(task.id);
}

Future<void> _waitUntil(bool Function() isReached) async {
  for (int i = 0; i < _waitLimit; i += 1) {
    if (isReached()) {
      return;
    }
    await Future<void>.delayed(_waitStep);
  }
  fail('the live run did not catch up in time');
}

void main() {
  test('test_watch_run_property_live_lines_reach_the_run', () async {
    final Random random = seededRandom(10081);
    for (int i = 0; i < _liveIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final Run run = await _startRun(random, fixture);
      final int lineCount = 1 + random.nextInt(_largestEventCount);
      final List<WireRecord> events = <WireRecord>[];
      for (int line = 0; line < lineCount; line += 1) {
        final WireRecord logLine = randomLogLineJson(random);
        logLine['text'] = 'live line $line';
        events.add(<String, Object?>{'kind': 'log_appended', 'line': logLine});
      }
      fixture.node.liveLinks[run.id.value] = 'relay';
      fixture.node.liveEvents[run.id.value] = events;

      fixture.repository.watchRun(run.id);
      await _waitUntil(
        () => fixture.repository.findRun(run.id).log.length == lineCount,
      );
      fixture.repository.stopWatchingRun(run.id);
      await _waitUntil(() => fixture.node.stoppedRuns.contains(run.id.value));

      final Run watched = fixture.repository.findRun(run.id);
      expect(watched.link, RunnerLink.relay);
      expect(watched.log.map((LogLine line) => line.text), <String>[
        for (int line = 0; line < lineCount; line += 1) 'live line $line',
      ]);
      fixture.repository.dispose();
    }
  });

  test('test_stop_watching_run_property_last_watcher_stops_it', () async {
    final Random random = seededRandom(10082);
    for (int i = 0; i < _liveIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final Run run = await _startRun(random, fixture);
      final int watcherCount = 1 + random.nextInt(_largestEventCount);

      for (int watcher = 0; watcher < watcherCount; watcher += 1) {
        fixture.repository.watchRun(run.id);
      }
      for (int watcher = 1; watcher < watcherCount; watcher += 1) {
        fixture.repository.stopWatchingRun(run.id);
      }
      await Future<void>.delayed(_waitStep);
      expect(fixture.node.stoppedRuns, isEmpty);

      fixture.repository.stopWatchingRun(run.id);
      await _waitUntil(() => fixture.node.stoppedRuns.isNotEmpty);
      await Future<void>.delayed(_waitStep);
      expect(fixture.node.stoppedRuns, <String>[run.id.value]);
      fixture.repository.dispose();
    }
  });
}
