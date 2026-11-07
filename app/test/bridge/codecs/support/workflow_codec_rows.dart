import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

import '../../support/random_work_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> workflowConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'canvas_position',
      buildJson: randomCanvasPositionJson,
      decode: CanvasPosition.fromJson,
    ),
    rebuild: _rebuildCanvasPosition,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'agent_connection',
      buildJson: randomAgentConnectionJson,
      decode: AgentConnection.fromJson,
    ),
    rebuild: _rebuildAgentConnection,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'diff_line',
      buildJson: randomDiffLineJson,
      decode: DiffLine.fromJson,
    ),
    rebuild: _rebuildDiffLine,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'draft_status',
      buildJson: randomDraftStatusJson,
      decode: DraftStatus.fromJson,
    ),
    rebuild: _rebuildDraftStatus,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'draft_working',
      buildJson: randomDraftWorkingJson,
      decode: DraftStatus.fromJson,
    ),
    rebuild: _rebuildDraftStatus,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'draft_done',
      buildJson: randomDraftDoneJson,
      decode: DraftStatus.fromJson,
    ),
    rebuild: _rebuildDraftStatus,
  ),
];

const List<EncodableRow> workflowEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'workflow_agent',
    buildJson: randomWorkflowAgentJson,
    decode: WorkflowAgent.fromJson,
  ),
  EncodableRow(
    typeName: 'workflow_signature',
    buildJson: randomWorkflowSignatureJson,
    decode: WorkflowSignature.fromJson,
  ),
  EncodableRow(
    typeName: 'workflow',
    buildJson: randomWorkflowJson,
    decode: Workflow.fromJson,
  ),
  EncodableRow(
    typeName: 'workflow_view',
    buildJson: randomWorkflowViewJson,
    decode: WorkflowView.fromJson,
  ),
];

Object? randomDraftWorkingJson(Random random) {
  return randomJsonOfKind<DraftWorking>(
    random: random,
    buildJson: randomDraftStatusJson,
    decode: DraftStatus.fromJson,
  );
}

Object? randomDraftDoneJson(Random random) {
  return randomJsonOfKind<DraftDone>(
    random: random,
    buildJson: randomDraftStatusJson,
    decode: DraftStatus.fromJson,
  );
}

JsonEncodable _rebuildCanvasPosition(JsonEncodable value) {
  final CanvasPosition position = value as CanvasPosition;
  return CanvasPosition(
    horizontal: position.horizontal,
    vertical: position.vertical,
  );
}

JsonEncodable _rebuildAgentConnection(JsonEncodable value) {
  final AgentConnection connection = value as AgentConnection;
  return AgentConnection(
    from: connection.from,
    to: connection.to,
    condition: connection.condition,
    roundLimit: connection.roundLimit,
  );
}

JsonEncodable _rebuildDiffLine(JsonEncodable value) {
  final DiffLine line = value as DiffLine;
  return DiffLine(change: line.change, text: line.text);
}

JsonEncodable _rebuildDraftStatus(JsonEncodable value) {
  final DraftStatus status = value as DraftStatus;
  return switch (status) {
    DraftWorking() => const DraftWorking(),
    DraftDone(:final WorkflowView workflow) => DraftDone(workflow: workflow),
  };
}
