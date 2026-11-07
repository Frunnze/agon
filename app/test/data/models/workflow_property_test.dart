import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/domain_model_properties.dart';
import 'support/random_run_records.dart';
import 'support/value_equality_properties.dart';

const String _sharedWireCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'workflow_wire_cases.json';

const int _byteValueCount = 256;

const List<double> _closeCoordinates = <double>[
  0.0,
  -0.0,
  0.5,
  1.0,
  -1.0,
  1e300,
  double.minPositive,
  double.maxFinite,
];

double _randomCloseCoordinate(Random random) {
  return pickOne(random, _closeCoordinates);
}

CanvasPosition _randomClosePosition(Random random) {
  return CanvasPosition(
    horizontal: _randomCloseCoordinate(random),
    vertical: _randomCloseCoordinate(random),
  );
}

SignatureState _mapSignatureStateByName(node.SignatureState state) {
  return SignatureState.values.byName(state.name);
}

List<String> _readSharedSignatureStates() {
  final String sharedText = File(_sharedWireCasesPath).readAsStringSync();
  final Map<String, Object?> cases =
      jsonDecode(sharedText) as Map<String, Object?>;
  final List<Object?> names = cases['signature_states']! as List<Object?>;

  return <String>[for (final Object? name in names) name! as String];
}

WorkflowDifference _randomDifference(Random random) {
  return WorkflowDifference(
    subject: randomHostileText(random),
    change: randomHostileText(random),
  );
}

WorkflowSignature _buildSignatureWithBytes(Random random, List<int> bytes) {
  return WorkflowSignature(
    signedBy: randomDeviceId(random),
    signature: bytes,
    signedDocument: randomHostileText(random),
    signedAt: randomPreciseMoment(random),
  );
}

WorkflowChange _buildChangeWithDifferences(
  Random random,
  List<WorkflowDifference> differences,
) {
  return WorkflowChange(
    workflowId: randomWorkflowId(random),
    changedBy: randomDeviceId(random),
    changedAt: randomPreciseMoment(random),
    summary: randomHostileText(random),
    differences: differences,
    signedDocument: randomHostileText(random),
    changedDocument: randomHostileText(random),
  );
}

void main() {
  testEnumLabelProperties(
    testNamePrefix: 'test_agent_kind_label_property',
    choices: AgentKind.values,
    readLabel: (AgentKind kind) => kind.label,
  );

  const NodeEnumMapping<AgentKind, node.AgentKind> agentKindMapping =
      NodeEnumMapping<AgentKind, node.AgentKind>(
        testNamePrefix: 'test_agent_kind_values_property',
        choices: AgentKind.values,
        nodeChoices: node.AgentKind.values,
        mapFromNode: mapAgentKindFromNode,
      );
  testNodeEnumMappingProperties(agentKindMapping);
  testNodeEnumRoundTripProperty(agentKindMapping, mapAgentKindToNode);

  const NodeEnumMapping<StepKind, node.StepKind> stepKindMapping =
      NodeEnumMapping<StepKind, node.StepKind>(
        testNamePrefix: 'test_step_kind_values_property',
        choices: StepKind.values,
        nodeChoices: node.StepKind.values,
        mapFromNode: mapStepKindFromNode,
      );
  testNodeEnumMappingProperties(stepKindMapping);
  testNodeEnumRoundTripProperty(stepKindMapping, mapStepKindToNode);

  testNodeEnumMappingProperties(
    const NodeEnumMapping<SignatureState, node.SignatureState>(
      testNamePrefix: 'test_signature_state_values_property',
      choices: SignatureState.values,
      nodeChoices: node.SignatureState.values,
      mapFromNode: _mapSignatureStateByName,
    ),
  );

  test('test_signature_state_values_property_match_the_shared_table', () {
    final List<String> sharedNames = _readSharedSignatureStates();
    final List<String> wireNames = <String>[];

    for (final SignatureState state in SignatureState.values) {
      wireNames.add(node.SignatureState.values.byName(state.name).wireName);
    }

    expect(wireNames, sharedNames);
  });

  testModelConstructorProperties(
    ModelConstructor<CanvasPosition>(
      testNamePrefix: 'test_canvas_position_constructor_property',
      seed: 703501,
      randomFieldValues: (Random random) => <Object?>[
        randomCanvasCoordinate(random),
        _randomCloseCoordinate(random),
      ],
      construct: (ModelFieldValues fieldValues) => CanvasPosition(
        horizontal: fieldValues[0]! as double,
        vertical: fieldValues[1]! as double,
      ),
      readFieldValues: (CanvasPosition position) => <Object?>[
        position.horizontal,
        position.vertical,
      ],
    ),
  );

  testValueEqualityProperties(
    ValueEquality<CanvasPosition>(
      typeName: 'canvas_position',
      seed: 703511,
      randomValue: _randomClosePosition,
      copyValue: copyPosition,
      haveSameFields: (CanvasPosition first, CanvasPosition second) =>
          first.horizontal == second.horizontal &&
          first.vertical == second.vertical,
      otherKinds: <Object>[
        0.0,
        const Point<double>(0, 0),
        const <double>[0.0, 0.0],
        'CanvasPosition',
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<WorkflowSignature>(
      testNamePrefix: 'test_workflow_signature_constructor_property',
      seed: 703521,
      randomFieldValues: (Random random) => <Object?>[
        randomDeviceId(random),
        randomBytes(random),
        randomHostileText(random),
        randomPreciseMoment(random),
      ],
      construct: (ModelFieldValues fieldValues) => WorkflowSignature(
        signedBy: fieldValues[0]! as DeviceId,
        signature: fieldValues[1]! as List<int>,
        signedDocument: fieldValues[2]! as String,
        signedAt: fieldValues[3]! as DateTime,
      ),
      readFieldValues: (WorkflowSignature signature) => <Object?>[
        signature.signedBy,
        signature.signature,
        signature.signedDocument,
        signature.signedAt,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<WorkflowSignature, int>(
      testNamePrefix: 'test_workflow_signature_constructor_property_bytes',
      seed: 703531,
      buildElement: (Random random) => random.nextInt(_byteValueCount),
      construct: _buildSignatureWithBytes,
      readList: (WorkflowSignature signature) => signature.signature,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<WorkflowDifference>(
      testNamePrefix: 'test_workflow_difference_constructor_property',
      seed: 703541,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => WorkflowDifference(
        subject: fieldValues[0]! as String,
        change: fieldValues[1]! as String,
      ),
      readFieldValues: (WorkflowDifference difference) => <Object?>[
        difference.subject,
        difference.change,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<WorkflowChange>(
      testNamePrefix: 'test_workflow_change_constructor_property',
      seed: 703551,
      randomFieldValues: (Random random) => <Object?>[
        randomWorkflowId(random),
        randomDeviceId(random),
        randomPreciseMoment(random),
        randomHostileText(random),
        randomRecordsOf(random, _randomDifference),
        randomHostileText(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => WorkflowChange(
        workflowId: fieldValues[0]! as WorkflowId,
        changedBy: fieldValues[1]! as DeviceId,
        changedAt: fieldValues[2]! as DateTime,
        summary: fieldValues[3]! as String,
        differences: fieldValues[4]! as List<WorkflowDifference>,
        signedDocument: fieldValues[5]! as String,
        changedDocument: fieldValues[6]! as String,
      ),
      readFieldValues: (WorkflowChange change) => <Object?>[
        change.workflowId,
        change.changedBy,
        change.changedAt,
        change.summary,
        change.differences,
        change.signedDocument,
        change.changedDocument,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<WorkflowChange, WorkflowDifference>(
      testNamePrefix: 'test_workflow_change_constructor_property_differences',
      seed: 703561,
      buildElement: _randomDifference,
      construct: _buildChangeWithDifferences,
      readList: (WorkflowChange change) => change.differences,
    ),
  );
}
