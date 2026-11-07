import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

const List<String> _outcomeWords = <String>[
  'ship',
  'fix',
  'needs',
  'work',
  'go',
  'retry 2',
];
const String _targetIdText = 'target';

WorkflowAgent _agentWithId(Random random, int index, String idText) {
  final WorkflowAgent agent = randomAgent(random, index);
  return WorkflowAgent(
    id: WorkflowAgentId(idText),
    name: agent.name,
    stepKind: agent.stepKind,
    kind: agent.kind,
    task: agent.task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

AgentConnection _outcomeConnection(String fromIdText, String outcome) {
  return AgentConnection(
    from: WorkflowAgentId(fromIdText),
    to: const WorkflowAgentId(_targetIdText),
    condition: outcome,
    roundLimit: null,
  );
}

Workflow _buildWorkflow(
  List<WorkflowAgent> agents,
  List<AgentConnection> connections,
) {
  return Workflow(
    id: const WorkflowId('outcome-key-workflow'),
    name: 'outcome-keys',
    availability: const AllWorkspaces(),
    agents: agents,
    connections: connections,
    signature: null,
  );
}

String _randomSpacedIdText(Random random) {
  final String first = pickOne(random, _outcomeWords);
  final String second = pickOne(random, _outcomeWords);
  return '$first $second';
}

void main() {
  test(
    'test_describe_condition_problem_property_spaced_ids_never_collide',
    () {
      final Random random = seededRandom(52201);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String sharedWord = pickOne(random, _outcomeWords);
        final String tailWord = pickOne(random, _outcomeWords);
        final String outcome = pickOne(random, _outcomeWords);
        final String spacedIdText = '$sharedWord $tailWord';
        final Workflow workflow = _buildWorkflow(
          <WorkflowAgent>[
            _agentWithId(random, 0, spacedIdText),
            _agentWithId(random, 1, sharedWord),
            _agentWithId(random, 2, _targetIdText),
          ],
          <AgentConnection>[
            _outcomeConnection(spacedIdText, outcome),
            _outcomeConnection(sharedWord, '$tailWord $outcome'),
          ],
        );

        expect(describeConnectionsProblem(workflow), isNull);
      }
    },
  );

  test('test_describe_condition_problem_property_one_step_reuse_refused', () {
    final Random random = seededRandom(52202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String sourceIdText = _randomSpacedIdText(random);
      final String outcome = pickOne(random, _outcomeWords);
      final WorkflowAgent source = _agentWithId(random, 0, sourceIdText);
      final Workflow workflow = _buildWorkflow(
        <WorkflowAgent>[
          source,
          _agentWithId(random, 1, _targetIdText),
          _agentWithId(random, 2, 'other target'),
        ],
        <AgentConnection>[
          _outcomeConnection(sourceIdText, outcome),
          AgentConnection(
            from: source.id,
            to: const WorkflowAgentId('other target'),
            condition: outcome,
            roundLimit: null,
          ),
        ],
      );

      expect(
        describeConnectionsProblem(workflow),
        'Two connections from ${source.name} share the outcome $outcome',
      );
    }
  });

  test('test_describe_condition_problem_property_steps_may_share', () {
    final Random random = seededRandom(52203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String outcome = pickOne(random, _outcomeWords);
      final List<String> sourceIdTexts = <String>{
        for (int source = 0; source < 1 + random.nextInt(4); source += 1)
          _randomSpacedIdText(random),
      }.toList();
      final Workflow workflow = _buildWorkflow(
        <WorkflowAgent>[
          for (int index = 0; index < sourceIdTexts.length; index += 1)
            _agentWithId(random, index, sourceIdTexts[index]),
          _agentWithId(random, sourceIdTexts.length, _targetIdText),
        ],
        <AgentConnection>[
          for (final String sourceIdText in sourceIdTexts)
            _outcomeConnection(sourceIdText, outcome),
        ],
      );

      expect(describeConnectionsProblem(workflow), isNull);
    }
  });
}
