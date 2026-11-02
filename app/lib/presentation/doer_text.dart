import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

Workflow? findWorkflowForDoer(TaskDoer doer, List<Workflow> workflows) {
  switch (doer) {
    case OneAgentDoer():
      return null;
    case WorkflowDoer(:final WorkflowId workflowId):
      return findRecord<Workflow>(
        workflows,
        matches: (Workflow workflow) => workflow.id == workflowId,
        kind: 'workflow',
        identifier: workflowId.value,
      );
  }
}

String describeDoer(TaskDoer doer, List<Workflow> workflows) {
  switch (doer) {
    case OneAgentDoer(:final AgentKind agent):
      return agent.label;
    case WorkflowDoer():
      return 'workflow ${findWorkflowForDoer(doer, workflows)!.name}';
  }
}
