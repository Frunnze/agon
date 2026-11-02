import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

const String _addedSubject = 'Added';
const String _removedSubject = 'Removed';

List<WorkflowDifference> listDocumentDifferences(List<node.DiffLine> lines) {
  final List<WorkflowDifference> differences = <WorkflowDifference>[];

  for (final node.DiffLine line in lines) {
    final String text = line.text.trim();
    switch (line.change) {
      case node.DiffLineChange.unchanged:
        continue;
      case node.DiffLineChange.added:
        differences.add(
          WorkflowDifference(subject: _addedSubject, change: text),
        );
      case node.DiffLineChange.removed:
        differences.add(
          WorkflowDifference(subject: _removedSubject, change: text),
        );
    }
  }
  return List<WorkflowDifference>.unmodifiable(differences);
}

String summarizeDocumentChanges(List<node.DiffLine> lines) {
  int addedCount = 0;
  int removedCount = 0;

  for (final node.DiffLine line in lines) {
    if (line.change == node.DiffLineChange.added) {
      addedCount += 1;
    }
    if (line.change == node.DiffLineChange.removed) {
      removedCount += 1;
    }
  }
  return 'Lines added: $addedCount, removed: $removedCount';
}

WorkflowChange? mapPendingChangeFromNode(node.WorkflowView view) {
  final node.WorkflowSignature? signature = view.workflow.signature;
  final bool isChanged =
      view.signatureState == node.SignatureState.changedNotSigned;
  if (!isChanged || signature == null) {
    return null;
  }

  final DateTime? changedAt = view.changedAt;
  final DeviceId? changedBy = view.changedBy;
  if (changedAt == null || changedBy == null) {
    throw FormatException(
      'the node sent changed workflow ${view.workflow.id} without who '
      'changed it and when',
    );
  }
  return WorkflowChange(
    workflowId: view.workflow.id,
    changedBy: changedBy,
    changedAt: changedAt,
    summary: summarizeDocumentChanges(view.changes),
    differences: listDocumentDifferences(view.changes),
    signedDocument: readSignedDocument(view),
    changedDocument: view.document,
  );
}
