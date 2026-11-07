import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';

Repository _randomRepository(Random random) {
  return Repository(
    address: randomHostileText(random),
    defaultBranch: randomHostileText(random),
    agentAccess: pickOne(random, AgentAccess.values),
  );
}

List<Repository> _randomRepositories(Random random) {
  final List<Repository> repositories = <Repository>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    repositories.add(_randomRepository(random));
  }
  return repositories;
}

RepositoryDraft _randomRepositoryDraft(Random random) {
  return RepositoryDraft(
    address: randomHostileText(random),
    defaultBranch: randomHostileText(random),
  );
}

ModelFieldValues _readRepositoryFields(Repository repository) {
  return <Object?>[
    repository.address,
    repository.defaultBranch,
    repository.agentAccess,
  ];
}

void main() {
  const NodeEnumMapping<AgentAccess, node.AgentAccess> accessMapping =
      NodeEnumMapping<AgentAccess, node.AgentAccess>(
        testNamePrefix: 'test_agent_access_values_property',
        choices: AgentAccess.values,
        nodeChoices: node.AgentAccess.values,
        mapFromNode: mapAgentAccessFromNode,
      );
  testNodeEnumMappingProperties(accessMapping);
  testNodeEnumRoundTripProperty(accessMapping, mapAgentAccessToNode);

  testModelConstructorProperties(
    ModelConstructor<Repository>(
      testNamePrefix: 'test_repository_constructor_property',
      seed: 691301,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
        pickOne(random, AgentAccess.values),
      ],
      construct: (ModelFieldValues fieldValues) => Repository(
        address: fieldValues[0]! as String,
        defaultBranch: fieldValues[1]! as String,
        agentAccess: fieldValues[2]! as AgentAccess,
      ),
      readFieldValues: _readRepositoryFields,
    ),
  );

  test('test_repository_constructor_property_round_trips_the_node', () {
    final Random random = seededRandom(691311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repository = _randomRepository(random);

      final Repository roundTripped = mapRepositoryFromNode(
        mapRepositoryToNode(repository),
      );

      expect(
        _readRepositoryFields(roundTripped),
        _readRepositoryFields(repository),
      );
    }
  });

  testModelConstructorProperties(
    ModelConstructor<RepositoryDraft>(
      testNamePrefix: 'test_repository_draft_constructor_property',
      seed: 691321,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => RepositoryDraft(
        address: fieldValues[0]! as String,
        defaultBranch: fieldValues[1]! as String,
      ),
      readFieldValues: (RepositoryDraft draft) => <Object?>[
        draft.address,
        draft.defaultBranch,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<CheckedFolder>(
      testNamePrefix: 'test_checked_folder_constructor_property',
      seed: 691331,
      randomFieldValues: (Random random) => <Object?>[
        _randomRepositoryDraft(random),
        random.nextBool(),
      ],
      construct: (ModelFieldValues fieldValues) => CheckedFolder(
        repository: fieldValues[0]! as RepositoryDraft,
        hasStartedGit: fieldValues[1]! as bool,
      ),
      readFieldValues: (CheckedFolder folder) => <Object?>[
        folder.repository,
        folder.hasStartedGit,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ProjectDraft>(
      testNamePrefix: 'test_project_draft_constructor_property',
      seed: 691341,
      randomFieldValues: (Random random) => <Object?>[
        randomWorkspaceId(random),
        randomHostileText(random),
        _randomRepositories(random),
        randomInheritableApprovalPolicy(random),
      ],
      construct: (ModelFieldValues fieldValues) => ProjectDraft(
        workspaceId: fieldValues[0]! as WorkspaceId,
        name: fieldValues[1]! as String,
        repositories: fieldValues[2]! as List<Repository>,
        approvalPolicy: fieldValues[3] as ApprovalPolicy?,
      ),
      readFieldValues: (ProjectDraft draft) => <Object?>[
        draft.workspaceId,
        draft.name,
        draft.repositories,
        draft.approvalPolicy,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<ProjectDraft, Repository>(
      testNamePrefix: 'test_project_draft_constructor_property_repositories',
      seed: 691351,
      buildElement: _randomRepository,
      construct: (Random random, List<Repository> repositories) =>
          ProjectDraft(
            workspaceId: randomWorkspaceId(random),
            name: randomHostileText(random),
            repositories: repositories,
            approvalPolicy: randomInheritableApprovalPolicy(random),
          ),
      readList: (ProjectDraft draft) => draft.repositories,
    ),
  );
}
