import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';

void main() {
  test('test_delete_workflow_property_removes_only_that_one', () async {
    final Random random = seededRandom(67307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final Workflow deleted = pickOne(random, seeded.workflows);

      await seeded.repository.deleteWorkflow(deleted.id);

      final List<Workflow> expected = <Workflow>[
        for (final Workflow workflow in seeded.workflows)
          if (workflow.id != deleted.id) workflow,
      ];
      expect(seeded.repository.listWorkflows(), orderedEquals(expected));
      expect(seeded.repository.findPendingChange(deleted.id), isNull);
    }
  });

  test('test_delete_workflow_property_unknown_ids_change_nothing', () async {
    final Random random = seededRandom(67308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);
      final WorkflowId unknown = WorkflowId('gone ${randomText(random)}');

      await expectLater(
        seeded.repository.deleteWorkflow(unknown),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        seeded.repository.listWorkflows(),
        orderedEquals(seeded.workflows),
      );
      expect(notifications.count, 0);
    }
  });

  test('test_delete_workflow_property_deleted_twice_is_not_found', () async {
    final Random random = seededRandom(67309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final Workflow deleted = pickOne(random, seeded.workflows);
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);

      await seeded.repository.deleteWorkflow(deleted.id);
      await expectLater(
        seeded.repository.deleteWorkflow(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );

      expect(notifications.count, 1);
    }
  });

  test('test_remove_change_property_other_changes_survive', () async {
    final Random random = seededRandom(67310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null || seeded.changes.isEmpty) {
        continue;
      }
      final WorkflowId cleared = pickOne(random, seeded.changes).workflowId;
      final int step = random.nextInt(3);

      if (step == 0) {
        await seeded.repository.signWorkflow(cleared);
      } else if (step == 1) {
        await seeded.repository.discardChange(cleared);
      } else {
        await seeded.repository.deleteWorkflow(cleared);
      }

      for (final WorkflowChange change in seeded.changes) {
        final WorkflowChange? found = seeded.repository.findPendingChange(
          change.workflowId,
        );
        expect(found, change.workflowId == cleared ? isNull : same(change));
      }
    }
  });

  test('test_remove_change_property_deleted_change_stays_gone', () async {
    final Random random = seededRandom(67311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow signed = randomValidWorkflow(
        random,
        index: i,
        signature: buildSampleSignature(),
      );
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[signed],
        changes: <WorkflowChange>[buildSampleChange(signed.id)],
      );

      await repository.deleteWorkflow(signed.id);
      final Workflow recreated = await repository.createWorkflow(signed);

      expect(repository.findPendingChange(signed.id), isNull);
      expect(repository.findPendingChange(recreated.id), isNull);
    }
  });

  test('test_remove_change_property_sign_notifies_once', () async {
    final Random random = seededRandom(67312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null || seeded.changes.isEmpty) {
        continue;
      }
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);
      final WorkflowId cleared = pickOne(random, seeded.changes).workflowId;

      await seeded.repository.discardChange(cleared);

      expect(notifications.count, 1);
    }
  });
}
