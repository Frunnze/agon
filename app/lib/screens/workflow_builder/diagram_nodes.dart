import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';

const String pendingKindText = 'Adding…';
const String unconnectedTargetText = 'Connect it by dragging';
const String personKindText = 'You';
const String personTargetText = 'Waits for your answer';

final class DiagramNode {
  const DiagramNode({
    required this.position,
    required this.kindText,
    required this.name,
    required this.targetText,
    required this.stepKind,
    required this.look,
  });

  final CanvasPosition position;
  final String kindText;
  final String name;
  final String? targetText;
  final StepKind stepKind;
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

String _describeNodeTarget(WorkflowAgent agent, DeviceNames deviceNames) {
  switch (agent.stepKind) {
    case StepKind.agent:
      return describeAgentTarget(agent.runsOn, deviceNames);
    case StepKind.person:
      return personTargetText;
  }
}

String _describeNodeKind(WorkflowAgent agent) {
  switch (agent.stepKind) {
    case StepKind.agent:
      return describeAgentKind(agent.kind);
    case StepKind.person:
      return personKindText;
  }
}

DiagramNode describeAgentNode({
  required WorkflowAgent agent,
  required Workflow workflow,
  required DeviceNames deviceNames,
  required NodeLook look,
}) {
  final String target = isAgentUnconnected(workflow, agent.id)
      ? unconnectedTargetText
      : _describeNodeTarget(agent, deviceNames);

  return DiagramNode(
    position: agent.position,
    kindText: _describeNodeKind(agent),
    name: agent.name,
    targetText: target,
    stepKind: agent.stepKind,
    look: look,
  );
}

DiagramNode describePendingNode(PendingAgent pending) {
  return DiagramNode(
    position: pending.position,
    kindText: pendingKindText,
    name: pending.name,
    targetText: null,
    stepKind: StepKind.agent,
    look: NodeLook.pending,
  );
}
