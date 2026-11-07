import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_inputs.dart';

WorkspaceId _randomUnknownId(Random random) {
  return WorkspaceId('unknown ${randomText(random)}');
}

void main() {
  test('test_find_workspace_property_every_lookup_refuses_unknown', () async {
    final Random random = seededRandom(67913);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final FakeWorkspaceRepository repository = seeded.repository;
      final WorkspaceId unknown = _randomUnknownId(random);
      final Matcher isNotFound = throwsA(isA<RecordNotFound>());

      await expectLater(repository.switchWorkspace(unknown), isNotFound);
      await expectLater(
        repository.saveProtectedFiles(
          workspaceId: unknown,
          patterns: randomPatterns(random),
        ),
        isNotFound,
      );
      await expectLater(repository.resetProtectedFiles(unknown), isNotFound);
      await expectLater(
        repository.changeApprovalPolicy(
          workspaceId: unknown,
          approvalPolicy: pickOne(random, ApprovalPolicy.values),
        ),
        isNotFound,
      );
      await expectLater(repository.deleteWorkspace(unknown), isNotFound);
      expect(repository.listWorkspaces(), orderedEquals(seeded.workspaces));
    }
  });

  test('test_find_workspace_property_ids_match_exactly', () async {
    final Random random = seededRandom(67914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final String spelling = pickOne(random, <String>[
        ' ${target.id.value}',
        '${target.id.value} ',
        target.id.value.toUpperCase(),
      ]);

      await expectLater(
        seeded.repository.switchWorkspace(WorkspaceId(spelling)),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_find_workspace_property_finds_created_ones', () async {
    final Random random = seededRandom(67915);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace created = await seeded.repository.createWorkspace(
        name: 'team-$i',
      );

      final Workspace switched = await seeded.repository.switchWorkspace(
        created.id,
      );

      expect(switched, same(created));
    }
  });
}
