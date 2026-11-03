import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

abstract interface class WorkflowRepository implements Listenable {
  List<Workflow> listWorkflows();

  Workflow findWorkflow(WorkflowId workflowId);

  WorkflowChange? findPendingChange(WorkflowId workflowId);

  Future<Workflow> createWorkflow(Workflow unsavedWorkflow);

  Future<Workflow> saveWorkflow(Workflow workflow);

  Future<Workflow> signWorkflow(WorkflowId workflowId);

  Future<Workflow> discardChange(WorkflowId workflowId);

  Future<void> deleteWorkflow(WorkflowId workflowId);

  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft);

  Future<void> stopDrafting(WorkflowDraft draft);

  Future<Workflow> changeWorkflow(WorkflowId workflowId, String request);

  Future<Workflow> fillAgentSettings(
    WorkflowId workflowId,
    WorkflowAgentId agentId,
  );
}
