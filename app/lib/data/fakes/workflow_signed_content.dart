import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

const String _unsignedEditSummary = 'Changed since it was signed';
const List<int> _fakeSignature = <int>[0];
const CanvasPosition _unplacedPosition = CanvasPosition(
  horizontal: 0,
  vertical: 0,
);

List<WorkflowAgent> _listUnplacedSteps(Workflow workflow) {
  return <WorkflowAgent>[
    for (final WorkflowAgent agent in orderAgents(workflow))
      agent.copyWith(position: _unplacedPosition),
  ];
}

bool _hasSameAvailability(WorkspaceScope first, WorkspaceScope second) {
  if (first is OnlyWorkspaces && second is OnlyWorkspaces) {
    return listEquals(first.workspaces, second.workspaces);
  }
  return first is AllWorkspaces && second is AllWorkspaces;
}

bool hasSameSignedContent(Workflow first, Workflow second) {
  final bool hasSameName = first.name == second.name;
  final bool hasSameAvailability = _hasSameAvailability(
    first.availability,
    second.availability,
  );
  final bool hasSameSteps = listEquals(
    _listUnplacedSteps(first),
    _listUnplacedSteps(second),
  );
  final bool hasSameConnections = listEquals(
    first.connections,
    second.connections,
  );
  return hasSameName &&
      hasSameAvailability &&
      hasSameSteps &&
      hasSameConnections;
}

Workflow replaceSignature(Workflow workflow, WorkflowSignature? signature) {
  return Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: signature,
  );
}

String describeFakeWorkflowDocument(Workflow workflow) {
  return 'name: ${workflow.name}\n';
}

WorkflowSignature signFakeWorkflow({
  required Workflow workflow,
  required WorkflowChange? pendingChange,
  required DeviceId signedBy,
  required DateTime signedAt,
}) {
  final String signedDocument =
      pendingChange?.changedDocument ??
      workflow.signature?.signedDocument ??
      describeFakeWorkflowDocument(workflow);
  return WorkflowSignature(
    signedBy: signedBy,
    signature: _fakeSignature,
    signedDocument: signedDocument,
    signedAt: signedAt,
  );
}

Map<WorkflowId, Workflow> collectSignedVersions(List<Workflow> workflows) {
  final Map<WorkflowId, Workflow> signedVersions = <WorkflowId, Workflow>{};

  for (final Workflow workflow in workflows) {
    if (workflow.signature != null) {
      signedVersions[workflow.id] = workflow;
    }
  }
  return signedVersions;
}

WorkflowChange describeUnsignedEdit({
  required Workflow edited,
  required WorkflowSignature signature,
  required DeviceId changedBy,
  required DateTime changedAt,
}) {
  return WorkflowChange(
    workflowId: edited.id,
    changedBy: changedBy,
    changedAt: changedAt,
    summary: _unsignedEditSummary,
    differences: const <WorkflowDifference>[],
    signedDocument: signature.signedDocument,
    changedDocument: describeFakeWorkflowDocument(edited),
  );
}

List<WorkflowChange> recordUnsignedEdit({
  required List<WorkflowChange> changes,
  required Workflow stored,
  required Workflow edited,
  required DeviceId changedBy,
  required DateTime changedAt,
}) {
  final WorkflowSignature? signature = stored.signature;
  final bool hasPendingChange = changes.any(
    (WorkflowChange change) => change.workflowId == stored.id,
  );
  if (signature == null || hasPendingChange) {
    return changes;
  }
  if (hasSameSignedContent(stored, edited)) {
    return changes;
  }

  final WorkflowChange change = describeUnsignedEdit(
    edited: edited,
    signature: signature,
    changedBy: changedBy,
    changedAt: changedAt,
  );
  return List<WorkflowChange>.unmodifiable(<WorkflowChange>[
    ...changes,
    change,
  ]);
}
