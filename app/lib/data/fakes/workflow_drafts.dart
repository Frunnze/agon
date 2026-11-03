import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

const AgentKind fakeDrafterKind = AgentKind.claudeCode;
const String _requestedAgentName = 'requested-step';

Workflow buildDraftedWorkflow({
  required Workflow template,
  required String chosenName,
  required WorkflowId workflowId,
}) {
  return Workflow(
    id: workflowId,
    name: chosenName,
    availability: template.availability,
    agents: template.agents,
    connections: template.connections,
    signature: null,
  );
}

WorkflowDraftProgress buildDraftProgress({
  required Workflow drafted,
  required int addedAgentCount,
  required DeviceId drafterDeviceId,
}) {
  final List<WorkflowAgent> added = drafted.agents.sublist(0, addedAgentCount);
  final Set<WorkflowAgentId> addedIds = <WorkflowAgentId>{
    for (final WorkflowAgent agent in added) agent.id,
  };
  final List<AgentConnection> connections = <AgentConnection>[
    for (final AgentConnection connection in drafted.connections)
      if (addedIds.contains(connection.from) &&
          addedIds.contains(connection.to))
        connection,
  ];
  final List<PendingAgent> pending = <PendingAgent>[
    for (final WorkflowAgent agent in drafted.agents.sublist(addedAgentCount))
      PendingAgent(name: agent.name, position: agent.position),
  ];

  return WorkflowDraftProgress(
    workflow: drafted.withGraph(agents: added, connections: connections),
    pendingAgents: pending,
    drafterKind: fakeDrafterKind,
    drafterDeviceId: drafterDeviceId,
  );
}

Workflow appendRequestedAgent(Workflow workflow, String request) {
  final WorkflowAgent requested = buildBlankAgent(workflow).copyWith(
    name: findFreeAgentName(workflow, _requestedAgentName),
    kind: fakeDrafterKind,
    task: request,
  );
  final List<AgentConnection> connections = <AgentConnection>[
    ...workflow.connections,
  ];

  for (final WorkflowAgent agent in workflow.agents) {
    final bool feedsNothing = workflow.connections.every(
      (AgentConnection connection) => connection.from != agent.id,
    );
    if (feedsNothing) {
      connections.add(
        AgentConnection(
          from: agent.id,
          to: requested.id,
          condition: null,
          roundLimit: null,
        ),
      );
    }
  }

  return workflow.withGraph(
    agents: <WorkflowAgent>[...workflow.agents, requested],
    connections: connections,
  );
}

WorkflowAgent fillInAgent(WorkflowAgent agent, String workflowName) {
  final String task = agent.task.trim().isEmpty
      ? 'Do the ${agent.name} step of $workflowName.'
      : agent.task;

  return agent.copyWith(kind: agent.kind ?? fakeDrafterKind, task: task);
}
