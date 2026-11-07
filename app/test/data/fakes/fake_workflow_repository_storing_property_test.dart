import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';

void main() {
  test('test_store_workflow_property_replaces_in_place', () async {
    final Random random = seededRandom(67209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      final List<Workflow> before = repository.listWorkflows();
      final Workflow stored = pickOne(random, before);

      final Workflow saved = await repository.saveWorkflow(
        addBlankStep(stored),
      );

      final List<Workflow> after = repository.listWorkflows();
      expect(after, hasLength(before.length));
      for (int index = 0; index < before.length; index += 1) {
        final Workflow expected = before[index].id == stored.id
            ? saved
            : before[index];
        expect(after[index], same(expected));
      }
    }
  });

  test('test_store_workflow_property_saved_steps_are_found', () async {
    final Random random = seededRandom(67210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      Workflow expected = pickOne(random, repository.listWorkflows());
      final int editCount = 1 + random.nextInt(4);

      for (int edit = 0; edit < editCount; edit += 1) {
        expected = await repository.saveWorkflow(addBlankStep(expected));
      }

      final Workflow found = repository.findWorkflow(expected.id);
      expect(hasSameDesign(found, expected), isTrue);
      expect(found.agents, hasLength(expected.agents.length));
    }
  });

  test('test_store_workflow_property_notifies_once_per_save', () async {
    final Random random = seededRandom(67211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final int saveCount = 1 + random.nextInt(5);

      for (int save = 0; save < saveCount; save += 1) {
        final Workflow stored = pickOne(random, repository.listWorkflows());
        await repository.saveWorkflow(addBlankStep(stored));
      }

      expect(notifications.count, saveCount);
    }
  });
}
