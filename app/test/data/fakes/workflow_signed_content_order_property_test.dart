import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/workflow_signed_content.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/workflow_inputs.dart';

Workflow _randomWorkflow(Random random, int index) {
  return randomValidWorkflow(
    random,
    index: index,
    signature: random.nextBool() ? buildSampleSignature() : null,
  );
}

Workflow _moveEveryStep(Random random, Workflow workflow) {
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        agent.copyWith(position: randomCanvasPosition(random)),
    ],
    connections: workflow.connections,
  );
}

Workflow _shiftEveryStep(Workflow workflow, double offset) {
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        agent.copyWith(
          position: CanvasPosition(
            horizontal: agent.position.horizontal + offset,
            vertical: agent.position.vertical + offset,
          ),
        ),
    ],
    connections: workflow.connections,
  );
}

List<WorkflowAgentId> _listOrder(Workflow workflow) {
  return <WorkflowAgentId>[
    for (final WorkflowAgent agent in orderAgents(workflow)) agent.id,
  ];
}

void main() {
  test('test_list_unplaced_steps_property_moves_count_by_order', () {
    final Random random = seededRandom(67703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final Workflow moved = _moveEveryStep(random, workflow);
      final bool keepsOrder = listEquals(
        _listOrder(workflow),
        _listOrder(moved),
      );

      expect(hasSameSignedContent(workflow, moved), keepsOrder);
    }
  });

  test('test_has_same_signed_content_property_signature_is_ignored', () {
    final Random random = seededRandom(67704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final Workflow resigned = replaceSignature(
        workflow,
        workflow.signature == null ? buildSampleSignature() : null,
      );

      expect(hasSameSignedContent(workflow, resigned), isTrue);
    }
  });

  test('test_has_same_signed_content_property_transitive', () {
    final Random random = seededRandom(67717);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow first = _randomWorkflow(random, i);
      final Workflow second = _shiftEveryStep(first, 7);
      final Workflow third = _shiftEveryStep(second, 11);

      expect(hasSameSignedContent(first, second), isTrue);
      expect(hasSameSignedContent(second, third), isTrue);
      expect(hasSameSignedContent(first, third), isTrue);
    }
  });

  test('test_list_unplaced_steps_property_shifts_keep_order', () {
    final Random random = seededRandom(67718);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final Workflow shifted = _shiftEveryStep(
        workflow,
        random.nextInt(500).toDouble(),
      );

      expect(listEquals(_listOrder(workflow), _listOrder(shifted)), isTrue);
      expect(hasSameSignedContent(workflow, shifted), isTrue);
    }
  });

  test('test_list_unplaced_steps_property_list_order_is_ignored', () {
    final Random random = seededRandom(67719);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final List<WorkflowAgent> shuffled = List<WorkflowAgent>.of(
        workflow.agents,
      );
      shuffled.shuffle(random);
      final Workflow reordered = workflow.withGraph(
        agents: shuffled,
        connections: workflow.connections,
      );

      expect(hasSameSignedContent(workflow, reordered), isTrue);
    }
  });

  test('test_has_same_signed_content_property_moves_follow_order', () {
    final Random random = seededRandom(67720);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final Workflow moved = _moveEveryStep(random, workflow);

      expect(
        hasSameSignedContent(workflow, moved),
        listEquals(_listOrder(workflow), _listOrder(moved)),
      );
      expect(hasSameDesign(workflow, moved), workflow.agents.isEmpty);
    }
  });

  test('test_has_same_signed_content_property_renames_count', () {
    final Random random = seededRandom(67721);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent first = workflow.agents.first;
      final WorkflowAgent renamed = first.copyWith(name: '${first.name}-x');
      final Workflow moved = _shiftEveryStep(
        replaceAgent(workflow, renamed),
        3,
      );

      expect(hasSameSignedContent(workflow, moved), isFalse);
    }
  });
}
