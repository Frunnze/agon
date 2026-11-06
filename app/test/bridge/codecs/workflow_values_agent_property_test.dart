import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/random_work_json.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';

const String _stepKindField = 'step_kind';

const Set<String> _requiredAgentFields = <String>{
  'id',
  'name',
  'task',
  'runs_on',
  'skills',
  'uses_automatic_skills',
  'position',
};

const Set<String> _nullableAgentFields = <String>{'kind', 'approval_policy'};

const Set<String> _everyAgentField = <String>{
  ..._requiredAgentFields,
  ..._nullableAgentFields,
  _stepKindField,
};

const WireCodec _workflowCodec = WireCodec(
  typeName: 'workflow',
  seed: 53700,
  buildJson: randomWorkflowJson,
  decode: Workflow.fromJson,
  requiredFields: <String>{
    'id',
    'name',
    'availability',
    'agents',
    'connections',
  },
  optionalFields: <String>{'signature'},
);

SkillId _buildSkillId(Random random) => SkillId(randomUuidText(random));

WorkflowAgent _buildAgent(Random random) {
  return WorkflowAgent.fromJson(randomWorkflowAgentJson(random));
}

WorkflowAgent _buildAgentWithSkills(Random random, List<SkillId> skills) {
  final WorkflowAgent template = _buildAgent(random);
  return WorkflowAgent(
    id: template.id,
    name: template.name,
    stepKind: template.stepKind,
    kind: template.kind,
    task: template.task,
    runsOn: template.runsOn,
    skills: skills,
    usesAutomaticSkills: template.usesAutomaticSkills,
    approvalPolicy: template.approvalPolicy,
    position: template.position,
  );
}

List<SkillId> _readSkills(WorkflowAgent agent) => agent.skills;

AgentConnection _buildConnection(Random random) {
  return AgentConnection.fromJson(randomAgentConnectionJson(random));
}

Workflow _buildWorkflow(
  Random random, {
  required List<WorkflowAgent> agents,
  required List<AgentConnection> connections,
}) {
  final Workflow template = Workflow.fromJson(randomWorkflowJson(random));
  return Workflow(
    id: template.id,
    name: template.name,
    availability: template.availability,
    agents: agents,
    connections: connections,
    signature: template.signature,
  );
}

Workflow _buildWorkflowWithAgents(Random random, List<WorkflowAgent> agents) {
  return _buildWorkflow(
    random,
    agents: agents,
    connections: <AgentConnection>[_buildConnection(random)],
  );
}

Workflow _buildWorkflowWithConnections(
  Random random,
  List<AgentConnection> connections,
) {
  return _buildWorkflow(
    random,
    agents: <WorkflowAgent>[_buildAgent(random)],
    connections: connections,
  );
}

List<WorkflowAgent> _readAgents(Workflow workflow) => workflow.agents;

List<AgentConnection> _readConnections(Workflow workflow) {
  return workflow.connections;
}

void main() {
  testWireDecodingProperties(_workflowCodec);
  testWireEncodingProperties(_workflowCodec);

  testListCopyProperties(
    const ListCopy<WorkflowAgent, SkillId>(
      testNamePrefix: 'test_workflow_agent_constructor_property_skills',
      seed: 53710,
      buildElement: _buildSkillId,
      construct: _buildAgentWithSkills,
      readList: _readSkills,
    ),
  );

  testListCopyProperties(
    const ListCopy<Workflow, WorkflowAgent>(
      testNamePrefix: 'test_workflow_constructor_property_agents',
      seed: 53720,
      buildElement: _buildAgent,
      construct: _buildWorkflowWithAgents,
      readList: _readAgents,
    ),
  );

  testListCopyProperties(
    const ListCopy<Workflow, AgentConnection>(
      testNamePrefix: 'test_workflow_constructor_property_connections',
      seed: 53730,
      buildElement: _buildConnection,
      construct: _buildWorkflowWithConnections,
      readList: _readConnections,
    ),
  );

  test(
    'test_workflow_agent_from_json_property_needs_every_required_field',
    () {
      final Random random = seededRandom(53740);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject wireJson = randomWorkflowAgentJson(random);
        expect(wireJson.keys.toSet(), equals(_everyAgentField));

        for (final String field in _requiredAgentFields) {
          final JsonObject shortenedJson = removeWireField(wireJson, field);
          final JsonObject nulledJson = replaceWireField(
            wireJson,
            field,
            null,
          );

          expect(
            () => WorkflowAgent.fromJson(shortenedJson),
            throwsFormatException,
          );
          expect(
            () => WorkflowAgent.fromJson(nulledJson),
            throwsFormatException,
          );
        }
      }
    },
  );

  test('test_workflow_agent_from_json_property_'
      'left_out_fields_read_as_none_or_an_agent_step', () {
    final Random random = seededRandom(53741);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkflowAgentJson(random);
      JsonObject shortenedJson = wireJson;
      final JsonObject expectedJson = Map<String, Object?>.of(wireJson);
      for (final String field in _nullableAgentFields) {
        if (random.nextBool()) {
          shortenedJson = removeWireField(shortenedJson, field);
          expectedJson[field] = null;
        }
      }
      if (random.nextBool()) {
        shortenedJson = removeWireField(shortenedJson, _stepKindField);
        expectedJson[_stepKindField] = StepKind.agent.wireName;
      }

      final WorkflowAgent agent = WorkflowAgent.fromJson(shortenedJson);

      expect(reencodeAsJsonText(agent), equals(expectedJson));
    }
  });

  test('test_workflow_agent_from_json_property_ignores_unknown_fields', () {
    final Random random = seededRandom(53742);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkflowAgentJson(random);
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final WorkflowAgent agent = WorkflowAgent.fromJson(widenedJson);

      expect(reencodeAsJsonText(agent), equals(wireJson));
    }
  });

  test(
    'test_workflow_agent_from_json_property_rejects_wrongly_typed_fields',
    () {
      final Random random = seededRandom(53743);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject wireJson = randomWorkflowAgentJson(random);

        expectWrongKindFieldsRejected(
          random,
          wireJson,
          WorkflowAgent.fromJson,
        );
      }
    },
  );

  test(
    'test_workflow_agent_to_json_property_is_plain_json_that_decodes_back',
    () {
      final Random random = seededRandom(53744);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkflowAgent agent = _buildAgent(random);
        final JsonObject encoded = agent.toJson();

        final WorkflowAgent decodedAgain = WorkflowAgent.fromJson(encoded);

        expect(reencodeAsJsonText(agent), equals(encoded));
        expect(decodedAgain.toJson(), equals(encoded));
      }
    },
  );

  test('test_workflow_agent_to_json_property_reproduces_the_node_json', () {
    final Random random = seededRandom(53745);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkflowAgentJson(random);

      final WorkflowAgent agent = WorkflowAgent.fromJson(wireJson);

      expect(reencodeAsJsonText(agent), equals(wireJson));
    }
  });

  test('test_workflow_agent_to_json_property_writes_every_node_field', () {
    final Random random = seededRandom(53746);

    for (int i = 0; i < propertyIterations; i += 1) {
      JsonObject requiredJson = randomWorkflowAgentJson(random);
      for (final String field in <String>{
        ..._nullableAgentFields,
        _stepKindField,
      }) {
        requiredJson = removeWireField(requiredJson, field);
      }

      final JsonObject encoded = WorkflowAgent.fromJson(requiredJson).toJson();

      expect(encoded.keys.toSet(), equals(_everyAgentField));
      expect(encoded[_stepKindField], StepKind.agent.wireName);
      for (final String field in _nullableAgentFields) {
        expect(encoded[field], isNull, reason: field);
      }
    }
  });
}
