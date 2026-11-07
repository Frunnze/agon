import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';

List<WorkflowId> _listIds(FakeWorkflowRepository repository) {
  return <WorkflowId>[
    for (final Workflow workflow in repository.listWorkflows()) workflow.id,
  ];
}

List<WorkflowAgentId> _listStepOrder(Workflow workflow) {
  return <WorkflowAgentId>[
    for (final WorkflowAgent agent in orderAgents(workflow)) agent.id,
  ];
}

Workflow _moveEveryStep(Random random, Workflow workflow) {
  final List<WorkflowAgent> moved = <WorkflowAgent>[
    for (final WorkflowAgent agent in workflow.agents)
      agent.copyWith(position: randomCanvasPosition(random)),
  ];
  return workflow.withGraph(agents: moved, connections: workflow.connections);
}

void main() {
  test(
    'test_create_workflow_property_refuses_what_the_node_refuses',
    () async {
      final Random random = seededRandom(67201);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeWorkflowRepository repository = buildWorkflowRepository(
          workflows: randomSeededWorkflows(random),
          changes: const <WorkflowChange>[],
        );
        final NotificationCounter notifications = NotificationCounter();
        repository.addListener(notifications.record);
        final List<WorkflowId> idsBefore = _listIds(repository);
        final Workflow broken = breakWorkflow(
          random,
          randomValidWorkflow(random, index: i, signature: null),
        );
        expect(describeUploadProblem(broken), isNotNull);

        await expectLater(
          repository.createWorkflow(broken),
          throwsArgumentError,
        );

        expect(_listIds(repository), orderedEquals(idsBefore));
        expect(notifications.count, 0);
      }
    },
  );

  test('test_create_workflow_property_new_unsigned_record', () async {
    final Random random = seededRandom(67202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final List<WorkflowId> idsBefore = _listIds(repository);
      final Workflow unsaved = randomValidWorkflow(
        random,
        index: random.nextInt(4),
        signature: random.nextBool() ? buildSampleSignature() : null,
      );

      final Workflow created = await repository.createWorkflow(unsaved);

      expect(idsBefore, isNot(contains(created.id)));
      expect(created.signature, isNull);
      expect(hasSameDesign(created, unsaved), isTrue);
      expect(repository.findWorkflow(created.id), same(created));
      expect(repository.findPendingChange(created.id), isNull);
    }
  });

  test('test_create_workflow_property_valid_ones_notify_once', () async {
    final Random random = seededRandom(67203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: const <Workflow>[],
        changes: const <WorkflowChange>[],
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final Workflow unsaved = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      expect(describeUploadProblem(unsaved), isNull);

      await repository.createWorkflow(unsaved);

      expect(notifications.count, 1);
      expect(repository.listWorkflows(), hasLength(1));
    }
  });

  test('test_save_workflow_property_unknown_ids_are_not_found', () async {
    final Random random = seededRandom(67204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        randomSeededWorkflows(random),
      );
      final List<WorkflowId> idsBefore = _listIds(repository);
      final Workflow unknown = randomValidWorkflow(
        random,
        index: 1000 + i,
        signature: null,
      );

      await expectLater(
        repository.saveWorkflow(unknown),
        throwsA(isA<RecordNotFound>()),
      );
      expect(_listIds(repository), orderedEquals(idsBefore));
    }
  });

  test('test_save_workflow_property_refuses_broken_workflows', () async {
    final Random random = seededRandom(67205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      final Workflow stored = pickOne(random, repository.listWorkflows());
      final Workflow broken = breakWorkflow(random, stored);

      await expectLater(repository.saveWorkflow(broken), throwsArgumentError);
      expect(repository.findWorkflow(stored.id), same(stored));
    }
  });

  test('test_save_workflow_property_keeps_the_stored_signature', () async {
    final Random random = seededRandom(67206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      final Workflow stored = pickOne(random, repository.listWorkflows());
      final Workflow edited = addBlankStep(stored);
      final Workflow forged = Workflow(
        id: edited.id,
        name: edited.name,
        availability: edited.availability,
        agents: edited.agents,
        connections: edited.connections,
        signature: stored.signature == null ? buildSampleSignature() : null,
      );

      final Workflow saved = await repository.saveWorkflow(forged);

      expect(saved.signature, same(stored.signature));
      final Workflow found = repository.findWorkflow(stored.id);
      expect(found.signature, same(stored.signature));
    }
  });

  test('test_save_workflow_property_edits_unseal_signed_ones', () async {
    final Random random = seededRandom(67207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      final Workflow stored = pickOne(random, repository.listWorkflows());
      final SignatureState before = readSignatureState(repository, stored.id);

      await repository.saveWorkflow(addBlankStep(stored));

      final SignatureState after = readSignatureState(repository, stored.id);
      final SignatureState expected = before == SignatureState.notSignedYet
          ? SignatureState.notSignedYet
          : SignatureState.changedNotSigned;
      expect(after, expected);
      final WorkflowChange? change = repository.findPendingChange(stored.id);
      if (before == SignatureState.signed) {
        expect(change?.signedDocument, stored.signature?.signedDocument);
      }
    }
  });

  test('test_save_workflow_property_unchanged_steps_stay_signed', () async {
    final Random random = seededRandom(67208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildSeededWorkflowRepository(
        random,
        seeded,
      );
      final Workflow stored = pickOne(random, repository.listWorkflows());
      final SignatureState before = readSignatureState(repository, stored.id);
      final WorkflowChange? changeBefore = repository.findPendingChange(
        stored.id,
      );
      final Workflow resaved = random.nextBool()
          ? stored
          : _moveEveryStep(random, stored);
      final bool keepsStepOrder = listEquals(
        _listStepOrder(stored),
        _listStepOrder(resaved),
      );
      final bool unseals = before == SignatureState.signed && !keepsStepOrder;

      await repository.saveWorkflow(resaved);

      final SignatureState after = readSignatureState(repository, stored.id);
      expect(after, unseals ? SignatureState.changedNotSigned : before);
      if (keepsStepOrder) {
        expect(repository.findPendingChange(stored.id), same(changeBefore));
      }
    }
  });
}
