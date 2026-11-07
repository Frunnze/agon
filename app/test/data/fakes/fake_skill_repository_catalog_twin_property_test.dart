import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_twin_checks.dart';
import 'support/catalog_twin_world.dart';

const String _typePrefix = 'test_fake_skill_repository';
const int _sequenceIterations = 25;

void main() {
  test('${_typePrefix}_delete_skill_property_leaves_the_same_tasks_as_the_'
      'node', () async {
    final Random random = seededRandom(92901);
    int deletedCount = 0;

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
      final List<Skill> listed = world.nodeSkills.listSkills();
      if (listed.isEmpty) {
        closeCatalogTwinWorld(world);
        continue;
      }
      final Skill doomed = pickOne(random, listed);

      await world.fakeSkills.deleteSkill(doomed.id);
      await world.nodeSkills.deleteSkill(doomed.id);

      deletedCount += 1;
      for (final Task task in world.fakeTasks.listTasksAndJobs()) {
        expect(task.skills, isNot(contains(doomed.id)));
      }
      await expectCatalogTwinsAgree(world);
      closeCatalogTwinWorld(world);
    }

    expect(deletedCount, greaterThan(0));
  });
}
