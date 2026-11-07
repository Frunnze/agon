import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/project_inputs.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_project_repository';
const String _createdIdPrefix = 'created-project-';
const int _largestCreatedCount = 4;

String _randomNameCandidate(Random random) {
  final String validName = 'project-${random.nextInt(1000)}';
  return pickOne(random, <String>[
    validName,
    '  $validName ',
    validName.toUpperCase(),
    randomWordPhrase(random),
    randomText(random),
    validName * 6,
  ]);
}

ProjectDraft _randomDraft(
  Random random, {
  required String name,
  required List<Repository> repositories,
}) {
  return ProjectDraft(
    workspaceId: pickOne(random, projectWorkspaceIds),
    name: name,
    repositories: repositories,
    approvalPolicy: pickOne(random, inheritableApprovalPolicies),
  );
}

bool _isCreateRefusal(Object error) {
  return error is ArgumentError || error is StateError;
}

void main() {
  test('${_typePrefix}_create_project_property_names_follow_the_node_'
      'rules', () async {
    final Random random = seededRandom(65801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final String name = _randomNameCandidate(random);
      final bool isValid = describeNameProblem(name.trim()) == null;

      final bool wasRefused = await isRefused(
        () => counted.repository.createProject(
          _randomDraft(random, name: name, repositories: <Repository>[]),
        ),
        isRefusal: _isCreateRefusal,
      );

      expect(wasRefused, !isValid, reason: name);
      expect(counted.notifications.count, isValid ? 1 : 0);
    }
  });

  test('${_typePrefix}_create_project_property_keeps_the_draft_with_'
      'canonical_addresses', () async {
    final Random random = seededRandom(65802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final List<Repository> canonical = randomDistinctRepositories(random);
      final List<Repository> spelled = <Repository>[
        for (final Repository repository in canonical)
          randomRepositoryAt(
            random,
            spellAddressDifferently(random, repository.address),
          ),
      ];
      final ProjectDraft draft = _randomDraft(
        random,
        name: ' project-${random.nextInt(1000)} ',
        repositories: spelled,
      );

      final Project created = await counted.repository.createProject(draft);

      expect(created.name, draft.name.trim());
      expect(created.workspaceId, draft.workspaceId);
      expect(created.approvalPolicy, draft.approvalPolicy);
      expect(listAddresses(created), <String>[
        for (final Repository repository in canonical) repository.address,
      ]);
      expect(
        identical(counted.repository.findProject(created.id), created),
        isTrue,
      );
      expect(counted.repository.listProjects(draft.workspaceId).last, created);
    }
  });

  test('${_typePrefix}_create_project_property_refuses_an_address_listed_'
      'twice', () async {
    final Random random = seededRandom(65803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final String canonical = randomCanonicalAddress(random);
      final List<Repository> repositories = <Repository>[
        ...randomDistinctRepositories(random),
        randomRepositoryAt(random, spellAddressDifferently(random, canonical)),
        randomRepositoryAt(random, spellAddressDifferently(random, canonical)),
      ]..shuffle(random);

      final bool wasRefused = await isRefused(
        () => counted.repository.createProject(
          _randomDraft(
            random,
            name: 'project-twice',
            repositories: repositories,
          ),
        ),
        isRefusal: _isCreateRefusal,
      );

      expect(wasRefused, isTrue);
      expect(
        listAllProjectIds(counted.repository).length,
        counted.seeded.length,
      );
    }
  });

  test('${_typePrefix}_create_project_property_trims_and_requires_the_'
      'default_branch', () async {
    final Random random = seededRandom(65804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final String branch = pickOne(random, <String>[
        'main',
        ' develop ',
        '\tmain\n',
        '',
        '   ',
      ]);
      final Repository repository = Repository(
        address: randomCanonicalAddress(random),
        defaultBranch: branch,
        agentAccess: AgentAccess.readOnly,
      );
      final Future<Project> creating = counted.repository.createProject(
        _randomDraft(
          random,
          name: 'project-branch',
          repositories: <Repository>[repository],
        ),
      );

      if (branch.trim().isEmpty) {
        await expectLater(creating, throwsArgumentError, reason: branch);
        continue;
      }
      final Project created = await creating;
      expect(created.repositories.single.defaultBranch, branch.trim());
    }
  });

  test('${_typePrefix}_create_project_property_new_ids_never_repeat_a_'
      'listed_id', () async {
    final Random random = seededRandom(65805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Project> seeded = <Project>[
        ...randomSeededProjects(random),
        for (int created = 1; created <= _largestCreatedCount; created += 1)
          if (random.nextBool())
            randomProjectWithId(
              random,
              ProjectId('$_createdIdPrefix$created'),
            ),
      ];
      final CountedProjects counted = buildCountedProjects(seeded);
      final int createCount = 1 + random.nextInt(_largestCreatedCount);

      for (int created = 0; created < createCount; created += 1) {
        await counted.repository.createProject(
          _randomDraft(
            random,
            name: 'project-new',
            repositories: <Repository>[],
          ),
        );
      }

      final List<ProjectId> allIds = listAllProjectIds(counted.repository);
      expect(allIds.toSet().length, allIds.length);
      expect(allIds.length, seeded.length + createCount);
    }
  });
}
