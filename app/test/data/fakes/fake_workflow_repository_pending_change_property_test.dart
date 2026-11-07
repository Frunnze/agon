import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

void main() {
  test('test_find_pending_change_property_returns_seeded_changes', () {
    final Random random = seededRandom(67110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final List<WorkflowChange> changes = randomChangesFor(random, seeded);
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: changes,
      );

      for (final Workflow workflow in seeded) {
        final List<WorkflowChange> expected = <WorkflowChange>[
          for (final WorkflowChange change in changes)
            if (change.workflowId == workflow.id) change,
        ];
        final WorkflowChange? found = repository.findPendingChange(
          workflow.id,
        );
        expect(found, expected.isEmpty ? isNull : same(expected.single));
      }
    }
  });

  test('test_find_pending_change_property_unknown_ids_have_none', () {
    final Random random = seededRandom(67111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: randomChangesFor(random, seeded),
      );
      final WorkflowId unknown = WorkflowId(randomText(random));

      expect(repository.findPendingChange(unknown), isNull);
    }
  });

  test('test_find_pending_change_property_signing_clears_it', () async {
    final Random random = seededRandom(67112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final List<WorkflowChange> changes = randomChangesFor(random, seeded);
      if (changes.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: changes,
      );
      final WorkflowId changedId = pickOne(random, changes).workflowId;

      if (random.nextBool()) {
        await repository.signWorkflow(changedId);
      } else {
        await repository.discardChange(changedId);
      }

      expect(repository.findPendingChange(changedId), isNull);
    }
  });
}
