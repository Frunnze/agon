import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

const int _firstRemainingIndex = 0;

enum ConnectionProblem {
  sameAgent("An agent can't feed into itself"),
  alreadyConnected('These agents are already connected'),
  wouldMakeLoop('That would make a loop');

  const ConnectionProblem(this.message);

  final String message;
}

int _compareCanvasOrder(WorkflowAgent first, WorkflowAgent second) {
  final int verticalOrder = first.position.vertical.compareTo(
    second.position.vertical,
  );
  if (verticalOrder != 0) {
    return verticalOrder;
  }

  final int horizontalOrder = first.position.horizontal.compareTo(
    second.position.horizontal,
  );
  if (horizontalOrder != 0) {
    return horizontalOrder;
  }
  return first.name.compareTo(second.name);
}

bool _isReady(
  WorkflowAgent agent,
  Set<WorkflowAgentId> orderedIds,
  List<AgentConnection> connections,
) {
  for (final AgentConnection connection in connections) {
    final bool feedsAgent = connection.to == agent.id;
    if (feedsAgent && !orderedIds.contains(connection.from)) {
      return false;
    }
  }
  return true;
}

int _findReadyIndex(
  List<WorkflowAgent> remaining,
  Set<WorkflowAgentId> orderedIds,
  List<AgentConnection> connections,
) {
  for (int index = 0; index < remaining.length; index += 1) {
    if (_isReady(remaining[index], orderedIds, connections)) {
      return index;
    }
  }
  return _firstRemainingIndex;
}

List<WorkflowAgent> orderAgents(Workflow workflow) {
  final List<WorkflowAgent> remaining = List<WorkflowAgent>.of(
    workflow.agents,
  );
  remaining.sort(_compareCanvasOrder);
  final List<WorkflowAgent> ordered = <WorkflowAgent>[];
  final Set<WorkflowAgentId> orderedIds = <WorkflowAgentId>{};

  while (remaining.isNotEmpty) {
    final int readyIndex = _findReadyIndex(
      remaining,
      orderedIds,
      workflow.connections,
    );
    final WorkflowAgent next = remaining.removeAt(readyIndex);
    ordered.add(next);
    orderedIds.add(next.id);
  }

  return ordered;
}

bool _reaches(
  Workflow workflow, {
  required WorkflowAgentId from,
  required WorkflowAgentId to,
}) {
  final List<WorkflowAgentId> waiting = <WorkflowAgentId>[from];
  final Set<WorkflowAgentId> visited = <WorkflowAgentId>{};

  while (waiting.isNotEmpty) {
    final WorkflowAgentId current = waiting.removeLast();
    if (current == to) {
      return true;
    }
    if (!visited.add(current)) {
      continue;
    }
    for (final AgentConnection connection in workflow.connections) {
      if (connection.from == current) {
        waiting.add(connection.to);
      }
    }
  }

  return false;
}

ConnectionProblem? findConnectionProblem(
  Workflow workflow,
  AgentConnection connection,
) {
  if (connection.from == connection.to) {
    return ConnectionProblem.sameAgent;
  }
  if (workflow.connections.contains(connection)) {
    return ConnectionProblem.alreadyConnected;
  }
  if (_reaches(workflow, from: connection.to, to: connection.from)) {
    return ConnectionProblem.wouldMakeLoop;
  }
  return null;
}

Workflow connectAgents(Workflow workflow, AgentConnection connection) {
  workflow.findAgent(connection.from);
  workflow.findAgent(connection.to);

  final ConnectionProblem? problem = findConnectionProblem(
    workflow,
    connection,
  );
  if (problem != null) {
    throw ArgumentError.value(connection, 'connection', problem.message);
  }

  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[...workflow.connections, connection],
  );
}
