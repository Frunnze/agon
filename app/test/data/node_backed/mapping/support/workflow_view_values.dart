import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../../../bridge/support/hostile_texts.dart';
import '../../../../bridge/support/node_json_primitives.dart';
import '../../../../bridge/support/random_work_json.dart';
import '../../../../support/random_inputs.dart';

const String documentLineBreak = '\n';
const String _lineBreakStandIn = ' ';
const int _largestLineCount = 7;

String randomDocumentLine(Random random) {
  final String text = randomHostileText(random);
  return text.replaceAll(documentLineBreak, _lineBreakStandIn);
}

node.DiffLine randomNodeDiffLine(Random random) {
  return node.DiffLine(
    change: pickOne(random, node.DiffLineChange.values),
    text: randomDocumentLine(random),
  );
}

List<node.DiffLine> randomNodeDiffLines(
  Random random, {
  required int leastCount,
}) {
  final int count = leastCount + random.nextInt(_largestLineCount);
  final List<node.DiffLine> lines = <node.DiffLine>[];
  for (int i = 0; i < count; i += 1) {
    lines.add(randomNodeDiffLine(random));
  }
  return lines;
}

String joinDocumentLines(List<String> lines) {
  final StringBuffer document = StringBuffer();
  for (final String line in lines) {
    document.write(line);
    document.write(documentLineBreak);
  }
  return document.toString();
}

String keepDocumentSide(
  List<node.DiffLine> changes, {
  required node.DiffLineChange droppedChange,
}) {
  final List<String> keptLines = <String>[
    for (final node.DiffLine line in changes)
      if (line.change != droppedChange) line.text,
  ];
  return joinDocumentLines(keptLines);
}

String _randomDocument(Random random) {
  final List<node.DiffLine> sourceLines = randomNodeDiffLines(
    random,
    leastCount: 1,
  );
  final List<String> lines = <String>[
    for (final node.DiffLine line in sourceLines) line.text,
  ];
  return joinDocumentLines(lines);
}

Map<String, Object?> buildNodeRuleViewJson(
  Random random,
  node.SignatureState state,
) {
  final bool hasSignature = state != node.SignatureState.notSignedYet;
  final bool isChanged = state == node.SignatureState.changedNotSigned;
  final List<node.DiffLine> changes = isChanged
      ? randomNodeDiffLines(random, leastCount: 1)
      : const <node.DiffLine>[];
  final String document = isChanged
      ? keepDocumentSide(changes, droppedChange: node.DiffLineChange.removed)
      : _randomDocument(random);
  final Map<String, Object?> workflow = <String, Object?>{
    ...randomWorkflowJson(random),
    'signature': hasSignature ? randomWorkflowSignatureJson(random) : null,
  };

  return <String, Object?>{
    ...randomWorkflowViewJson(random),
    'workflow': workflow,
    'document': document,
    'signature_state': state.wireName,
    'changes': <Object?>[
      for (final node.DiffLine line in changes) line.toJson(),
    ],
    'signed_at': hasSignature ? randomMomentText(random) : null,
    'changed_at': isChanged
        ? randomMomentText(random)
        : randomOptional(random, randomMomentText),
    'changed_by': isChanged
        ? randomDeviceIdText(random)
        : randomOptional(random, randomDeviceIdText),
  };
}

node.WorkflowView randomNodeRuleView(Random random) {
  final node.SignatureState state = pickOne(
    random,
    node.SignatureState.values,
  );
  return node.WorkflowView.fromJson(buildNodeRuleViewJson(random, state));
}

String expectSignedDocument(node.WorkflowView view) {
  if (view.changes.isEmpty) {
    return view.document;
  }
  return keepDocumentSide(
    view.changes,
    droppedChange: node.DiffLineChange.added,
  );
}

SignatureState readModelSignatureState(node.SignatureState state) {
  return SignatureState.values.byName(state.name);
}

node.WorkflowView replaceViewChanges(
  node.WorkflowView view,
  List<node.DiffLine> changes,
) {
  return node.WorkflowView(
    workflow: view.workflow,
    agentNames: view.agentNames,
    document: view.document,
    signatureState: view.signatureState,
    changes: changes,
    signedAt: view.signedAt,
    changedAt: view.changedAt,
    changedBy: view.changedBy,
    changedByName: view.changedByName,
  );
}
