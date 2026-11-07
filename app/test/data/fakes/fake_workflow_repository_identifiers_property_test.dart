import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';

FakeWorkflowRepository _buildWith(List<Workflow> workflows) {
  return buildWorkflowRepository(
    workflows: workflows,
    changes: const <WorkflowChange>[],
  );
}

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Draft ${randomText(random)}');
}

void main() {
  test('test_claim_created_workflow_id_property_never_reused', () async {
    final Random random = seededRandom(68419);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = _buildWith(const <Workflow>[]);
      final Set<WorkflowId> seenIds = <WorkflowId>{};
      final int createCount = 1 + random.nextInt(5);

      for (int create = 0; create < createCount; create += 1) {
        final Workflow created = await repository.createWorkflow(
          randomValidWorkflow(random, index: create, signature: null),
        );
        expect(seenIds.add(created.id), isTrue);
        if (random.nextBool()) {
          await repository.deleteWorkflow(created.id);
        }
      }
    }
  });

  test('test_claim_created_workflow_id_property_skips_seeded_ids', () async {
    final Random random = seededRandom(68420);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final Workflow taken = Workflow(
        id: const WorkflowId('created-workflow-1'),
        name: seed.name,
        availability: seed.availability,
        agents: seed.agents,
        connections: seed.connections,
        signature: null,
      );
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[taken]);

      final Workflow created = await repository.createWorkflow(seed);

      expect(created.id, isNot(taken.id));
      expect(repository.findWorkflow(taken.id), same(taken));
    }
  });

  test('test_claim_created_workflow_id_property_ignores_given_id', () async {
    final Random random = seededRandom(68421);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);

      final Workflow created = await repository.createWorkflow(seed);

      expect(created.id, isNot(seed.id));
      expect(repository.listWorkflows(), hasLength(2));
    }
  });

  test('test_list_drafted_workflow_property_appends_at_the_end', () async {
    final Random random = seededRandom(68422);

    for (int i = 0; i < 30; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final FakeWorkflowRepository repository = _buildWith(seeded);

      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(_randomDraft(random))
          .toList();

      final List<Workflow> listed = repository.listWorkflows();
      expect(listed.take(seeded.length), orderedEquals(seeded));
      expect(listed.last.id, steps.last.workflow.id);
    }
  });

  test('test_list_drafted_workflow_property_notifies_once', () async {
    final Random random = seededRandom(68423);

    for (int i = 0; i < 30; i += 1) {
      final FakeWorkflowRepository repository = _buildWith(const <Workflow>[]);
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);

      await repository.draftWorkflow(_randomDraft(random)).toList();

      expect(notifications.count, 1);
    }
  });

  test('test_list_drafted_workflow_property_unsigned_and_unchanged', () async {
    final Random random = seededRandom(68424);

    for (int i = 0; i < 30; i += 1) {
      final FakeWorkflowRepository repository = _buildWith(const <Workflow>[]);

      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(_randomDraft(random))
          .toList();

      final WorkflowId draftedId = steps.last.workflow.id;
      expect(
        readSignatureState(repository, draftedId),
        SignatureState.notSignedYet,
      );
    }
  });

  test('test_is_listed_property_deleted_ids_free_but_unused', () async {
    final Random random = seededRandom(68425);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = _buildWith(const <Workflow>[]);
      final Workflow first = await repository.createWorkflow(
        randomValidWorkflow(random, index: i, signature: null),
      );
      await repository.deleteWorkflow(first.id);

      final Workflow second = await repository.createWorkflow(
        randomValidWorkflow(random, index: i, signature: null),
      );

      expect(second.id, isNot(first.id));
    }
  });

  test('test_is_listed_property_created_ids_were_free', () async {
    final Random random = seededRandom(68426);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final FakeWorkflowRepository repository = _buildWith(seeded);
      final Set<WorkflowId> before = <WorkflowId>{
        for (final Workflow workflow in seeded) workflow.id,
      };

      final Workflow created = await repository.createWorkflow(
        randomValidWorkflow(random, index: i, signature: null),
      );

      expect(before, isNot(contains(created.id)));
    }
  });

  test('test_is_listed_property_draft_and_create_never_clash', () async {
    final Random random = seededRandom(68427);

    for (int i = 0; i < 30; i += 1) {
      final FakeWorkflowRepository repository = _buildWith(const <Workflow>[]);

      await repository.draftWorkflow(_randomDraft(random)).toList();
      await repository.createWorkflow(
        randomValidWorkflow(random, index: i, signature: null),
      );
      await repository.draftWorkflow(_randomDraft(random)).toList();

      final Set<WorkflowId> ids = <WorkflowId>{
        for (final Workflow workflow in repository.listWorkflows())
          workflow.id,
      };
      expect(ids, hasLength(3));
    }
  });
}
