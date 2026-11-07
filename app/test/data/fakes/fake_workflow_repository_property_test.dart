import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

const String _typePrefix = 'test_fake_workflow_repository';

List<WorkflowId> _listIds(FakeWorkflowRepository repository) {
  return <WorkflowId>[
    for (final Workflow workflow in repository.listWorkflows()) workflow.id,
  ];
}

Matcher _isNotFound(WorkflowId workflowId) {
  return isA<RecordNotFound>()
      .having((RecordNotFound error) => error.kind, 'kind', 'workflow')
      .having(
        (RecordNotFound error) => error.identifier,
        'identifier',
        workflowId.value,
      );
}

void main() {
  test('${_typePrefix}_new_property_refuses_repeated_seed_ids', () {
    final Random random = seededRandom(67101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final Workflow repeated = randomValidWorkflow(
        random,
        index: random.nextInt(seeded.length + 1),
        signature: null,
      );
      final List<Workflow> withRepeat = <Workflow>[
        ...seeded,
        repeated,
        repeated.withName('other-name'),
      ];

      expect(
        () => buildWorkflowRepository(
          workflows: withRepeat,
          changes: const <WorkflowChange>[],
        ),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_new_property_refuses_two_changes_for_one', () {
    final Random random = seededRandom(67102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow signed = randomValidWorkflow(
        random,
        index: i,
        signature: buildSampleSignature(),
      );

      expect(
        () => buildWorkflowRepository(
          workflows: <Workflow>[signed],
          changes: <WorkflowChange>[
            buildSampleChange(signed.id),
            buildSampleChange(signed.id),
          ],
        ),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_new_property_keeps_a_frozen_copy_of_seeds', () {
    final Random random = seededRandom(67103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final List<WorkflowId> seededIds = <WorkflowId>[
        for (final Workflow workflow in seeded) workflow.id,
      ];
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: randomChangesFor(random, seeded),
      );

      seeded.add(randomValidWorkflow(random, index: 99, signature: null));

      expect(_listIds(repository), orderedEquals(seededIds));
    }
  });

  test('test_list_workflows_property_listing_cannot_be_edited', () {
    final Random random = seededRandom(67104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: const <WorkflowChange>[],
      );
      final Workflow extra = randomValidWorkflow(
        random,
        index: 50,
        signature: null,
      );

      expect(
        () => repository.listWorkflows().add(extra),
        throwsUnsupportedError,
      );
      expect(repository.listWorkflows(), hasLength(seeded.length));
    }
  });

  test('test_list_workflows_property_follows_creates_and_deletes', () async {
    final Random random = seededRandom(67105);

    for (int i = 0; i < 60; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final List<WorkflowId> model = _listIds(repository);

      for (int step = 0; step < 8; step += 1) {
        if (model.isNotEmpty && random.nextBool()) {
          final WorkflowId removed = pickOne(random, model);
          await repository.deleteWorkflow(removed);
          model.remove(removed);
        } else {
          final Workflow created = await repository.createWorkflow(
            randomValidWorkflow(random, index: step, signature: null),
          );
          model.add(created.id);
        }

        expect(_listIds(repository), orderedEquals(model));
        expect(model.toSet(), hasLength(model.length));
      }
    }
  });

  test('test_list_workflows_property_one_listing_per_identifier', () async {
    final Random random = seededRandom(67106);

    for (int i = 0; i < 60; i += 1) {
      final List<Workflow> seeded = <Workflow>[];
      for (int index = 1; index <= 3; index += 1) {
        final Workflow graph = randomValidWorkflow(
          random,
          index: index,
          signature: null,
        );
        seeded.add(
          Workflow(
            id: WorkflowId('created-workflow-$index'),
            name: graph.name,
            availability: graph.availability,
            agents: graph.agents,
            connections: graph.connections,
            signature: null,
          ),
        );
      }
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: const <WorkflowChange>[],
      );

      for (int step = 0; step < 4; step += 1) {
        await repository.createWorkflow(
          randomValidWorkflow(random, index: step, signature: null),
        );
      }

      final List<WorkflowId> ids = _listIds(repository);
      expect(ids.toSet(), hasLength(ids.length));
    }
  });

  test('test_find_workflow_property_finds_the_listed_record', () {
    final Random random = seededRandom(67107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: const <WorkflowChange>[],
      );

      for (final Workflow listed in repository.listWorkflows()) {
        expect(repository.findWorkflow(listed.id), same(listed));
      }
    }
  });

  test('test_find_workflow_property_unknown_ids_are_not_found', () {
    final Random random = seededRandom(67108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final WorkflowId unknown = WorkflowId('missing ${randomText(random)}');

      expect(
        () => repository.findWorkflow(unknown),
        throwsA(_isNotFound(unknown)),
      );
    }
  });

  test('test_find_workflow_property_deleted_records_are_gone', () async {
    final Random random = seededRandom(67109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: randomChangesFor(random, seeded),
      );
      final Workflow deleted = pickOne(random, seeded);

      await repository.deleteWorkflow(deleted.id);

      expect(
        () => repository.findWorkflow(deleted.id),
        throwsA(_isNotFound(deleted.id)),
      );
    }
  });
}
