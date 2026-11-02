import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

CanvasPosition mapCanvasPositionFromNode(node.CanvasPosition position) {
  return CanvasPosition(
    horizontal: position.horizontal,
    vertical: position.vertical,
  );
}

node.CanvasPosition mapCanvasPositionToNode(CanvasPosition position) {
  return node.CanvasPosition(
    horizontal: position.horizontal,
    vertical: position.vertical,
  );
}

WorkflowAgent mapWorkflowAgentFromNode(node.WorkflowAgent agent) {
  final node.AgentKind? kind = agent.kind;

  return WorkflowAgent(
    id: agent.id,
    name: agent.name,
    kind: kind == null ? null : mapAgentKindFromNode(kind),
    task: agent.task,
    runsOn: mapRunnerTargetFromNode(agent.runsOn),
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: mapApprovalPolicyFromNode(agent.approvalPolicy),
    position: mapCanvasPositionFromNode(agent.position),
  );
}

node.WorkflowAgent mapWorkflowAgentToNode(WorkflowAgent agent) {
  final AgentKind? kind = agent.kind;

  return node.WorkflowAgent(
    id: agent.id,
    name: agent.name,
    kind: kind == null ? null : mapAgentKindToNode(kind),
    task: agent.task,
    runsOn: mapRunnerTargetToNode(agent.runsOn),
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: mapApprovalPolicyToNode(agent.approvalPolicy),
    position: mapCanvasPositionToNode(agent.position),
  );
}

AgentConnection mapAgentConnectionFromNode(node.AgentConnection connection) {
  return AgentConnection(from: connection.from, to: connection.to);
}

node.AgentConnection mapAgentConnectionToNode(AgentConnection connection) {
  return node.AgentConnection(from: connection.from, to: connection.to);
}
