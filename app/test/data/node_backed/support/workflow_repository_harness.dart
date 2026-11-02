import 'package:agent_orchestration/data/node_backed.dart';

import 'node_backed_harness.dart' show buildSingleWorkspaceRepository;
import 'simulated_workflow_node.dart';

NodeBackedWorkflowRepository buildSimulatedWorkflowRepository(
  SimulatedWorkflowNode simulated,
) {
  return NodeBackedWorkflowRepository(
    channel: simulated.channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
    draftPollInterval: Duration.zero,
  );
}
