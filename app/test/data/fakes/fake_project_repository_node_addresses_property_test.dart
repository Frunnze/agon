import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/project_inputs.dart';

const int _sequenceIterations = 40;
const int _longestSequence = 10;
const String _acceptedKind = 'accepted';
const String _nodeRefusalKind = 'node';
const String _missingRecordKind = 'missing';
const String _localRefusalKind = 'refused';
const Set<String> _everyKind = <String>{
  _acceptedKind,
  _nodeRefusalKind,
  _missingRecordKind,
  _localRefusalKind,
};

enum _Step { addRepository, removeRepository, createProject }

typedef _Pair = ({
  FakeProjectRepository fake,
  NodeBackedProjectRepository nodeBacked,
});

typedef _PlannedStep = ({
  _Step step,
  int at,
  String address,
  ProjectDraft draft,
});

String _describeAccepted(Object? outcome) => _acceptedKind;

bool _isRefusal(Object problem) {
  return problem is StateError ||
      problem is ArgumentError ||
      problem is RecordNotFound;
}

String _describeRefusal(Object problem) {
  if (problem is AppServerRefusal) {
    return '$_nodeRefusalKind ${problem.status} ${problem.message}';
  }
  if (problem is RecordNotFound) {
    return '$_missingRecordKind ${problem.kind} ${problem.identifier}';
  }
  return _localRefusalKind;
}

Future<String> _observe(Future<Object?> Function() action) {
  final Future<String> accepted = action().then(_describeAccepted);
  return accepted.catchError(_describeRefusal, test: _isRefusal);
}

String _readKind(String outcome) => outcome.split(' ').first;

List<String> _describeListing(ProjectRepository repository) {
  return <String>[
    for (final Project project in repository.listProjects(harnessWorkspaceId))
      '${project.name} ${listAddresses(project)}',
  ];
}

Future<_Pair> _buildPair() async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
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

String _pickAddress(Random random, List<Project> listed, int at) {
  final bool hasProject = at < listed.length;
  final int choice = random.nextInt(4);
  if (hasProject && listed[at].repositories.isNotEmpty && choice < 2) {
    final String listedAddress = pickOne(
      random,
      listed[at].repositories,
    ).address;
    return spellAddressDifferently(random, listedAddress);
  }
  if (choice == 2) {
    return randomText(random);
  }
  return spellAddressDifferently(random, randomCanonicalAddress(random));
}

_PlannedStep _planStep(Random random, _Pair pair) {
  final List<Project> listed = pair.nodeBacked.listProjects(
    harnessWorkspaceId,
  );
  final int at = random.nextInt(listed.length + 1);
  final List<Repository> repositories = <Repository>[
    for (final Repository repository in randomDistinctRepositories(random))
      randomRepositoryAt(
        random,
        spellAddressDifferently(random, repository.address),
      ),
  ];
  return (
    step: pickOne(random, _Step.values),
    at: at,
    address: _pickAddress(random, listed, at),
    draft: ProjectDraft(
      workspaceId: harnessWorkspaceId,
      name: 'project-${random.nextInt(1000)}',
      repositories: repositories,
      approvalPolicy: null,
    ),
  );
}

ProjectId _pickProjectId(ProjectRepository repository, int at) {
  final List<Project> listed = repository.listProjects(harnessWorkspaceId);
  if (at >= listed.length) {
    return const ProjectId('project-missing');
  }
  return listed[at].id;
}

Future<Object?> _apply(ProjectRepository target, _PlannedStep planned) {
  final ProjectId projectId = _pickProjectId(target, planned.at);
  return switch (planned.step) {
    _Step.addRepository => target.addRepository(
      projectId,
      Repository(
        address: planned.address,
        defaultBranch: 'main',
        agentAccess: AgentAccess.values.first,
      ),
    ),
    _Step.removeRepository => target.removeRepository(
      projectId,
      planned.address,
    ),
    _Step.createProject => target.createProject(planned.draft),
  };
}

void main() {
  test('test_fake_project_repository_remove_repository_property_agrees_'
      'with_the_node_on_spelled_and_missing_addresses', () async {
    final Random random = seededRandom(72601);
    final Set<String> seenKinds = <String>{};

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair();
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final _PlannedStep planned = _planStep(random, pair);

        final String fakeOutcome = await _observe(
          () => _apply(pair.fake, planned),
        );
        final String nodeOutcome = await _observe(
          () => _apply(pair.nodeBacked, planned),
        );
        seenKinds.add(_readKind(nodeOutcome));

        expect(fakeOutcome, nodeOutcome, reason: '$planned');
        expect(
          _describeListing(pair.fake),
          orderedEquals(_describeListing(pair.nodeBacked)),
        );
      }
      pair.nodeBacked.dispose();
    }
    expect(seenKinds, _everyKind);
  });
}
