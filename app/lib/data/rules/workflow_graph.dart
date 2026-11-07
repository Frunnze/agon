import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

const int _firstRemainingIndex = 0;
const String _loopPointsForwardProblem =
    'A loop must go back to an earlier step';
const String _backwardWithoutRoundsProblem =
    'Going back to an earlier step needs a round limit';

enum ConnectionProblem {
  sameAgent("A step can't feed into itself"),
  alreadyConnected('These steps are already connected');

  const ConnectionProblem(this.message);

  final String message;
}

List<AgentConnection> listForwardConnections(Workflow workflow) {
  return <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (!connection.isLoop) connection,
  ];
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

  final int nameOrder = first.name.compareTo(second.name);
  if (nameOrder != 0) {
    return nameOrder;
  }
  return first.id.value.compareTo(second.id.value);
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

int? findReadyIndex(
  List<WorkflowAgent> remaining,
  Set<WorkflowAgentId> orderedIds,
  List<AgentConnection> connections,
) {
  for (int index = 0; index < remaining.length; index += 1) {
    if (_isReady(remaining[index], orderedIds, connections)) {
      return index;
    }
  }
  return null;
}

List<WorkflowAgent> orderAgents(Workflow workflow) {
  final List<WorkflowAgent> remaining = List<WorkflowAgent>.of(
    workflow.agents,
  );
  remaining.sort(_compareCanvasOrder);
  final List<AgentConnection> forward = listForwardConnections(workflow);
  final List<WorkflowAgent> ordered = <WorkflowAgent>[];
  final Set<WorkflowAgentId> orderedIds = <WorkflowAgentId>{};

  while (remaining.isNotEmpty) {
    final int readyIndex =
        findReadyIndex(remaining, orderedIds, forward) ?? _firstRemainingIndex;
    final WorkflowAgent next = remaining.removeAt(readyIndex);
    ordered.add(next);
    orderedIds.add(next.id);
  }

  return ordered;
}

bool reachesForward(
  Workflow workflow, {
  required WorkflowAgentId from,
  required WorkflowAgentId to,
}) {
  final List<WorkflowAgentId> waiting = <WorkflowAgentId>[from];
  final Set<WorkflowAgentId> visited = <WorkflowAgentId>{};
  final List<AgentConnection> forward = listForwardConnections(workflow);

  while (waiting.isNotEmpty) {
    final WorkflowAgentId current = waiting.removeLast();
    if (current == to) {
      return true;
    }
    if (!visited.add(current)) {
      continue;
    }
    for (final AgentConnection connection in forward) {
      if (connection.from == current) {
        waiting.add(connection.to);
      }
    }
  }

  return false;
}

bool pointsBack(Workflow workflow, AgentConnection connection) {
  return reachesForward(workflow, from: connection.to, to: connection.from);
}

ConnectionProblem? findConnectionProblem(
  Workflow workflow,
  AgentConnection connection,
) {
  if (connection.from == connection.to) {
    return ConnectionProblem.sameAgent;
  }
  for (final AgentConnection existing in workflow.connections) {
    if (existing.joinsSameSteps(connection)) {
      return ConnectionProblem.alreadyConnected;
    }
  }
  return null;
}

String? _describeDirectionProblem(
  Workflow workflow,
  AgentConnection connection,
) {
  final bool isBackward = pointsBack(workflow, connection);
  if (connection.isLoop && !isBackward) {
    return _loopPointsForwardProblem;
  }
  if (!connection.isLoop && isBackward) {
    return _backwardWithoutRoundsProblem;
  }
  return null;
}

Workflow connectAgents(Workflow workflow, AgentConnection connection) {
  workflow.findAgent(connection.from);
  workflow.findAgent(connection.to);

  final String? problem =
      findConnectionProblem(workflow, connection)?.message ??
      _describeDirectionProblem(workflow, connection);
  if (problem != null) {
    throw ArgumentError.value(connection, 'connection', problem);
  }

  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[...workflow.connections, connection],
  );
}
