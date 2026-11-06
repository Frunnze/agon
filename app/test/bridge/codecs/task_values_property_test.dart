import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_typed_values.dart';
import '../support/random_wire_values.dart';
import '../support/random_work_json.dart';
import '../support/tagged_wire_union_properties.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_decoder_properties.dart';

const String _kindField = 'kind';
const List<String> _nodeDoerKinds = <String>['one_agent', 'workflow'];

const WireNameDecoderFamily _taskStatusFamily = WireNameDecoderFamily(
  typeName: 'task_status',
  choices: TaskStatus.values,
  nodeNames: nodeTaskStatuses,
  decode: TaskStatus.decode,
);

const List<WireCodec> _taskValueCodecs = <WireCodec>[
  WireCodec(
    typeName: 'one_agent',
    seed: 53200,
    buildJson: _buildOneAgentJson,
    decode: TaskDoer.fromJson,
    requiredFields: <String>{_kindField, 'agent'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'workflow_doer',
    seed: 53210,
    buildJson: _buildWorkflowDoerJson,
    decode: TaskDoer.fromJson,
    requiredFields: <String>{_kindField, 'workflow_id'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'task_summary',
    seed: 53220,
    buildJson: randomTaskSummaryJson,
    decode: TaskSummary.fromJson,
    requiredFields: <String>{
      'to_do',
      'running',
      'waiting_for_approval',
      'failed',
      'done',
    },
    optionalFields: <String>{},
  ),
];

JsonObject _buildOneAgentJson(Random random) {
  return <String, Object?>{
    _kindField: OneAgent.kind,
    'agent': pickOne(random, nodeAgentKinds),
  };
}

JsonObject _buildWorkflowDoerJson(Random random) {
  return <String, Object?>{
    _kindField: WorkflowDoer.kind,
    'workflow_id': randomUuidText(random),
  };
}

String _readDoerKind(JsonEncodable doer) {
  return switch (doer) {
    OneAgent() => 'one_agent',
    WorkflowDoer() => 'workflow',
    _ => throw StateError('not a task doer: $doer'),
  };
}

int _readCountOf(TaskSummary summary, TaskStatus status) {
  return switch (status) {
    TaskStatus.toDo => summary.toDo,
    TaskStatus.running => summary.running,
    TaskStatus.waitingForApproval => summary.waitingForApproval,
    TaskStatus.failed => summary.failed,
    TaskStatus.done => summary.done,
  };
}

TaskSummary _buildDistinctSummary(Random random) {
  final int base = randomWholeNumber(random);
  return TaskSummary(
    toDo: base,
    running: base + 1,
    waitingForApproval: base + 2,
    failed: base + 3,
    done: base + 4,
  );
}

void main() {
  testDecodeReadsEveryNodeName(_taskStatusFamily);
  testDecodeRejectsNearMissNames(_taskStatusFamily, 53230);
  testDecodeRejectsAnythingButANodeName(_taskStatusFamily, 53231);

  for (final WireCodec codec in _taskValueCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testTaggedWireUnionProperties(
    const TaggedWireUnion(
      typeName: 'task_doer',
      seed: 53240,
      tagField: _kindField,
      nodeTags: _nodeDoerKinds,
      buildJson: randomTaskDoerJson,
      decode: TaskDoer.fromJson,
      readVariantTag: _readDoerKind,
    ),
  );

  test('test_one_agent_to_json_property_keeps_the_agent_given', () {
    for (final AgentKind agent in AgentKind.values) {
      final TaskDoer decoded = TaskDoer.fromJson(
        reencodeAsJsonText(OneAgent(agent: agent)),
      );

      expect(decoded, isA<OneAgent>());
      expect((decoded as OneAgent).agent, agent);
    }
  });

  test('test_workflow_doer_to_json_property_keeps_the_workflow_given', () {
    final Random random = seededRandom(53250);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowDoer doer = WorkflowDoer(
        workflowId: randomWorkflowId(random),
      );

      final TaskDoer decoded = TaskDoer.fromJson(reencodeAsJsonText(doer));

      expect(decoded, isA<WorkflowDoer>());
      expect((decoded as WorkflowDoer).workflowId, doer.workflowId);
    }
  });

  test('test_task_summary_to_json_property_'
      'files_each_count_under_its_status_name', () {
    final Random random = seededRandom(53251);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSummary summary = _buildDistinctSummary(random);

      final JsonObject summaryJson = summary.toJson();

      expect(summaryJson.keys.toSet(), equals(nodeTaskStatuses.toSet()));
      for (final TaskStatus status in TaskStatus.values) {
        final int expectedCount = _readCountOf(summary, status);
        expect(summaryJson[status.wireName], expectedCount);
      }
    }
  });

  test('test_task_summary_from_json_property_'
      'reads_each_status_count_exactly', () {
    final Random random = seededRandom(53252);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject summaryJson = <String, Object?>{};
      for (final String status in nodeTaskStatuses) {
        summaryJson[status] = randomWholeNumber(random);
      }

      final TaskSummary summary = TaskSummary.fromJson(summaryJson);

      for (final TaskStatus status in TaskStatus.values) {
        final Object? expectedCount = summaryJson[status.wireName];
        expect(_readCountOf(summary, status), expectedCount);
      }
    }
  });
}
