import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';

AgentPlace mapAgentPlaceFromNode(node.SandboxSettings sandbox) {
  return switch (sandbox) {
    node.LocalProcessSandbox() => AgentPlace.localProcess,
    node.ContainerSandbox() => AgentPlace.container,
  };
}

node.AgentPlace mapAgentPlaceToNode(AgentPlace place) {
  return switch (place) {
    AgentPlace.container => node.AgentPlace.container,
    AgentPlace.localProcess => node.AgentPlace.localProcess,
  };
}
