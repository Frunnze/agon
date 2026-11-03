import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';

const WorkflowId _unsavedWorkflowId = WorkflowId('unsaved');

Workflow _buildUnsavedWorkflow(Random random) {
  Workflow unsaved = Workflow(
    id: _unsavedWorkflowId,
    name: 'flow-${random.nextInt(1000)}',
    availability: const AllWorkspaces(),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
  final int agentCount = 1 + random.nextInt(4);
  for (int i = 0; i < agentCount; i += 1) {
    unsaved = addAgent(unsaved, buildBlankAgent(unsaved));
  }
  return unsaved;
}

void main() {
  test(
    'test_create_workflow_property_stores_a_new_unsigned_workflow',
    () async {
      final Random random = seededRandom(6201);
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();
      final Set<WorkflowId> createdIds = <WorkflowId>{};

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow unsaved = _buildUnsavedWorkflow(random);
        final int countBefore = repository.listWorkflows().length;

        final Workflow created = await repository.createWorkflow(unsaved);

        expect(created.id, isNot(_unsavedWorkflowId));
        expect(createdIds.add(created.id), isTrue);
        expect(created.signature, isNull);
        expect(created.name, unsaved.name);
        expect(created.agents.length, unsaved.agents.length);
        expect(repository.listWorkflows().length, countBefore + 1);
        expect(repository.findWorkflow(created.id).name, unsaved.name);
      }
    },
  );
}
