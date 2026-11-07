import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/project_inputs.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_project_repository';

bool _isProjectRefusal(Object error) {
  return error is StateError ||
      error is ArgumentError ||
      error is RecordNotFound;
}

Project _pickProjectWithRepositories(Random random, List<Project> projects) {
  final List<Project> withRepositories = <Project>[
    for (final Project project in projects)
      if (project.repositories.isNotEmpty) project,
  ];
  return pickOne(random, withRepositories);
}

void main() {
  test('${_typePrefix}_add_repository_property_stores_the_canonical_'
      'address', () async {
    final Random random = seededRandom(65701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = pickOne(random, counted.seeded);
      final String canonical = randomCanonicalAddress(random);
      final String spelled = spellAddressDifferently(random, canonical);

      final Project updated = await counted.repository.addRepository(
        picked.id,
        randomRepositoryAt(random, spelled),
      );

      expect(listAddresses(updated), <String>[
        ...listAddresses(picked),
        canonical,
      ], reason: spelled);
    }
  });

  test('${_typePrefix}_add_repository_property_any_spelling_of_a_listed_'
      'address_is_refused', () async {
    final Random random = seededRandom(65702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = _pickProjectWithRepositories(
        random,
        counted.seeded,
      );
      final String listed = pickOne(random, listAddresses(picked));
      final String spelled = spellAddressDifferently(random, listed);

      await expectLater(
        counted.repository.addRepository(
          picked.id,
          randomRepositoryAt(random, spelled),
        ),
        throwsStateError,
        reason: spelled,
      );
      expect(
        identical(counted.repository.findProject(picked.id), picked),
        isTrue,
      );
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_add_repository_property_refuses_what_the_node_'
      'refuses', () async {
    final Random random = seededRandom(65703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final bool isMissingProject = random.nextBool();
      final ProjectId projectId = isMissingProject
          ? ProjectId('project-missing-${randomText(random)}')
          : pickOne(random, counted.seeded).id;
      final Repository refused = pickOne(random, <Repository>[
        Repository(
          address: randomText(random).replaceAll('/', ''),
          defaultBranch: 'main',
          agentAccess: AgentAccess.readOnly,
        ),
        Repository(
          address: randomCanonicalAddress(random),
          defaultBranch: pickOne(random, <String>['', '  ', '\t']),
          agentAccess: AgentAccess.readOnly,
        ),
      ]);

      final bool wasRefused = await isRefused(
        () => counted.repository.addRepository(projectId, refused),
        isRefusal: _isProjectRefusal,
      );

      expect(wasRefused, isTrue, reason: refused.address);
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_remove_repository_property_any_spelling_removes_'
      'it', () async {
    final Random random = seededRandom(65704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = _pickProjectWithRepositories(
        random,
        counted.seeded,
      );
      final String listed = pickOne(random, listAddresses(picked));
      final String spelled = spellAddressDifferently(random, listed);

      final Project updated = await counted.repository.removeRepository(
        picked.id,
        spelled,
      );

      expect(listAddresses(updated), <String>[
        for (final String address in listAddresses(picked))
          if (address != listed) address,
      ], reason: spelled);
    }
  });

  test('${_typePrefix}_remove_repository_property_unlisted_addresses_are_'
      'not_found', () async {
    final Random random = seededRandom(65705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = pickOne(random, counted.seeded);
      final String unlisted = randomCanonicalAddress(random);

      await expectLater(
        counted.repository.removeRepository(picked.id, unlisted),
        throwsA(
          isA<AppServerRefusal>().having(
            (AppServerRefusal refusal) => refusal.message,
            'reason',
            'the repository was not found',
          ),
        ),
      );
      expect(
        identical(counted.repository.findProject(picked.id), picked),
        isTrue,
      );
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_remove_repository_property_add_then_remove_'
      'round_trips', () async {
    final Random random = seededRandom(65706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = pickOne(random, counted.seeded);
      final String canonical = randomCanonicalAddress(random);
      await counted.repository.addRepository(
        picked.id,
        randomRepositoryAt(random, spellAddressDifferently(random, canonical)),
      );

      final Project restored = await counted.repository.removeRepository(
        picked.id,
        spellAddressDifferently(random, canonical),
      );

      expect(listAddresses(restored), listAddresses(picked));
      expect(counted.notifications.count, 2);
    }
  });

  test('${_typePrefix}_store_project_property_keeps_the_other_'
      'projects', () async {
    final Random random = seededRandom(65707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = pickOne(random, counted.seeded);

      await counted.repository.addRepository(
        picked.id,
        randomRepositoryAt(random, randomCanonicalAddress(random)),
      );

      for (final Project other in counted.seeded) {
        if (other.id == picked.id) {
          continue;
        }
        expect(
          identical(counted.repository.findProject(other.id), other),
          isTrue,
        );
      }
    }
  });

  test('${_typePrefix}_store_project_property_keeps_the_place_in_the_'
      'list', () async {
    final Random random = seededRandom(65708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final List<ProjectId> idsBefore = listAllProjectIds(counted.repository);
      final Project picked = _pickProjectWithRepositories(
        random,
        counted.seeded,
      );

      await counted.repository.removeRepository(
        picked.id,
        pickOne(random, listAddresses(picked)),
      );

      expect(listAllProjectIds(counted.repository), orderedEquals(idsBefore));
    }
  });

  test('${_typePrefix}_store_project_property_keeps_the_project_'
      'fields', () async {
    final Random random = seededRandom(65709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = pickOne(random, counted.seeded);

      final Project updated = await counted.repository.addRepository(
        picked.id,
        randomRepositoryAt(random, randomCanonicalAddress(random)),
      );

      expect(updated.id, picked.id);
      expect(updated.workspaceId, picked.workspaceId);
      expect(updated.name, picked.name);
      expect(updated.approvalPolicy, picked.approvalPolicy);
      expect(counted.notifications.count, 1);
    }
  });
}
