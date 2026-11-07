import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/skill_inputs.dart';
import 'support/workflow_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_skill_inputs.dart';
import 'support/workspace_workflow_inputs.dart';

typedef _ListingBuilder = ChangeNotifier Function(
  Random random,
  SeededWorkspaces workspaces,
);

typedef _ListingCase = ({String typeName, _ListingBuilder build});

ChangeNotifier _buildSkills(Random random, SeededWorkspaces workspaces) {
  return buildSkillRepositoryIn(
    randomSkillsScopedOver(random, listWorkspaceIds(workspaces.workspaces)),
    workspaces.repository,
  );
}

ChangeNotifier _buildWorkflows(Random random, SeededWorkspaces workspaces) {
  return buildWorkflowRepositoryIn(
    workflows: randomWorkflowsAvailableOver(
      random,
      listWorkspaceIds(workspaces.workspaces),
    ),
    changes: const <WorkflowChange>[],
    workspaceRepository: workspaces.repository,
  );
}

const List<_ListingCase> _cases = <_ListingCase>[
  (typeName: 'fake_skill_repository', build: _buildSkills),
  (typeName: 'fake_workflow_repository', build: _buildWorkflows),
];

Future<void> _switchRandomly(Random random, SeededWorkspaces workspaces) {
  final Workspace target = pickOne(random, workspaces.workspaces);
  return workspaces.repository.switchWorkspace(target.id);
}

void main() {
  for (int index = 0; index < _cases.length; index += 1) {
    final _ListingCase listing = _cases[index];

    test('test_${listing.typeName}_dispose_property_a_sibling_on_the_same_'
        'workspaces_keeps_following_them', () async {
      final Random random = seededRandom(93001 + index);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
        final ChangeNotifier disposed = listing.build(random, workspaces);
        final ChangeNotifier sibling = listing.build(random, workspaces);
        final NotificationCounter notifications = NotificationCounter();
        sibling.addListener(notifications.record);

        disposed.dispose();
        await _switchRandomly(random, workspaces);

        expect(notifications.count, 1);
        sibling.dispose();
      }
    });

    test('test_${listing.typeName}_dispose_property_switching_afterwards_'
        'never_throws', () async {
      final Random random = seededRandom(93011 + index);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
        final ChangeNotifier disposed = listing.build(random, workspaces);

        disposed.dispose();

        final int switchCount = 1 + random.nextInt(3);
        for (int step = 0; step < switchCount; step += 1) {
          await _switchRandomly(random, workspaces);
        }
        expect(workspaces.repository.listWorkspaces(), isNotEmpty);
      }
    });
  }
}
