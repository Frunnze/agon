import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

const String blankAgentName = 'new-agent';
const String blankPersonStepName = 'new-person-step';
const double _agentRowStep = 136;
const String _numberedAgentIdPrefix = '00000000-0000-4000-8000-';
const int _agentNumberDigitCount = 12;
const int _hexadecimalRadix = 16;
const CanvasPosition _firstAgentPosition = CanvasPosition(
  horizontal: 92,
  vertical: 16,
);

bool _hasAgentNamed(Workflow workflow, String name) {
  return workflow.agents.any((WorkflowAgent agent) => agent.name == name);
}

bool _hasAgentId(Workflow workflow, WorkflowAgentId agentId) {
  return workflow.agents.any((WorkflowAgent agent) => agent.id == agentId);
}

String findFreeAgentName(Workflow workflow, String baseName) {
  if (!_hasAgentNamed(workflow, baseName)) {
    return baseName;
  }

  int suffix = 2;
  while (_hasAgentNamed(workflow, '$baseName-$suffix')) {
    suffix += 1;
  }
  return '$baseName-$suffix';
}

WorkflowAgentId _describeNumberedAgentId(int number) {
  final String numberDigits = number
      .toRadixString(_hexadecimalRadix)
      .padLeft(_agentNumberDigitCount, '0');
  return WorkflowAgentId('$_numberedAgentIdPrefix$numberDigits');
}

WorkflowAgentId _findFreeAgentId(Workflow workflow) {
  int number = workflow.agents.length + 1;
  WorkflowAgentId candidate = _describeNumberedAgentId(number);

  while (_hasAgentId(workflow, candidate)) {
    number += 1;
    candidate = _describeNumberedAgentId(number);
  }
  return candidate;
}

CanvasPosition placeBelowAgents(List<WorkflowAgent> agents) {
  if (agents.isEmpty) {
    return _firstAgentPosition;
  }

  WorkflowAgent lowest = agents.first;
  for (final WorkflowAgent agent in agents) {
    if (agent.position.vertical > lowest.position.vertical) {
      lowest = agent;
    }
  }

  return CanvasPosition(
    horizontal: lowest.position.horizontal,
    vertical: lowest.position.vertical + _agentRowStep,
  );
}

WorkflowAgent _buildBlankStep(
  Workflow workflow, {
  required String baseName,
  required StepKind stepKind,
}) {
  return WorkflowAgent(
    id: _findFreeAgentId(workflow),
    name: findFreeAgentName(workflow, baseName),
    stepKind: stepKind,
    kind: null,
    task: '',
    runsOn: const AnyFreeRunner(),
    skills: const <SkillId>[],
    usesAutomaticSkills: true,
    approvalPolicy: null,
    position: placeBelowAgents(workflow.agents),
  );
}

WorkflowAgent buildBlankAgent(Workflow workflow) {
  return _buildBlankStep(
    workflow,
    baseName: blankAgentName,
    stepKind: StepKind.agent,
  );
}

WorkflowAgent buildBlankPersonStep(Workflow workflow) {
  return _buildBlankStep(
    workflow,
    baseName: blankPersonStepName,
    stepKind: StepKind.person,
  );
}

Workflow addAgent(Workflow workflow, WorkflowAgent agent) {
  if (_hasAgentId(workflow, agent.id)) {
    throw ArgumentError.value(agent.id, 'agent', 'Already in the workflow');
  }

  return workflow.withGraph(
    agents: <WorkflowAgent>[...workflow.agents, agent],
    connections: workflow.connections,
  );
}

Workflow replaceAgent(Workflow workflow, WorkflowAgent replacement) {
  workflow.findAgent(replacement.id);

  final List<WorkflowAgent> agents = <WorkflowAgent>[];
  for (final WorkflowAgent agent in workflow.agents) {
    if (agent.id == replacement.id) {
      agents.add(replacement);
    } else {
      agents.add(agent);
    }
  }

  return workflow.withGraph(agents: agents, connections: workflow.connections);
}

Workflow removeAgent(Workflow workflow, WorkflowAgentId agentId) {
  workflow.findAgent(agentId);

  final List<WorkflowAgent> agents = <WorkflowAgent>[
    for (final WorkflowAgent agent in workflow.agents)
      if (agent.id != agentId) agent,
  ];
  final List<AgentConnection> connections = <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (connection.from != agentId && connection.to != agentId) connection,
  ];

  return _dropLoopsNotPointingBack(
    workflow.withGraph(agents: agents, connections: connections),
  );
}

Workflow _dropLoopsNotPointingBack(Workflow workflow) {
  final List<AgentConnection> kept = <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (!connection.isLoop || pointsBack(workflow, connection)) connection,
  ];
  return workflow.withGraph(agents: workflow.agents, connections: kept);
}

AgentConnection findConnection(Workflow workflow, AgentConnection connection) {
  for (final AgentConnection existing in workflow.connections) {
    if (existing.joinsSameSteps(connection)) {
      return existing;
    }
  }
  throw StateError('Workflow ${workflow.name} has no such connection');
}

Workflow replaceConnection(Workflow workflow, AgentConnection replacement) {
  findConnection(workflow, replacement);

  final List<AgentConnection> connections = <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (connection.joinsSameSteps(replacement)) replacement else connection,
  ];
  return workflow.withGraph(agents: workflow.agents, connections: connections);
}

Workflow removeConnection(Workflow workflow, AgentConnection removed) {
  findConnection(workflow, removed);

  final List<AgentConnection> connections = <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (!connection.joinsSameSteps(removed)) connection,
  ];
  return _dropLoopsNotPointingBack(
    workflow.withGraph(agents: workflow.agents, connections: connections),
  );
}

bool hasSameDesign(Workflow first, Workflow second) {
  return first.name == second.name &&
      listEquals(first.agents, second.agents) &&
      listEquals(first.connections, second.connections);
}
