import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

final class StopRecordingWorkflowRepository extends ChangeNotifier
    implements WorkflowRepository {
  StopRecordingWorkflowRepository({required this.refusal});

  final String? refusal;
  int stopAttempts = 0;

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    return const Stream<WorkflowDraftProgress>.empty();
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) async {
    stopAttempts += 1;
    final String? givenRefusal = refusal;
    if (givenRefusal != null) {
      throw StateError(givenRefusal);
    }
  }

  @override
  List<Workflow> listWorkflows() => const <Workflow>[];

  @override
  Workflow findWorkflow(WorkflowId workflowId) => throw UnimplementedError();

  @override
  WorkflowChange? findPendingChange(WorkflowId workflowId) {
    throw UnimplementedError();
  }

  @override
  Future<Workflow> saveWorkflow(Workflow workflow) {
    throw UnimplementedError();
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) {
    throw UnimplementedError();
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWorkflow(WorkflowId workflowId) {
    throw UnimplementedError();
  }

  @override
  Future<Workflow> changeWorkflow(WorkflowId workflowId, String request) {
    throw UnimplementedError();
  }

  @override
  Future<Workflow> fillAgentSettings(
    WorkflowId workflowId,
    WorkflowAgentId agentId,
  ) {
    throw UnimplementedError();
  }
}
