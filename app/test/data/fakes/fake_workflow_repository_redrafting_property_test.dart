import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

const List<String> _blankRequests = <String>['', ' ', '\t\n', '  '];

FakeWorkflowRepository? _seedRandomly(Random random) {
  final List<Workflow> workflows = randomSeededWorkflows(random);
  if (workflows.isEmpty) {
    return null;
  }
  return buildWorkflowRepository(
    workflows: workflows,
    changes: randomChangesFor(random, workflows),
  );
}

SignatureState _expectedStateAfterEdit(SignatureState before) {
  if (before == SignatureState.notSignedYet) {
    return SignatureState.notSignedYet;
  }
  return SignatureState.changedNotSigned;
}

void main() {
  test('test_change_workflow_property_blank_requests_refused', () async {
    final Random random = seededRandom(67501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository? repository = _seedRandomly(random);
      if (repository == null) {
        continue;
      }
      final Workflow workflow = pickOne(random, repository.listWorkflows());

      await expectLater(
        repository.changeWorkflow(
          workflow.id,
          pickOne(random, _blankRequests),
          pickOne(random, AgentKind.values),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.changeWorkflow(
          WorkflowId('missing-$i'),
          'Add a review step',
          pickOne(random, AgentKind.values),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(repository.findWorkflow(workflow.id), same(workflow));
    }
  });

  test('test_change_workflow_property_adds_one_valid_step', () async {
    final Random random = seededRandom(67502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository? repository = _seedRandomly(random);
      if (repository == null) {
        continue;
      }
      final Workflow workflow = pickOne(random, repository.listWorkflows());
      final String request = '  Add ${randomText(random)}x ';

      final Workflow changed = await repository.changeWorkflow(
        workflow.id,
        request,
        pickOne(random, AgentKind.values),
      );

      expect(changed.agents, hasLength(workflow.agents.length + 1));
      expect(changed.agents.take(workflow.agents.length), workflow.agents);
      expect(changed.agents.last.task, request.trim());
      expect(describeUploadProblem(changed), isNull);
      expect(repository.findWorkflow(workflow.id), same(changed));
    }
  });

  test('test_change_workflow_property_unseals_signed_ones', () async {
    final Random random = seededRandom(67503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository? repository = _seedRandomly(random);
      if (repository == null) {
        continue;
      }
      final Workflow workflow = pickOne(random, repository.listWorkflows());
      final SignatureState before = readSignatureState(
        repository,
        workflow.id,
      );

      final Workflow changed = await repository.changeWorkflow(
        workflow.id,
        'Add a review step',
        pickOne(random, AgentKind.values),
      );

      expect(changed.signature, same(workflow.signature));
      expect(
        readSignatureState(repository, workflow.id),
        _expectedStateAfterEdit(before),
      );
    }
  });

  test('test_fill_agent_settings_property_unknown_ids_refused', () async {
    final Random random = seededRandom(67504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository? repository = _seedRandomly(random);
      if (repository == null) {
        continue;
      }
      final Workflow workflow = pickOne(random, repository.listWorkflows());
      final WorkflowAgentId unknownAgent = WorkflowAgentId(
        'missing ${randomText(random)}',
      );

      await expectLater(
        repository.fillAgentSettings(workflow.id, unknownAgent),
        throwsStateError,
      );
      await expectLater(
        repository.fillAgentSettings(WorkflowId('missing-$i'), unknownAgent),
        throwsA(isA<RecordNotFound>()),
      );
      expect(repository.findWorkflow(workflow.id), same(workflow));
    }
  });

  test('test_fill_agent_settings_property_only_that_step_is_set', () async {
    final Random random = seededRandom(67505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository? repository = _seedRandomly(random);
      if (repository == null) {
        continue;
      }
      final Workflow workflow = await repository.saveWorkflow(
        addBlankStep(pickOne(random, repository.listWorkflows())),
      );
      final WorkflowAgent chosen = pickOne(random, workflow.agents);

      final Workflow filled = await repository.fillAgentSettings(
        workflow.id,
        chosen.id,
      );

      final WorkflowAgent result = filled.findAgent(chosen.id);
      expect(result.kind, isNotNull);
      expect(result.task.trim(), isNotEmpty);
      expect(result.name, chosen.name);
      expect(result.position, chosen.position);
      for (final WorkflowAgent other in workflow.agents) {
        if (other.id != chosen.id) {
          expect(filled.findAgent(other.id), other);
        }
      }
      expect(filled.connections, workflow.connections);
    }
  });

  test('test_fill_agent_settings_property_filling_twice_is_once', () async {
    final Random random = seededRandom(67506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository? repository = _seedRandomly(random);
      if (repository == null) {
        continue;
      }
      final Workflow workflow = await repository.saveWorkflow(
        addBlankStep(pickOne(random, repository.listWorkflows())),
      );
      final WorkflowAgent chosen = pickOne(random, workflow.agents);

      final Workflow once = await repository.fillAgentSettings(
        workflow.id,
        chosen.id,
      );
      final WorkflowChange? changeAfterOnce = repository.findPendingChange(
        workflow.id,
      );
      final Workflow twice = await repository.fillAgentSettings(
        workflow.id,
        chosen.id,
      );

      expect(twice.agents, once.agents);
      expect(repository.findPendingChange(workflow.id), same(changeAfterOnce));
    }
  });

  test('test_fill_agent_settings_property_unseals_when_it_fills', () async {
    final Random random = seededRandom(67507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seeded = randomValidWorkflow(
        random,
        index: i,
        signature: buildSampleSignature(),
      );
      final Workflow signed = addBlankStep(seeded);
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[signed],
        changes: const <WorkflowChange>[],
      );
      final WorkflowAgent chosen = pickOne(random, signed.agents);
      final bool needsFilling =
          chosen.kind == null || chosen.task.trim().isEmpty;

      await repository.fillAgentSettings(signed.id, chosen.id);

      final SignatureState expected = needsFilling
          ? SignatureState.changedNotSigned
          : SignatureState.signed;
      expect(readSignatureState(repository, signed.id), expected);
    }
  });
}
