import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_wire_names.dart';
import '../support/random_typed_values.dart';
import '../support/random_work_json.dart';
import '../support/utc_offset_moments.dart' show randomMicrosecondMoment;
import '../support/wire_codec_properties.dart';
import '../support/wire_contract_checks.dart' show expectOptionalUtcMomentText;
import '../support/wire_json_edits.dart';
import '../support/wire_name_decoder_properties.dart';

const int _firstFamilySeed = 53800;
const int _seedsPerFamily = 2;

const List<WireNameDecoderFamily> _viewFamilies = <WireNameDecoderFamily>[
  WireNameDecoderFamily(
    typeName: 'signature_state',
    choices: SignatureState.values,
    nodeNames: nodeSignatureStates,
    decode: SignatureState.decode,
  ),
  WireNameDecoderFamily(
    typeName: 'diff_line_change',
    choices: DiffLineChange.values,
    nodeNames: nodeDiffChanges,
    decode: DiffLineChange.decode,
  ),
];

const WireCodec _workflowViewCodec = WireCodec(
  typeName: 'workflow_view',
  seed: 53810,
  buildJson: randomWorkflowViewJson,
  decode: WorkflowView.fromJson,
  requiredFields: <String>{
    'workflow',
    'agent_names',
    'document',
    'signature_state',
    'changes',
  },
  optionalFields: <String>{
    'signed_at',
    'changed_at',
    'changed_by',
    'changed_by_name',
  },
);

DiffLine _buildDiffLine(Random random) {
  return DiffLine.fromJson(randomDiffLineJson(random));
}

WorkflowView _rebuildView(
  WorkflowView template, {
  required List<String> agentNames,
  required List<DiffLine> changes,
  required DateTime? signedAt,
  required DateTime? changedAt,
}) {
  return WorkflowView(
    workflow: template.workflow,
    agentNames: agentNames,
    document: template.document,
    signatureState: template.signatureState,
    changes: changes,
    signedAt: signedAt,
    changedAt: changedAt,
    changedBy: template.changedBy,
    changedByName: template.changedByName,
  );
}

WorkflowView _buildTemplateView(Random random) {
  return WorkflowView.fromJson(randomWorkflowViewJson(random));
}

WorkflowView _buildViewWithNames(Random random, List<String> agentNames) {
  final WorkflowView template = _buildTemplateView(random);
  return _rebuildView(
    template,
    agentNames: agentNames,
    changes: template.changes,
    signedAt: template.signedAt,
    changedAt: template.changedAt,
  );
}

WorkflowView _buildViewWithChanges(Random random, List<DiffLine> changes) {
  final WorkflowView template = _buildTemplateView(random);
  return _rebuildView(
    template,
    agentNames: template.agentNames,
    changes: changes,
    signedAt: template.signedAt,
    changedAt: template.changedAt,
  );
}

List<String> _readAgentNames(WorkflowView view) => view.agentNames;

List<DiffLine> _readChanges(WorkflowView view) => view.changes;

DateTime? _randomOptionalMoment(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomMicrosecondMoment(random);
}

void main() {
  for (int index = 0; index < _viewFamilies.length; index += 1) {
    final WireNameDecoderFamily family = _viewFamilies[index];
    final int seed = _firstFamilySeed + index * _seedsPerFamily;

    testDecodeReadsEveryNodeName(family);
    testDecodeRejectsNearMissNames(family, seed);
    testDecodeRejectsAnythingButANodeName(family, seed + 1);
  }

  testWireDecodingProperties(_workflowViewCodec);
  testWireEncodingProperties(_workflowViewCodec);

  testListCopyProperties(
    const ListCopy<WorkflowView, String>(
      testNamePrefix: 'test_workflow_view_constructor_property_agent_names',
      seed: 53820,
      buildElement: randomHostileText,
      construct: _buildViewWithNames,
      readList: _readAgentNames,
    ),
  );

  testListCopyProperties(
    const ListCopy<WorkflowView, DiffLine>(
      testNamePrefix: 'test_workflow_view_constructor_property_changes',
      seed: 53830,
      buildElement: _buildDiffLine,
      construct: _buildViewWithChanges,
      readList: _readChanges,
    ),
  );

  test('test_workflow_view_to_json_property_writes_moments_as_utc_text', () {
    final Random random = seededRandom(53840);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowView template = _buildTemplateView(random);
      final DateTime? signedAt = _randomOptionalMoment(random);
      final DateTime? changedAt = _randomOptionalMoment(random);
      final WorkflowView view = _rebuildView(
        template,
        agentNames: template.agentNames,
        changes: template.changes,
        signedAt: signedAt,
        changedAt: changedAt,
      );

      final JsonObject viewJson = view.toJson();

      expectOptionalUtcMomentText(viewJson['signed_at'], signedAt);
      expectOptionalUtcMomentText(viewJson['changed_at'], changedAt);
    }
  });

  test(
    'test_workflow_view_from_json_property_keeps_the_changed_by_device',
    () {
      final Random random = seededRandom(53857);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String deviceText = randomDeviceId(random).value;
        final JsonObject wireJson = replaceWireField(
          randomWorkflowViewJson(random),
          'changed_by',
          deviceText,
        );

        final WorkflowView view = WorkflowView.fromJson(wireJson);

        expect(view.changedBy?.value, deviceText);
      }
    },
  );
}
