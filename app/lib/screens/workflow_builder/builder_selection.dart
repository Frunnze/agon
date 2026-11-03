import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

sealed class BuilderSelection {
  const BuilderSelection();
}

final class SelectedStep extends BuilderSelection {
  const SelectedStep(this.agentId);

  final WorkflowAgentId agentId;
}

final class SelectedConnection extends BuilderSelection {
  const SelectedConnection(this.connection);

  final AgentConnection connection;
}

final class DrawnLoop extends BuilderSelection {
  const DrawnLoop(this.connection);

  final AgentConnection connection;
}

WorkflowAgentId? findSelectedStepId(BuilderSelection? selection) {
  if (selection is SelectedStep) {
    return selection.agentId;
  }
  return null;
}

AgentConnection? findSelectedConnection(BuilderSelection? selection) {
  if (selection is SelectedConnection) {
    return selection.connection;
  }
  return null;
}

AgentConnection? findDrawnLoop(BuilderSelection? selection) {
  if (selection is DrawnLoop) {
    return selection.connection;
  }
  return null;
}
