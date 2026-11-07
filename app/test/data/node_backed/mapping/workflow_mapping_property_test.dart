import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/screens/workflows/workflow_text.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../support/random_inputs.dart';
import 'support/workflow_view_values.dart';

List<Object?> _encodeAgents(List<WorkflowAgent> agents) {
  return <Object?>[
    for (final WorkflowAgent agent in agents)
      mapWorkflowAgentToNode(agent).toJson(),
  ];
}

List<Object?> _encodeConnections(List<AgentConnection> connections) {
  return <Object?>[
    for (final AgentConnection connection in connections)
      mapAgentConnectionToNode(connection).toJson(),
  ];
}

List<node.DiffLine> _insertAddedLines(
  Random random,
  List<node.DiffLine> lines,
) {
  final List<node.DiffLine> padded = List<node.DiffLine>.of(lines);
  final int insertedCount = 1 + random.nextInt(4);
  for (int i = 0; i < insertedCount; i += 1) {
    final node.DiffLine added = node.DiffLine(
      change: node.DiffLineChange.added,
      text: randomDocumentLine(random),
    );
    padded.insert(random.nextInt(padded.length + 1), added);
  }
  return padded;
}

node.WorkflowView _randomViewIn(Random random, node.SignatureState state) {
  return node.WorkflowView.fromJson(buildNodeRuleViewJson(random, state));
}

void main() {
  test('test_read_signed_document_property_rebuilds_the_signed_side', () {
    final Random random = seededRandom(74201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomViewIn(
        random,
        node.SignatureState.changedNotSigned,
      );
      final String signedSide = keepDocumentSide(
        view.changes,
        droppedChange: node.DiffLineChange.added,
      );

      expect(readSignedDocument(view), signedSide);
    }
  });

  test(
    'test_read_signed_document_property_unchanged_view_is_its_document',
    () {
      final Random random = seededRandom(74202);
      for (int i = 0; i < propertyIterations; i += 1) {
        final node.SignatureState state = pickOne(
          random,
          <node.SignatureState>[
            node.SignatureState.signed,
            node.SignatureState.notSignedYet,
          ],
        );
        final node.WorkflowView view = _randomViewIn(random, state);

        expect(readSignedDocument(view), view.document);
      }
    },
  );

  test('test_read_signed_document_property_added_lines_change_nothing', () {
    final Random random = seededRandom(74203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomViewIn(
        random,
        node.SignatureState.changedNotSigned,
      );
      final node.WorkflowView padded = replaceViewChanges(
        view,
        _insertAddedLines(random, view.changes),
      );

      expect(readSignedDocument(padded), readSignedDocument(view));
    }
  });

  test('test_map_workflow_from_node_property_keeps_every_graph_field', () {
    final Random random = seededRandom(74204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = randomNodeRuleView(random);
      final node.Workflow wire = view.workflow;
      final Workflow workflow = mapWorkflowFromNode(view);

      expect(workflow.id, wire.id);
      expect(workflow.name, wire.name);
      expect(
        mapWorkspaceScopeToNode(workflow.availability).toJson(),
        wire.availability.toJson(),
      );
      expect(_encodeAgents(workflow.agents), wire.toJson()['agents']);
      expect(
        _encodeConnections(workflow.connections),
        wire.toJson()['connections'],
      );
    }
  });

  test('test_map_workflow_from_node_property_shown_state_is_node_state', () {
    final Random random = seededRandom(74205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = randomNodeRuleView(random);
      final SignatureState shownState = findSignatureState(
        mapWorkflowFromNode(view),
        mapPendingChangeFromNode(view),
      );

      expect(shownState, readModelSignatureState(view.signatureState));
    }
  });

  test('test_map_workflow_from_node_property_graph_lists_are_frozen', () {
    final Random random = seededRandom(74206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = mapWorkflowFromNode(
        randomNodeRuleView(random),
      );

      expect(workflow.agents.clear, throwsUnsupportedError);
      expect(workflow.connections.clear, throwsUnsupportedError);
    }
  });

  test('test_map_workflow_to_node_property_model_round_trips', () {
    final Random random = seededRandom(74207);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = mapWorkflowFromNode(
        randomNodeRuleView(random),
      );
      final node.Workflow wire = mapWorkflowToNode(workflow);
      final node.WorkflowView unsignedView = node.WorkflowView.fromJson(
        <String, Object?>{
          ...buildNodeRuleViewJson(random, node.SignatureState.notSignedYet),
          'workflow': wire.toJson(),
        },
      );
      final Workflow returned = mapWorkflowFromNode(unsignedView);

      expect(returned.id, workflow.id);
      expect(returned.name, workflow.name);
      expect(returned.agents, workflow.agents);
      expect(returned.connections, workflow.connections);
      expect(returned.signature, isNull);
    }
  });

  test('test_map_workflow_to_node_property_sends_a_renamed_workflow', () {
    final Random random = seededRandom(74208);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = mapWorkflowFromNode(
        randomNodeRuleView(random),
      );
      final String newName = randomHostileText(random);
      final Map<String, Object?> renamed = mapWorkflowToNode(
        workflow.withName(newName),
      ).toJson();

      expect(renamed, <String, Object?>{
        ...mapWorkflowToNode(workflow).toJson(),
        'name': newName,
      });
    }
  });

  test('test_map_workflow_to_node_property_keeps_graph_order', () {
    final Random random = seededRandom(74209);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = mapWorkflowFromNode(
        randomNodeRuleView(random),
      );
      final List<WorkflowAgent> agents = List<WorkflowAgent>.of(
        workflow.agents,
      );
      final List<AgentConnection> connections = List<AgentConnection>.of(
        workflow.connections,
      );
      agents.shuffle(random);
      connections.shuffle(random);
      final node.Workflow wire = mapWorkflowToNode(
        workflow.withGraph(agents: agents, connections: connections),
      );

      expect(
        <WorkflowAgentId>[
          for (final node.WorkflowAgent agent in wire.agents) agent.id,
        ],
        <WorkflowAgentId>[for (final WorkflowAgent agent in agents) agent.id],
      );
      expect(_encodeConnections(connections), wire.toJson()['connections']);
    }
  });
}
