import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';

const String pendingKindText = 'Adding…';
const String unconnectedTargetText = 'Connect it by dragging';

final class DiagramNode {
  const DiagramNode({
    required this.position,
    required this.kindText,
    required this.name,
    required this.targetText,
    required this.look,
  });

  final CanvasPosition position;
  final String kindText;
  final String name;
  final String? targetText;
  final NodeLook look;
}

bool isAgentUnconnected(Workflow workflow, WorkflowAgentId agentId) {
  for (final AgentConnection connection in workflow.connections) {
    if (connection.from == agentId || connection.to == agentId) {
      return false;
    }
  }
  return workflow.agents.length > 1;
}

DiagramNode describeAgentNode({
  required WorkflowAgent agent,
  required Workflow workflow,
  required DeviceNames deviceNames,
  required NodeLook look,
}) {
  final String target = isAgentUnconnected(workflow, agent.id)
      ? unconnectedTargetText
      : describeAgentTarget(agent.runsOn, deviceNames);

  return DiagramNode(
    position: agent.position,
    kindText: describeAgentKind(agent.kind),
    name: agent.name,
    targetText: target,
    look: look,
  );
}

DiagramNode describePendingNode(PendingAgent pending) {
  return DiagramNode(
    position: pending.position,
    kindText: pendingKindText,
    name: pending.name,
    targetText: null,
    look: NodeLook.pending,
  );
}
