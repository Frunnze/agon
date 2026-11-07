import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/task_listing_descriptions.dart';
import 'support/task_repository_rig.dart';

const int _rigIterations = 20;
const int _stepsPerRig = 8;

void main() {
  test('test_refresh_run_and_tasks_property_task_status_follows_an_outside_'
      'run_change', () async {
    final Random random = seededRandom(51807);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Run> runs = listEveryListedRun(rig.tasks);
      for (int step = 0; step < _stepsPerRig && runs.isNotEmpty; step += 1) {
        final Run run = pickOne(random, runs);
        rig.node.changeRunFromElsewhere(random, run.id.value);
        await rig.tasks.applyChange(node.RunChanged(runId: run.id));

        expect(
          describeListedStatuses(rig),
          describeSimulatedStatuses(rig.node),
        );
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_refresh_run_and_tasks_property_new_outside_run_is_listed_'
      'under_its_task', () async {
    final Random random = seededRandom(51808);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Task> listed = rig.tasks.listTasks();
      if (listed.isEmpty) {
        closeTaskRepositoryRig(rig);
        continue;
      }
      final Task task = pickOne(random, listed);
      final String runId = rig.node.addRunFromElsewhere(random, task.id.value);

      await rig.tasks.applyChange(node.RunChanged(runId: RunId(runId)));

      final Set<String> listedRunIds = <String>{
        for (final Run run in rig.tasks.listRuns(task.id)) run.id.value,
      };
      expect(listedRunIds, contains(runId));
      expect(
        rig.tasks.findTask(task.id).status,
        findSimulatedTaskStatus(rig.node, task.id.value),
      );
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_refresh_run_and_tasks_property_cancel_and_retry_update_the_'
      'listing', () async {
    final Random random = seededRandom(51809);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final Task task = await rig.tasks.createTask(randomTaskDraft(random));
      final Run run = await rig.tasks.startTask(task.id);

      for (int step = 0; step < 4; step += 1) {
        if (step.isEven) {
          await rig.tasks.cancelRun(run.id);
        } else {
          await rig.tasks.retryRun(run.id);
        }
        expect(
          describeListedStatuses(rig),
          describeSimulatedStatuses(rig.node),
        );
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_reload_tasks_property_listing_matches_the_node_after_each_'
      'edit', () async {
    final Random random = seededRandom(51810);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      for (int step = 0; step < _stepsPerRig; step += 1) {
        await takeRandomTaskEdit(random, rig);

        expect(
          describeListedStatuses(rig),
          describeSimulatedStatuses(rig.node),
        );
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_reload_tasks_property_each_edit_notifies_listeners', () async {
    final Random random = seededRandom(51811);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      int notifications = 0;
      rig.tasks.addListener(() => notifications += 1);

      for (int step = 0; step < _stepsPerRig; step += 1) {
        final int before = notifications;
        await takeRandomTaskEdit(random, rig);
        expect(notifications, greaterThan(before));
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_reload_tasks_property_refused_edit_keeps_the_listing', () async {
    final Random random = seededRandom(51812);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<String> before = describeRigListing(rig);
      rig.node.refusal = 'refused ${randomWordPhrase(random)}';
      int notifications = 0;
      rig.tasks.addListener(() => notifications += 1);

      await expectLater(
        takeRandomTaskEdit(random, rig),
        throwsA(isA<StateError>()),
      );

      expect(describeRigListing(rig), before);
      expect(notifications, 0);
      closeTaskRepositoryRig(rig);
    }
  });
}
