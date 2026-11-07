import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

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

ModelFieldValues _randomProjectFields(Random random) {
  return <Object?>[
    randomProjectId(random),
    randomWorkspaceId(random),
    randomHostileText(random),
    _randomRepositories(random),
    randomInheritableApprovalPolicy(random),
  ];
}

Project _buildProject(ModelFieldValues fieldValues) {
  return Project(
    id: fieldValues[0]! as ProjectId,
    workspaceId: fieldValues[1]! as WorkspaceId,
    name: fieldValues[2]! as String,
    repositories: fieldValues[3]! as List<Repository>,
    approvalPolicy: fieldValues[4] as ApprovalPolicy?,
  );
}

Project _randomProject(Random random) {
  return _buildProject(_randomProjectFields(random));
}

ModelFieldValues _readFieldsBesidesRepositories(Project project) {
  return <Object?>[
    project.id,
    project.workspaceId,
    project.name,
    project.approvalPolicy,
  ];
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<Project>(
      testNamePrefix: 'test_project_constructor_property',
      seed: 691401,
      randomFieldValues: _randomProjectFields,
      construct: _buildProject,
      readFieldValues: (Project project) => <Object?>[
        project.id,
        project.workspaceId,
        project.name,
        project.repositories,
        project.approvalPolicy,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<Project, Repository>(
      testNamePrefix: 'test_project_constructor_property_repositories',
      seed: 691411,
      buildElement: _randomRepository,
      construct: (Random random, List<Repository> repositories) => Project(
        id: randomProjectId(random),
        workspaceId: randomWorkspaceId(random),
        name: randomHostileText(random),
        repositories: repositories,
        approvalPolicy: randomInheritableApprovalPolicy(random),
      ),
      readList: (Project project) => project.repositories,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Project, List<Repository>>(
      testNamePrefix: 'test_with_repositories_property',
      seed: 691421,
      randomModel: _randomProject,
      randomChange: _randomRepositories,
      applyChange: (Project project, List<Repository> repositories) =>
          project.withRepositories(repositories),
      readChangedField: (Project project) => project.repositories,
      readOtherFields: _readFieldsBesidesRepositories,
    ),
  );

  testListCopyProperties(
    ListCopy<Project, Repository>(
      testNamePrefix: 'test_with_repositories_property_repositories',
      seed: 691431,
      buildElement: _randomRepository,
      construct: (Random random, List<Repository> repositories) =>
          _randomProject(random).withRepositories(repositories),
      readList: (Project project) => project.repositories,
    ),
  );
}
