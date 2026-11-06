import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

import '../../support/random_inputs.dart';
import '../support/random_work_json.dart';
import '../support/tagged_wire_union_properties.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';

const String _stateField = 'state';
const String _workflowField = 'workflow';
const List<String> _nodeDraftStates = <String>['working', 'done'];

const List<WireCodec> _draftCodecs = <WireCodec>[
  WireCodec(
    typeName: 'draft_working',
    seed: 53900,
    buildJson: _buildWorkingJson,
    decode: DraftStatus.fromJson,
    requiredFields: <String>{_stateField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'draft_done',
    seed: 53910,
    buildJson: _buildDoneJson,
    decode: DraftStatus.fromJson,
    requiredFields: <String>{_stateField, _workflowField},
    optionalFields: <String>{},
  ),
];

JsonObject _buildWorkingJson(Random random) {
  return <String, Object?>{_stateField: DraftWorking.state};
}

JsonObject _buildDoneJson(Random random) {
  return <String, Object?>{
    _stateField: DraftDone.state,
    _workflowField: randomWorkflowViewJson(random),
  };
}

String _readDraftState(JsonEncodable status) {
  return switch (status) {
    DraftWorking() => 'working',
    DraftDone() => 'done',
    _ => throw StateError('not a draft status: $status'),
  };
}

void main() {
  for (final WireCodec codec in _draftCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testTaggedWireUnionProperties(
    const TaggedWireUnion(
      typeName: 'draft_status',
      seed: 53920,
      tagField: _stateField,
      nodeTags: _nodeDraftStates,
      buildJson: randomDraftStatusJson,
      decode: DraftStatus.fromJson,
      readVariantTag: _readDraftState,
    ),
  );

  test('test_draft_status_from_json_property_'
      'working_drops_a_stray_workflow', () {
    final Random random = seededRandom(53930);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject strayJson = <String, Object?>{
        _stateField: DraftWorking.state,
        _workflowField: randomWorkflowViewJson(random),
      };

      final DraftStatus status = DraftStatus.fromJson(strayJson);

      expect(status, isA<DraftWorking>());
      expect(status.toJson(), equals(_buildWorkingJson(random)));
    }
  });

  test('test_draft_done_to_json_property_keeps_the_whole_workflow_view', () {
    final Random random = seededRandom(53931);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowView workflow = WorkflowView.fromJson(
        randomWorkflowViewJson(random),
      );
      final DraftDone done = DraftDone(workflow: workflow);

      final DraftStatus decodedAgain = DraftStatus.fromJson(
        reencodeAsJsonText(done),
      );

      expect(decodedAgain, isA<DraftDone>());
      final DraftDone decodedDone = decodedAgain as DraftDone;
      expect(decodedDone.workflow.toJson(), equals(workflow.toJson()));
    }
  });

  test('test_draft_working_to_json_property_writes_only_the_state', () {
    const DraftWorking working = DraftWorking();

    final JsonObject workingJson = working.toJson();

    expect(workingJson.keys, orderedEquals(<String>[_stateField]));
    expect(_nodeDraftStates, contains(workingJson[_stateField]));
    expect(DraftStatus.fromJson(workingJson), isA<DraftWorking>());
  });
}
