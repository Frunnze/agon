import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

WorkflowAgent? findRunStepAgent({
  required RunStep step,
  required Workflow? workflow,
}) {
  final WorkflowAgentId? agentId = step.agentId;
  if (agentId == null || workflow == null) {
    return null;
  }
  return workflow.findAgentIfPresent(agentId);
}
