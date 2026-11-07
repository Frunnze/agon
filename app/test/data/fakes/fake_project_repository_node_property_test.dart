import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/project_inputs.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_project_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 10;
const int _largestSeededCount = 3;

typedef _Pair = ({
  FakeProjectRepository fake,
  NodeBackedProjectRepository nodeBacked,
});

bool _isProjectRefusal(Object error) {
  return error is StateError ||
      error is ArgumentError ||
      error is RecordNotFound;
}

String _describeRepository(Repository repository) {
  final String access = repository.agentAccess.name;
  return '${repository.address} ${repository.defaultBranch} $access';
}

String _describeProject(Project project) {
  final List<String> repositories = <String>[
    for (final Repository repository in project.repositories)
      _describeRepository(repository),
  ];
  return '${project.name} ${project.approvalPolicy} $repositories';
}

List<String> _describeListing(ProjectRepository repository) {
  return <String>[
    for (final Project project in repository.listProjects(harnessWorkspaceId))
      _describeProject(project),
  ];
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int seededCount = random.nextInt(_largestSeededCount + 1);
  for (int i = 0; i < seededCount; i += 1) {
    simulated.projects.add(<String, Object?>{
      'id': simulated.nextIdentifier('project'),
      'workspace_id': harnessWorkspaceId.value,
      'name': 'seeded-$i',
      'repositories': <Object?>[
        for (final Repository repository in randomDistinctRepositories(random))
          mapRepositoryToNode(repository).toJson(),
      ],
      'approval_policy': null,
    });
  }
  final NodeBackedProjectRepository nodeBacked = NodeBackedProjectRepository(
    channel: simulated.channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
  );
  await nodeBacked.load();
  final FakeProjectRepository fake = FakeProjectRepository(
    projects: nodeBacked.listProjects(harnessWorkspaceId),
    taskWork: buildEmptyTaskWork(),
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

ProjectId _pickProjectId(ProjectRepository repository, int at) {
  final List<Project> listed = repository.listProjects(harnessWorkspaceId);
  if (at >= listed.length) {
    return const ProjectId('project-missing');
  }
  return listed[at].id;
}

String _pickAddress(Random random, Project? project) {
  if (project == null || project.repositories.isEmpty || random.nextBool()) {
    return randomCanonicalAddress(random);
  }
  return pickOne(random, project.repositories).address;
}

enum _Operation {
  createProject('create_project'),
  addRepository('add_repository'),
  removeRepository('remove_repository'),
  deleteProject('delete_project');

  const _Operation(this.methodName);

  final String methodName;
}

typedef _PlannedStep = ({
  _Operation operation,
  int at,
  ProjectDraft draft,
  Repository repository,
  String? removedAddress,
});

_PlannedStep _planStep(Random random, _Pair pair, _Operation focus) {
  final List<Project> listed = pair.nodeBacked.listProjects(
    harnessWorkspaceId,
  );
  final int at = random.nextInt(listed.length + 1);
  final Project? picked = at < listed.length ? listed[at] : null;
  final bool hasRepositories =
      picked != null && picked.repositories.isNotEmpty;
  final String? removedAddress = hasRepositories
      ? pickOne(random, picked.repositories).address
      : null;
  final ProjectDraft draft = ProjectDraft(
    workspaceId: harnessWorkspaceId,
    name: pickOne(random, <String>[
      'project-${random.nextInt(100)}',
      randomWordPhrase(random),
    ]),
    repositories: randomDistinctRepositories(random),
    approvalPolicy: pickOne(random, inheritableApprovalPolicies),
  );
  final _Operation operation = random.nextInt(3) == 0
      ? _Operation.createProject
      : focus;
  return (
    operation: operation,
    at: at,
    draft: draft,
    repository: randomRepositoryAt(random, _pickAddress(random, picked)),
    removedAddress: removedAddress,
  );
}

Future<Object?> _applyStep(ProjectRepository target, _PlannedStep step) {
  final ProjectId projectId = _pickProjectId(target, step.at);
  final String? removedAddress = step.removedAddress;
  return switch (step.operation) {
    _Operation.createProject => target.createProject(step.draft),
    _Operation.addRepository => target.addRepository(
      projectId,
      step.repository,
    ),
    _Operation.removeRepository when removedAddress != null =>
      target.removeRepository(projectId, removedAddress),
    _Operation.removeRepository => target.addRepository(
      projectId,
      step.repository,
    ),
    _Operation.deleteProject => target.deleteProject(projectId),
  };
}

Future<void> _runOnBoth(Random random, _Pair pair, _Operation focus) async {
  final _PlannedStep step = _planStep(random, pair, focus);

  final bool isFakeRefused = await isRefused(
    () => _applyStep(pair.fake, step),
    isRefusal: _isProjectRefusal,
  );
  final bool isNodeRefused = await isRefused(
    () => _applyStep(pair.nodeBacked, step),
    isRefusal: _isProjectRefusal,
  );

  expect(isFakeRefused, isNodeRefused, reason: '$step');
}

Future<void> _checkAgreement({
  required _Operation focus,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      await _runOnBoth(random, pair, focus);

      expect(
        _describeListing(pair.fake),
        orderedEquals(_describeListing(pair.nodeBacked)),
      );
    }
    pair.nodeBacked.dispose();
  }
}

void main() {
  for (final _Operation operation in _Operation.values) {
    test('${_typePrefix}_${operation.methodName}_property_agrees_with_the_'
        'node_backed_repository', () async {
      await _checkAgreement(focus: operation, seed: 65901 + operation.index);
    });
  }
}
