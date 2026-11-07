import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

String identifyWorkflow(Workflow workflow) => workflow.id.value;

String identifyChangedWorkflow(WorkflowChange change) {
  return change.workflowId.value;
}

void refuseWorkflowProblem(Workflow workflow, String? problem) {
  if (problem != null) {
    throw ArgumentError.value(workflow.name, 'workflow', problem);
  }
}

void refuseWorkflowUploadProblem(Workflow workflow) {
  final String? problem =
      describeNameProblem(workflow.name) ?? describeWorkflowProblem(workflow);
  refuseWorkflowProblem(workflow, problem);
}
