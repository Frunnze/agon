import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_work_json.dart';
import '../../../support/random_inputs.dart';

const List<double> _edgeCoordinates = <double>[
  0,
  -0.0,
  -1,
  1e-300,
  -1e300,
  1e300,
  double.maxFinite,
  -double.maxFinite,
  double.minPositive,
];

const List<double> _nonFiniteCoordinates = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
];

node.WorkflowAgent _randomNodeAgent(Random random) {
  return node.WorkflowAgent.fromJson(randomWorkflowAgentJson(random));
}

node.WorkflowAgent _randomHostileNodeAgent(Random random) {
  return node.WorkflowAgent.fromJson(<String, Object?>{
    ...randomWorkflowAgentJson(random),
    'name': randomHostileText(random),
    'task': randomHostileText(random),
  });
}

node.AgentConnection _randomNodeConnection(Random random) {
  return node.AgentConnection.fromJson(randomAgentConnectionJson(random));
}

void main() {
  test('test_map_canvas_position_from_node_property_keeps_edge_values', () {
    final Random random = seededRandom(74401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final double horizontal = pickOne(random, _edgeCoordinates);
      final double vertical = pickOne(random, _edgeCoordinates);
      final CanvasPosition position = mapCanvasPositionFromNode(
        node.CanvasPosition(horizontal: horizontal, vertical: vertical),
      );

      expect(position.horizontal, horizontal);
      expect(position.vertical, vertical);
    }
  });

  test('test_map_canvas_position_from_node_property_equal_wires_agree', () {
    final Random random = seededRandom(74402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomCanvasPositionJson(random);

      expect(
        mapCanvasPositionFromNode(node.CanvasPosition.fromJson(json)),
        mapCanvasPositionFromNode(node.CanvasPosition.fromJson(json)),
      );
    }
  });

  test('test_map_canvas_position_to_node_property_model_round_trips', () {
    final Random random = seededRandom(74403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = CanvasPosition(
        horizontal: pickOne(random, _edgeCoordinates),
        vertical: random.nextDouble() * 4000 - 2000,
      );
      final node.CanvasPosition wire = mapCanvasPositionToNode(position);

      expect(mapCanvasPositionFromNode(wire), position);
    }
  });

  test('test_map_canvas_position_to_node_property_rejects_non_finite', () {
    final Random random = seededRandom(74404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final bool breaksHorizontal = random.nextBool();
      final double broken = pickOne(random, _nonFiniteCoordinates);
      final double finite = pickOne(random, _edgeCoordinates);
      final CanvasPosition position = CanvasPosition(
        horizontal: breaksHorizontal ? broken : finite,
        vertical: breaksHorizontal ? finite : broken,
      );

      expect(() => mapCanvasPositionToNode(position), throwsArgumentError);
    }
  });

  test('test_map_step_kind_from_node_property_is_one_to_one', () {
    final Set<StepKind> kinds = <StepKind>{
      for (final node.StepKind wire in node.StepKind.values)
        mapStepKindFromNode(wire),
    };

    expect(kinds, StepKind.values.toSet());
    expect(kinds.length, node.StepKind.values.length);
  });

  test('test_map_step_kind_from_node_property_keeps_the_kind_name', () {
    for (final node.StepKind wire in node.StepKind.values) {
      expect(mapStepKindFromNode(wire).name, wire.name);
    }
  });

  test('test_map_step_kind_from_node_property_agent_keeps_wire_kind', () {
    final Random random = seededRandom(74405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowAgent wire = _randomNodeAgent(random);
      final StepKind kind = mapWorkflowAgentFromNode(wire).stepKind;

      expect(mapStepKindToNode(kind).wireName, wire.stepKind.wireName);
    }
  });

  test('test_map_step_kind_to_node_property_model_round_trips', () {
    for (final StepKind kind in StepKind.values) {
      expect(mapStepKindFromNode(mapStepKindToNode(kind)), kind);
    }
  });

  test('test_map_step_kind_to_node_property_covers_rust_wire_names', () {
    final List<String> wireNames = <String>[
      for (final StepKind kind in StepKind.values)
        mapStepKindToNode(kind).wireName,
    ];

    expect(wireNames.toSet(), nodeStepKinds.toSet());
    expect(wireNames.length, nodeStepKinds.length);
  });

  test('test_map_step_kind_to_node_property_wire_name_decodes_back', () {
    for (final StepKind kind in StepKind.values) {
      final node.StepKind wire = mapStepKindToNode(kind);

      expect(node.StepKind.decode(wire.wireName), wire);
    }
  });

  test('test_map_workflow_agent_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(74406);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowAgent wire = _randomHostileNodeAgent(random);
      final WorkflowAgent agent = mapWorkflowAgentFromNode(wire);
      final node.AgentKind? wireKind = wire.kind;

      expect(agent.id, wire.id);
      expect(agent.name, wire.name);
      expect(agent.stepKind.name, wire.stepKind.name);
      expect(agent.kind?.name, wireKind?.name);
      expect(agent.task, wire.task);
      expect(
        mapRunnerTargetToNode(agent.runsOn).toJson(),
        wire.runsOn.toJson(),
      );
      expect(agent.skills, wire.skills);
      expect(agent.usesAutomaticSkills, wire.usesAutomaticSkills);
      expect(
        mapOptionalApprovalPolicyToNode(agent.approvalPolicy),
        wire.approvalPolicy,
      );
      expect(agent.position, mapCanvasPositionFromNode(wire.position));
    }
  });

  test('test_map_workflow_agent_from_node_property_skills_are_frozen', () {
    final Random random = seededRandom(74407);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = mapWorkflowAgentFromNode(
        _randomNodeAgent(random),
      );

      expect(agent.skills.clear, throwsUnsupportedError);
    }
  });

  test('test_map_workflow_agent_to_node_property_model_round_trips', () {
    final Random random = seededRandom(74408);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = mapWorkflowAgentFromNode(
        _randomHostileNodeAgent(random),
      );
      final node.WorkflowAgent wire = mapWorkflowAgentToNode(agent);

      expect(mapWorkflowAgentFromNode(wire), agent);
    }
  });

  test('test_map_workflow_agent_to_node_property_json_decodes_back', () {
    final Random random = seededRandom(74409);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = mapWorkflowAgentFromNode(
        _randomHostileNodeAgent(random),
      );
      final Map<String, Object?> json = mapWorkflowAgentToNode(agent).toJson();
      final node.WorkflowAgent decoded = node.WorkflowAgent.fromJson(json);

      expect(mapWorkflowAgentFromNode(decoded), agent);
    }
  });

  test('test_map_agent_connection_from_node_property_keeps_loop_data', () {
    final Random random = seededRandom(74410);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentConnection sample = _randomNodeConnection(random);
      final node.AgentConnection wire = node.AgentConnection(
        from: sample.from,
        to: sample.to,
        condition: random.nextBool() ? null : randomHostileText(random),
        roundLimit: random.nextBool() ? null : random.nextInt(1 << 31),
      );
      final AgentConnection connection = mapAgentConnectionFromNode(wire);

      expect(connection.condition, wire.condition);
      expect(connection.roundLimit, wire.roundLimit);
      expect(connection.isLoop, wire.roundLimit != null);
    }
  });

  test('test_map_agent_connection_from_node_property_self_loop_kept', () {
    final Random random = seededRandom(74411);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentConnection sample = _randomNodeConnection(random);
      final node.AgentConnection wire = node.AgentConnection(
        from: sample.from,
        to: sample.from,
        condition: sample.condition,
        roundLimit: sample.roundLimit,
      );
      final AgentConnection connection = mapAgentConnectionFromNode(wire);

      expect(connection.from, connection.to);
      expect(connection.from, wire.from);
    }
  });

  test('test_map_agent_connection_to_node_property_model_round_trips', () {
    final Random random = seededRandom(74412);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = mapAgentConnectionFromNode(
        _randomNodeConnection(random),
      );
      final node.AgentConnection wire = mapAgentConnectionToNode(connection);

      expect(mapAgentConnectionFromNode(wire), connection);
    }
  });

  test('test_map_agent_connection_to_node_property_keeps_cleared_fields', () {
    final Random random = seededRandom(74413);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = mapAgentConnectionFromNode(
        _randomNodeConnection(random),
      ).withCondition(null).withRoundLimit(null);
      final Map<String, Object?> json = mapAgentConnectionToNode(connection)
          .toJson();

      expect(json['condition'], isNull);
      expect(json['round_limit'], isNull);
      expect(json['from'], connection.from.value);
      expect(json['to'], connection.to.value);
    }
  });
}
