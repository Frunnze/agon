import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/notification_counter.dart';
import '../fakes/support/workspace_work_checks.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/job_repository_fixtures.dart';
import 'support/simulated_work_node.dart';

const String _typePrefix = 'test_node_backed_job_repository';
const int _iterations = 25;

void _ignoreChange() {}

List<String> _listAskedSince(WorkspaceWorkRig rig, int asked) {
  return rig.simulated.work.receivedCommands.skip(asked).toList();
}

Set<String> _listJobIdsIn(WorkspaceWorkRig rig, WorkspaceId workspaceId) {
  return <String>{
    for (final WireRecord task in rig.simulated.work.tasks.values)
      if (isJob(task) &&
          rig.simulated.projectWorkspaces[task['project_id']] ==
              workspaceId.value)
        task['id']! as String,
  };
}

void _closeAfterDispose(WorkspaceWorkRig rig) {
  rig.nodeTasks.dispose();
  rig.fakeTasks.dispose();
}

void main() {
  test(
    '${_typePrefix}_apply_change_property_other_areas_ask_nothing',
    () async {
      final Random random = seededRandom(77311);
      for (int i = 0; i < _iterations; i += 1) {
        final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
        addOutsideWork(random, fixture.node);

        for (final node.ChangeArea area in node.ChangeArea.values) {
          if (area != node.ChangeArea.tasks) {
            await fixture.repository.applyChange(node.AreaChanged(area: area));
          }
        }

        expect(fixture.sentCommands, isEmpty);
        expect(fixture.repository.listJobs(), isEmpty);
      }
    },
  );

  test('${_typePrefix}_apply_change_property_run_changes_follow_the_'
      'node', () async {
    final Random random = seededRandom(77314);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
      addOutsideWork(random, fixture.node);

      await fixture.repository.applyChange(
        node.RunChanged(runId: RunId(randomText(random))),
      );

      expect(
        listRepositoryJobIds(fixture.repository),
        listSimulatedJobIds(fixture.node),
      );
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_lists_the_new_'
      'workspace', () async {
    final Random random = seededRandom(77315);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final WorkspaceId target = pickOne(random, rig.workspaceIds);

      await rig.workspaces.switchWorkspace(target);
      await pumpEventQueue();

      expect(listRepositoryJobIds(rig.nodeJobs), _listJobIdsIn(rig, target));
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_swallows_node_'
      'failures', () async {
    final Random random = seededRandom(77316);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<String> before = describeNodeJobs(rig);
      rig.simulated.work.refusal = 'the node is down ${randomText(random)}';

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(describeNodeJobs(rig), before);
      rig.simulated.work.refusal = null;
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_settles_on_the_'
      'last_switch', () async {
    final Random random = seededRandom(77317);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final int switches = 2 + random.nextInt(4);

      for (int step = 0; step < switches; step += 1) {
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
      }
      await pumpEventQueue();

      expect(describeNodeJobs(rig), unorderedEquals(describeFakeJobs(rig)));
      await closeWorkspaceWorkRig(rig);
    }
  });

  test(
    '${_typePrefix}_dispose_property_stops_reloading_on_switches',
    () async {
      final Random random = seededRandom(77312);
      for (int i = 0; i < _iterations; i += 1) {
        final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
        final List<String> before = describeNodeJobs(rig);
        rig.nodeJobs.dispose();
        final int asked = rig.simulated.work.receivedCommands.length;

        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
        await pumpEventQueue();

        expect(_listAskedSince(rig, asked), isNot(contains('list_jobs')));
        expect(describeNodeJobs(rig), before);
        _closeAfterDispose(rig);
      }
    },
  );

  test('${_typePrefix}_dispose_property_keeps_other_listeners', () async {
    final Random random = seededRandom(77313);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final NotificationCounter counter = NotificationCounter();
      rig.workspaces.addListener(counter.record);
      rig.nodeJobs.dispose();

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(counter.count, 1);
      _closeAfterDispose(rig);
    }
  });

  test('${_typePrefix}_dispose_property_refuses_new_listeners', () {
    final Random random = seededRandom(77318);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
      fixture.repository.dispose();

      expect(
        () => fixture.repository.addListener(_ignoreChange),
        throwsFlutterError,
      );
      expect(fixture.sentCommands, isEmpty);
    }
  });
}
