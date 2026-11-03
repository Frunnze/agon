import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'random_inputs.dart';
import 'random_workflows.dart';

const List<String> sampleOutcomes = <String>[
  'approved',
  'changes',
  'needs work',
  'ship-it',
  'retry 2',
];
const int mostRoundsInATest = 10;

bool hasForwardPath(
  Workflow workflow, {
  required WorkflowAgentId from,
  required WorkflowAgentId to,
}) {
  final List<WorkflowAgentId> waiting = <WorkflowAgentId>[from];
  final Set<WorkflowAgentId> seen = <WorkflowAgentId>{};

  while (waiting.isNotEmpty) {
    final WorkflowAgentId current = waiting.removeLast();
    if (current == to) {
      return true;
    }
    if (!seen.add(current)) {
      continue;
    }
    for (final AgentConnection connection in workflow.connections) {
      if (connection.from == current && connection.roundLimit == null) {
        waiting.add(connection.to);
      }
    }
  }
  return false;
}

String? _pickFreeOutcome(
  Random random,
  List<AgentConnection> connections,
  WorkflowAgentId from,
) {
  final List<String> free = <String>[
    for (final String outcome in sampleOutcomes)
      if (!connections.any(
        (AgentConnection connection) =>
            connection.from == from && connection.condition == outcome,
      ))
        outcome,
  ];
  if (free.isEmpty) {
    return null;
  }
  return pickOne(random, free);
}

WorkflowAgent _maybePerson(Random random, WorkflowAgent agent) {
  if (random.nextInt(3) != 0) {
    return agent;
  }
  return WorkflowAgent(
    id: agent.id,
    name: agent.name,
    stepKind: StepKind.person,
    kind: null,
    task: agent.task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

List<AgentConnection> _addConditions(
  Random random,
  List<AgentConnection> forward,
) {
  final List<AgentConnection> conditioned = <AgentConnection>[];
  for (final AgentConnection connection in forward) {
    final String? outcome = random.nextBool()
        ? _pickFreeOutcome(random, conditioned, connection.from)
        : null;
    conditioned.add(connection.withCondition(outcome));
  }
  return conditioned;
}

Workflow randomBranchingWorkflow(Random random) {
  final Workflow acyclic = randomAcyclicWorkflow(random);
  final Workflow conditioned = acyclic.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in acyclic.agents)
        _maybePerson(random, agent),
    ],
    connections: _addConditions(random, acyclic.connections),
  );
  final List<AgentConnection> connections = List<AgentConnection>.of(
    conditioned.connections,
  );

  for (final AgentConnection forward in conditioned.connections) {
    final bool isAlreadyJoined = connections.any(
      (AgentConnection connection) =>
          connection.from == forward.to && connection.to == forward.from,
    );
    if (isAlreadyJoined || random.nextInt(3) != 0) {
      continue;
    }
    final String? outcome = _pickFreeOutcome(random, connections, forward.to);
    if (outcome == null) {
      continue;
    }
    connections.add(
      AgentConnection(
        from: forward.to,
        to: forward.from,
        condition: outcome,
        roundLimit: 1 + random.nextInt(mostRoundsInATest),
      ),
    );
  }

  return conditioned.withGraph(
    agents: conditioned.agents,
    connections: connections,
  );
}
