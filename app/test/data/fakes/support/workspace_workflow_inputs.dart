import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'workflow_inputs.dart';
import 'workspace_scope_inputs.dart';

Workflow withAvailability(Workflow workflow, WorkspaceScope availability) {
  return Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

List<Workflow> randomWorkflowsAvailableOver(
  Random random,
  List<WorkspaceId> workspaceIds,
) {
  return <Workflow>[
    for (final Workflow workflow in randomSeededWorkflows(random))
      withAvailability(
        workflow,
        randomWorkspaceScopeOver(random, workspaceIds),
      ),
  ];
}

List<WorkflowId> predictWorkflowsListedIn(
  List<Workflow> workflows,
  WorkspaceId workspaceId,
) {
  return <WorkflowId>[
    for (final Workflow workflow in workflows)
      if (isModelUsableInWorkspace(workflow.availability, workspaceId))
        workflow.id,
  ];
}

List<WorkflowId> listWorkflowIds(List<Workflow> workflows) {
  return <WorkflowId>[for (final Workflow workflow in workflows) workflow.id];
}
