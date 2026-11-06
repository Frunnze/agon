import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

Future<void> restoreOpenedWorkflow({
  required WorkflowRepository workflowRepository,
  required Workflow openedVersion,
  required WorkflowChange? openedChange,
}) async {
  final WorkflowId workflowId = openedVersion.id;
  final WorkflowChange? currentChange = workflowRepository.findPendingChange(
    workflowId,
  );
  final bool isChangedSinceOpening =
      openedChange == null && currentChange != null;
  if (isChangedSinceOpening) {
    await workflowRepository.discardChange(workflowId);
    return;
  }

  final Workflow currentVersion = workflowRepository.findWorkflow(workflowId);
  if (!hasSameDesign(currentVersion, openedVersion)) {
    await workflowRepository.saveWorkflow(openedVersion);
  }
}
