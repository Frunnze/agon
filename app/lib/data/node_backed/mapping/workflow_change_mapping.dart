import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

const String _addedSubject = 'Added';
const String _removedSubject = 'Removed';

List<WorkflowDifference> listDocumentDifferences(List<node.DiffLine> lines) {
  final List<WorkflowDifference> differences = <WorkflowDifference>[];

  for (final node.DiffLine line in lines) {
    switch (line.change) {
      case node.DiffLineChange.unchanged:
        continue;
      case node.DiffLineChange.added:
        differences.add(
          WorkflowDifference(subject: _addedSubject, change: line.text),
        );
      case node.DiffLineChange.removed:
        differences.add(
          WorkflowDifference(subject: _removedSubject, change: line.text),
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
  checkSignatureMatchesState(view);
  if (view.signatureState != node.SignatureState.changedNotSigned) {
    return null;
  }

  return WorkflowChange(
    workflowId: view.workflow.id,
    changedBy: view.changedBy,
    changedAt: view.changedAt,
    summary: summarizeDocumentChanges(view.changes),
    differences: listDocumentDifferences(view.changes),
    signedDocument: readSignedDocument(view),
    changedDocument: view.document,
  );
}
