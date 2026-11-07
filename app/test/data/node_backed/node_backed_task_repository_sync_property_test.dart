import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/simulated_work_node.dart';
import 'support/task_listing_descriptions.dart';
import 'support/task_repository_rig.dart';

const int _rigIterations = 20;

Set<String> _listedIds(List<Task> tasks) {
  return <String>{for (final Task task in tasks) task.id.value};
}

void main() {
  test('test_node_backed_task_repository_load_property_reloading_changes_'
      'nothing', () async {
    final Random random = seededRandom(51801);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<String> first = describeRigListing(rig);

      await rig.tasks.load();

      expect(describeRigListing(rig), first);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_apply_change_property_run_change_'
      'updates_the_run_and_its_task', () async {
    final Random random = seededRandom(51802);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Run> runs = listEveryListedRun(rig.tasks);
      if (runs.isEmpty) {
        closeTaskRepositoryRig(rig);
        continue;
      }
      final Run run = pickOne(random, runs);
      rig.node.changeRunFromElsewhere(random, run.id.value);

      await rig.tasks.applyChange(node.RunChanged(runId: run.id));

      final WireRecord wireRun = rig.node.runs[run.id.value]!;
      final Run refreshed = rig.tasks.findRun(run.id);
      expect(
        refreshed.chat.length,
        (wireRun['chat']! as List<Object?>).length,
      );
      expect(
        rig.tasks.findTask(run.taskId).status,
        findSimulatedTaskStatus(rig.node, run.taskId.value),
      );
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_refresh_run_property_returns_the_'
      'node_run_and_notifies_once', () async {
    final Random random = seededRandom(51803);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Run> runs = listEveryListedRun(rig.tasks);
      if (runs.isEmpty) {
        closeTaskRepositoryRig(rig);
        continue;
      }
      final RunId runId = pickOne(random, runs).id;
      rig.node.changeRunFromElsewhere(random, runId.value);
      int notifications = 0;
      rig.tasks.addListener(() => notifications += 1);

      final Run refreshed = await rig.tasks.refreshRun(runId);

      final WireRecord wireRun = rig.node.runs[runId.value]!;
      expect(refreshed.id, runId);
      expect(refreshed.number, wireRun['number']);
      expect(
        refreshed.chat.length,
        (wireRun['chat']! as List<Object?>).length,
      );
      expect(rig.tasks.findRun(runId), same(refreshed));
      expect(notifications, 1);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_refresh_run_property_unknown_run_'
      'is_record_not_found_and_stores_nothing', () async {
    final Random random = seededRandom(51804);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<String> before = describeRigListing(rig);
      final RunId unknown = RunId('unknown-${randomWordPhrase(random)}');

      await expectLater(
        rig.tasks.refreshRun(unknown),
        throwsA(isA<RecordNotFound>()),
      );

      expect(describeRigListing(rig), before);
      expect(() => rig.tasks.findRun(unknown), throwsA(isA<RecordNotFound>()));
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_load_after_workspace_change_property_switch_shows_the_new_'
      'workspace_tasks', () async {
    final Random random = seededRandom(51805);
    for (int i = 0; i < _rigIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final WorkspaceId target = pickOne(random, rig.workspaceIds);

      await rig.workspaces.switchWorkspace(target);
      await pumpEventQueue();

      expect(
        _listedIds(rig.nodeTasks.listTasks()),
        _listedIds(rig.fakeTasks.listTasks()),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('test_load_after_workspace_change_property_rapid_switches_end_on_'
      'the_last_workspace', () async {
    final Random random = seededRandom(51806);
    for (int i = 0; i < _rigIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final int switchCount = 2 + random.nextInt(4);

      for (int step = 0; step < switchCount; step += 1) {
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
      }
      await pumpEventQueue();

      expect(
        _listedIds(rig.nodeTasks.listTasks()),
        _listedIds(rig.fakeTasks.listTasks()),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });
}
