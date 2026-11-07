import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';

RepositoryDraft _randomRepositoryDraft(Random random) {
  return RepositoryDraft(
    address: randomHostileText(random),
    defaultBranch: randomHostileText(random),
  );
}

List<RepositoryDraft> _randomRepositoryDrafts(Random random) {
  final List<RepositoryDraft> repositories = <RepositoryDraft>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    repositories.add(_randomRepositoryDraft(random));
  }
  return repositories;
}

DraftedProject _randomDraftedProject(Random random) {
  return DraftedProject(
    name: randomHostileText(random),
    repositories: _randomRepositoryDrafts(random),
    agentAccess: pickOne(random, AgentAccess.values),
    approvalPolicy: randomInheritableApprovalPolicy(random),
  );
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<DraftedProject>(
      testNamePrefix: 'test_drafted_project_constructor_property',
      seed: 690901,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        _randomRepositoryDrafts(random),
        pickOne(random, AgentAccess.values),
        randomInheritableApprovalPolicy(random),
      ],
      construct: (ModelFieldValues fieldValues) => DraftedProject(
        name: fieldValues[0]! as String,
        repositories: fieldValues[1]! as List<RepositoryDraft>,
        agentAccess: fieldValues[2]! as AgentAccess,
        approvalPolicy: fieldValues[3] as ApprovalPolicy?,
      ),
      readFieldValues: (DraftedProject project) => <Object?>[
        project.name,
        project.repositories,
        project.agentAccess,
        project.approvalPolicy,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<DraftedProject, RepositoryDraft>(
      testNamePrefix: 'test_drafted_project_constructor_property_repositories',
      seed: 690911,
      buildElement: _randomRepositoryDraft,
      construct: (Random random, List<RepositoryDraft> repositories) =>
          DraftedProject(
            name: randomHostileText(random),
            repositories: repositories,
            agentAccess: pickOne(random, AgentAccess.values),
            approvalPolicy: null,
          ),
      readList: (DraftedProject project) => project.repositories,
    ),
  );

  test('test_to_project_draft_property_keeps_name_policy_and_workspace', () {
    final Random random = seededRandom(690921);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedProject drafted = _randomDraftedProject(random);
      final WorkspaceId workspaceId = randomWorkspaceId(random);

      final ProjectDraft project = drafted.toProjectDraft(workspaceId);

      expect(project.workspaceId, workspaceId);
      expect(project.name, drafted.name);
      expect(project.approvalPolicy, drafted.approvalPolicy);
    }
  });

  test(
    'test_to_project_draft_property_repositories_keep_order_and_access',
    () {
      final Random random = seededRandom(690922);

      for (int i = 0; i < propertyIterations; i += 1) {
        final DraftedProject drafted = _randomDraftedProject(random);

        final ProjectDraft project = drafted.toProjectDraft(
          randomWorkspaceId(random),
        );

        expect(project.repositories, hasLength(drafted.repositories.length));
        for (int j = 0; j < drafted.repositories.length; j += 1) {
          final RepositoryDraft given = drafted.repositories[j];
          final Repository made = project.repositories[j];
          expect(made.address, given.address);
          expect(made.defaultBranch, given.defaultBranch);
          expect(made.agentAccess, drafted.agentAccess);
        }
      }
    },
  );

  test('test_to_project_draft_property_result_is_frozen_and_repeatable', () {
    final Random random = seededRandom(690923);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedProject drafted = _randomDraftedProject(random);
      final WorkspaceId workspaceId = randomWorkspaceId(random);

      final ProjectDraft first = drafted.toProjectDraft(workspaceId);
      final ProjectDraft second = drafted.toProjectDraft(workspaceId);

      expect(first.repositories.clear, throwsUnsupportedError);
      expect(second.repositories, hasLength(first.repositories.length));
      expect(drafted.repositories, hasLength(first.repositories.length));
    }
  });
}
