import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/task_repository_rig.dart';

const int _watchIterations = 10;
const int _largestWatcherCount = 5;
const int _waitLimit = 400;
const Duration _waitStep = Duration(milliseconds: 1);
const String _watchCommand = 'watch_run';

Future<void> _waitUntil(bool Function() isReached) async {
  for (int i = 0; i < _waitLimit; i += 1) {
    if (isReached()) {
      return;
    }
    await Future<void>.delayed(_waitStep);
  }
  fail('the live polling did not reach the expected point in time');
}

Future<void> _settle() async {
  for (int i = 0; i < 5; i += 1) {
    await Future<void>.delayed(_waitStep);
  }
}

Future<Run> _startRun(Random random, TaskRepositoryRig rig) async {
  final Task task = await rig.tasks.createTask(randomTaskDraft(random));
  return rig.tasks.startTask(task.id);
}

int _countWatches(TaskRepositoryRig rig) {
  return countReceivedCommands(rig.node, _watchCommand);
}

void main() {
  test('test_node_backed_task_repository_watch_run_property_extra_watchers_'
      'share_one_poll', () async {
    final Random random = seededRandom(51901);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final Run run = await _startRun(random, rig);
      final int watcherCount = 1 + random.nextInt(_largestWatcherCount);

      for (int watcher = 0; watcher < watcherCount; watcher += 1) {
        rig.tasks.watchRun(run.id);
      }
      await _settle();

      expect(_countWatches(rig), 1);
      for (int watcher = 0; watcher < watcherCount; watcher += 1) {
        rig.tasks.stopWatchingRun(run.id);
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_watch_run_property_views_of_unknown_'
      'runs_are_ignored', () async {
    final Random random = seededRandom(51902);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: Duration.zero,
      );
      final RunId unknown = RunId('unknown-${randomWordPhrase(random)}');
      rig.node.liveEvents[unknown.value] = <Map<String, Object?>>[
        <String, Object?>{
          'kind': 'log_appended',
          'line': randomLogLineJson(random),
        },
      ];
      int notifications = 0;
      rig.tasks.addListener(() => notifications += 1);

      rig.tasks.watchRun(unknown);
      await _waitUntil(() => _countWatches(rig) >= 2);
      rig.tasks.stopWatchingRun(unknown);

      expect(notifications, 0);
      expect(() => rig.tasks.findRun(unknown), throwsA(isA<RecordNotFound>()));
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_stop_watching_run_property_polling_'
      'stops', () async {
    final Random random = seededRandom(51903);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: Duration.zero,
      );
      final Run run = await _startRun(random, rig);

      rig.tasks.watchRun(run.id);
      await _waitUntil(() => _countWatches(rig) >= 2);
      rig.tasks.stopWatchingRun(run.id);
      await _waitUntil(() => rig.node.stoppedRuns.contains(run.id.value));
      await _settle();
      final int watchesAfterStop = _countWatches(rig);
      await _settle();

      expect(_countWatches(rig), watchesAfterStop);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_stop_watching_run_property_'
      'unwatched_run_never_polls', () async {
    final Random random = seededRandom(51904);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: Duration.zero,
      );
      final RunId runId = RunId('never-watched-${randomWordPhrase(random)}');

      rig.tasks.stopWatchingRun(runId);
      await _settle();

      expect(_countWatches(rig), 0);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_dispose_property_ignores_later_'
      'workspace_changes', () async {
    final Random random = seededRandom(51905);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      seedTasksWithRuns(random, rig.node);

      rig.tasks.dispose();
      await rig.workspaces.switchWorkspace(harnessWorkspaceId);
      await _settle();

      expect(countReceivedCommands(rig.node, 'list_tasks'), 0);
      rig.jobs.dispose();
    }
  });

  test('test_node_backed_task_repository_dispose_property_stops_live_'
      'polling', () async {
    final Random random = seededRandom(51906);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: Duration.zero,
      );
      final Run run = await _startRun(random, rig);
      rig.tasks.watchRun(run.id);
      await _waitUntil(() => _countWatches(rig) >= 2);

      rig.tasks.dispose();
      await _settle();
      final int watchesAfterDispose = _countWatches(rig);
      await _settle();

      expect(_countWatches(rig), watchesAfterDispose);
      rig.jobs.dispose();
    }
  });

  test('test_node_backed_task_repository_dispose_property_right_after_'
      'construction_sends_nothing', () async {
    final Random random = seededRandom(51907);
    for (int i = 0; i < _watchIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: Duration(milliseconds: random.nextInt(5)),
      );

      rig.tasks.dispose();
      await _settle();

      expect(rig.node.receivedCommands, isEmpty);
      rig.jobs.dispose();
    }
  });
}
