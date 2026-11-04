import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows/workflow_text.dart';
import 'package:agent_orchestration/screens/workflows/workflows_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';

typedef PendingChangeFinder = WorkflowChange? Function(WorkflowId workflowId);

final class WorkflowToSign {
  const WorkflowToSign({required this.name, required this.signRoute});

  final String name;
  final AppRoute signRoute;
}

Map<WorkflowId, WorkflowToSign> findWorkflowsToSign({
  required List<Workflow> workflows,
  required PendingChangeFinder findPendingChange,
}) {
  final Map<WorkflowId, WorkflowToSign> workflowsToSign =
      <WorkflowId, WorkflowToSign>{};
  for (final Workflow workflow in workflows) {
    final SignatureState state = findSignatureState(
      workflow,
      findPendingChange(workflow.id),
    );
    if (state != SignatureState.signed) {
      workflowsToSign[workflow.id] = WorkflowToSign(
        name: workflow.name,
        signRoute: findWorkflowRoute(workflow.id, state),
      );
    }
  }
  return workflowsToSign;
}
