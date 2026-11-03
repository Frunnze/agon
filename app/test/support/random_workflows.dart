import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'random_inputs.dart';
import 'sample_records.dart';

const int _largestAgentCount = 7;
const double _largestCanvasOffset = 600;

CanvasPosition randomCanvasPosition(Random random) {
  return CanvasPosition(
    horizontal: (random.nextDouble() * _largestCanvasOffset).roundToDouble(),
    vertical: (random.nextDouble() * _largestCanvasOffset).roundToDouble(),
  );
}

WorkflowAgent randomAgent(Random random, int index) {
  return WorkflowAgent(
    id: WorkflowAgentId('random-agent-$index'),
    name: 'agent-$index',
    stepKind: StepKind.agent,
    kind: random.nextInt(4) == 0 ? null : pickOne(random, AgentKind.values),
    task: randomWordPhrase(random),
    runsOn: randomRunnerTarget(random),
    skills: <SkillId>[
      for (final SkillId skillId in sampleSkillIds)
        if (random.nextBool()) skillId,
    ],
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
    position: randomCanvasPosition(random),
  );
}

List<WorkflowAgent> randomAgents(Random random) {
  final int count = random.nextInt(_largestAgentCount + 1);

  return <WorkflowAgent>[
    for (int index = 0; index < count; index += 1) randomAgent(random, index),
  ];
}

Workflow randomAcyclicWorkflow(Random random) {
  final List<WorkflowAgent> agents = randomAgents(random);
  final List<WorkflowAgent> shuffled = List<WorkflowAgent>.of(agents);
  shuffled.shuffle(random);
  final List<AgentConnection> connections = <AgentConnection>[];

  for (int first = 0; first < shuffled.length; first += 1) {
    for (int second = first + 1; second < shuffled.length; second += 1) {
      if (random.nextInt(3) == 0) {
        connections.add(
          AgentConnection(
            from: shuffled[first].id,
            to: shuffled[second].id,
            condition: null,
            roundLimit: null,
          ),
        );
      }
    }
  }

  return Workflow(
    id: WorkflowId('random-workflow-${random.nextInt(1000)}'),
    name: 'random-workflow',
    availability: const AllWorkspaces(),
    agents: agents,
    connections: connections,
    signature: null,
  );
}
