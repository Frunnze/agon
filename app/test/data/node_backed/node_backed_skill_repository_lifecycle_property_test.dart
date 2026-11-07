import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/notification_counter.dart';
import 'support/node_backed_harness.dart';
import 'support/runner_repository_rig.dart' show openWorkspacelessRepository;
import 'support/skill_repository_rig.dart';

const String _typePrefix = 'test_node_backed_skill_repository';
const int _iterations = 30;
const List<int> _refusalStatuses = <int>[400, 403, 404, 409, 503];

void _ignoreChange() {}

void _disposeSkillsOnly(SkillRig rig) {
  rig.skills.removeListener(rig.notifications.record);
  rig.skills.dispose();
}

void main() {
  test('${_typePrefix}_dispose_property_stops_reloading_on_'
      'switches', () async {
    final Random random = seededRandom(81321);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      _disposeSkillsOnly(rig);

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(rig.node.countCommands(listSkillsCommand), 0);
      rig.workspaces.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_keeps_other_listeners', () async {
    final Random random = seededRandom(81322);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final NotificationCounter counter = NotificationCounter();
      rig.workspaces.addListener(counter.record);
      _disposeSkillsOnly(rig);

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(counter.count, 1);
      rig.workspaces.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_refuses_new_listeners', () async {
    final Random random = seededRandom(81323);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      _disposeSkillsOnly(rig);

      expect(() => rig.skills.addListener(_ignoreChange), throwsFlutterError);
      expect(rig.node.countCommands(listSkillsCommand), 0);
      rig.workspaces.dispose();
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_lists_the_new_'
      'workspace', () async {
    final Random random = seededRandom(81324);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await rig.skills.load();
      final WorkspaceId target = pickOne(random, rig.workspaceIds);
      rig.node.catalog.addSkill(workspaceId: target.value, name: 'new-$i');

      await rig.workspaces.switchWorkspace(target);
      await pumpEventQueue();

      expect(listShownSkillIds(rig), rig.node.listSkillIdsIn(target));
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_settles_on_the_'
      'last_switch', () async {
    final Random random = seededRandom(81325);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final int switches = 2 + random.nextInt(4);

      for (int step = 0; step < switches; step += 1) {
        rig.node.catalog.addSkill(
          workspaceId: pickOne(random, rig.workspaceIds).value,
          name: 'step-$step',
        );
        unawaited(
          rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds)),
        );
      }
      await pumpEventQueue();

      expect(listShownSkillIds(rig), listNodeSkillIdsHere(rig));
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_swallows_node_'
      'failures', () async {
    final Random random = seededRandom(81326);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await rig.skills.load();
      final List<Skill> before = rig.skills.listSkills();
      final List<Object> escaped = <Object>[];

      rig.node.refusal = 'the node is down ${randomText(random)}';

      runZonedGuarded(
        () => unawaited(
          rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds)),
        ),
        (Object problem, StackTrace _) => escaped.add(problem),
      );
      await pumpEventQueue();

      expect(escaped, isEmpty);
      expect(identical(rig.skills.listSkills(), before), isTrue);
      rig.node.refusal = null;
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_load_skills_property_no_workspace_asks_'
      'nothing', () async {
    final Random random = seededRandom(81327);

    for (int i = 0; i < _iterations; i += 1) {
      final RustLikeSkillNode simulated = RustLikeSkillNode();
      final String workspaceId =
          simulated.catalog.addWorkspace('elsewhere')['id']! as String;
      simulated.catalog.addSkill(
        workspaceId: workspaceId,
        name: 'far-${random.nextInt(1000)}',
      );
      final WorkspaceRepository workspaces =
          await openWorkspacelessRepository();
      final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
        channel: buildSimulatedChannel(simulated.answer),
        workspaceRepository: workspaces,
      );

      await skills.load();
      await skills.applyChange(
        const node.AreaChanged(area: node.ChangeArea.skills),
      );

      expect(skills.listSkills(), isEmpty);
      expect(simulated.receivedCommands, isEmpty);
      skills.dispose();
    }
  });

  test('${_typePrefix}_load_skills_property_asks_for_the_current_'
      'workspace_every_time', () async {
    final Random random = seededRandom(81328);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);

      for (int step = 0; step < 4; step += 1) {
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
        await pumpEventQueue();

        expect(listShownSkillIds(rig), listNodeSkillIdsHere(rig));
      }
      expect(rig.node.countCommands(listSkillsCommand), 4);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_load_skills_property_app_server_refusals_are_typed_'
      'and_keep_the_listing', () async {
    final Random random = seededRandom(81329);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await rig.skills.load();
      final List<Skill> before = rig.skills.listSkills();
      final int notified = rig.notifications.count;
      final int status = pickOne(random, _refusalStatuses);
      final String reason = 'refused ${randomText(random)}';
      rig.node.refusal = 'the app server answered $status: $reason';

      await expectLater(
        rig.skills.load(),
        throwsA(
          isA<AppServerRefusal>()
              .having(
                (AppServerRefusal error) => error.status,
                'status',
                status,
              )
              .having(
                (AppServerRefusal error) => error.message,
                'message',
                reason,
              ),
        ),
      );

      expect(identical(rig.skills.listSkills(), before), isTrue);
      expect(rig.notifications.count, notified);
      rig.node.refusal = null;
      closeSkillRig(rig);
    }
  });
}
