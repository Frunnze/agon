import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import 'support/workflow_view_values.dart';

const String _addedSubject = 'Added';
const String _removedSubject = 'Removed';

List<List<String>> _describeDifferences(List<WorkflowDifference> differences) {
  return <List<String>>[
    for (final WorkflowDifference difference in differences)
      <String>[difference.subject, difference.change],
  ];
}

List<node.DiffLine> _insertUnchangedLines(
  Random random,
  List<node.DiffLine> lines,
) {
  final List<node.DiffLine> padded = List<node.DiffLine>.of(lines);
  final int insertedCount = 1 + random.nextInt(4);
  for (int i = 0; i < insertedCount; i += 1) {
    final node.DiffLine unchanged = node.DiffLine(
      change: node.DiffLineChange.unchanged,
      text: randomDocumentLine(random),
    );
    padded.insert(random.nextInt(padded.length + 1), unchanged);
  }
  return padded;
}

Map<String, Object?> _changedViewJson(Random random) {
  return buildNodeRuleViewJson(random, node.SignatureState.changedNotSigned);
}

void main() {
  test('test_list_document_differences_property_keeps_order_and_text', () {
    final Random random = seededRandom(74101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = randomNodeDiffLines(
        random,
        leastCount: 0,
      );
      final List<List<String>> expected = <List<String>>[
        for (final node.DiffLine line in lines)
          if (line.change == node.DiffLineChange.added)
            <String>[_addedSubject, line.text]
          else if (line.change == node.DiffLineChange.removed)
            <String>[_removedSubject, line.text],
      ];

      expect(_describeDifferences(listDocumentDifferences(lines)), expected);
    }
  });

  test('test_list_document_differences_property_unchanged_lines_add_none', () {
    final Random random = seededRandom(74102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = randomNodeDiffLines(
        random,
        leastCount: 0,
      );
      final List<node.DiffLine> padded = _insertUnchangedLines(random, lines);

      expect(
        _describeDifferences(listDocumentDifferences(padded)),
        _describeDifferences(listDocumentDifferences(lines)),
      );
    }
  });

  test('test_list_document_differences_property_result_is_frozen', () {
    final Random random = seededRandom(74103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowDifference> differences = listDocumentDifferences(
        randomNodeDiffLines(random, leastCount: 0),
      );
      const WorkflowDifference extra = WorkflowDifference(
        subject: _addedSubject,
        change: '',
      );

      expect(() => differences.add(extra), throwsUnsupportedError);
    }
  });

  test('test_summarize_document_changes_property_ignores_line_order', () {
    final Random random = seededRandom(74104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = randomNodeDiffLines(
        random,
        leastCount: 0,
      );
      final List<node.DiffLine> shuffled = List<node.DiffLine>.of(lines);
      shuffled.shuffle(random);

      expect(
        summarizeDocumentChanges(shuffled),
        summarizeDocumentChanges(lines),
      );
    }
  });

  test('test_summarize_document_changes_property_agrees_with_differences', () {
    final Random random = seededRandom(74105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = randomNodeDiffLines(
        random,
        leastCount: 0,
      );
      final List<WorkflowDifference> differences = listDocumentDifferences(
        lines,
      );
      int addedCount = 0;
      int removedCount = 0;
      for (final WorkflowDifference difference in differences) {
        if (difference.subject == _addedSubject) {
          addedCount += 1;
        } else {
          removedCount += 1;
        }
      }

      expect(
        summarizeDocumentChanges(lines),
        'Lines added: $addedCount, removed: $removedCount',
      );
    }
  });

  test('test_summarize_document_changes_property_unchanged_count_nothing', () {
    final Random random = seededRandom(74106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = randomNodeDiffLines(
        random,
        leastCount: 0,
      );
      final List<node.DiffLine> padded = _insertUnchangedLines(random, lines);
      final List<node.DiffLine> onlyUnchanged = _insertUnchangedLines(
        random,
        const <node.DiffLine>[],
      );

      expect(
        summarizeDocumentChanges(padded),
        summarizeDocumentChanges(lines),
      );
      expect(
        summarizeDocumentChanges(onlyUnchanged),
        'Lines added: 0, removed: 0',
      );
    }
  });

  test(
    'test_map_pending_change_from_node_property_only_for_changed_state',
    () {
      final Random random = seededRandom(74107);
      for (int i = 0; i < propertyIterations; i += 1) {
        final node.WorkflowView view = randomNodeRuleView(random);
        final bool isChanged =
            view.signatureState == node.SignatureState.changedNotSigned;

        expect(mapPendingChangeFromNode(view) != null, isChanged);
      }
    },
  );

  test('test_map_pending_change_from_node_property_holds_both_diff_sides', () {
    final Random random = seededRandom(74108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = node.WorkflowView.fromJson(
        _changedViewJson(random),
      );
      final WorkflowChange change = mapPendingChangeFromNode(view)!;
      final String changedSide = keepDocumentSide(
        view.changes,
        droppedChange: node.DiffLineChange.removed,
      );

      expect(change.workflowId, view.workflow.id);
      expect(change.changedBy, view.changedBy);
      expect(change.changedAt, view.changedAt);
      expect(change.signedDocument, expectSignedDocument(view));
      expect(change.changedDocument, changedSide);
      expect(change.summary, summarizeDocumentChanges(view.changes));
      expect(
        _describeDifferences(change.differences),
        _describeDifferences(listDocumentDifferences(view.changes)),
      );
    }
  });

  test(
    'test_map_pending_change_from_node_property_rejects_unsigned_change',
    () {
      final Random random = seededRandom(74109);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, Object?> json = _changedViewJson(random);
        final Map<String, Object?> workflow =
            json['workflow']! as Map<String, Object?>;
        json['workflow'] = <String, Object?>{...workflow, 'signature': null};
        final node.WorkflowView view = node.WorkflowView.fromJson(json);

        expect(() => mapPendingChangeFromNode(view), throwsFormatException);
      }
    },
  );

  test('test_map_pending_change_from_node_property_unknown_who_and_when', () {
    final Random random = seededRandom(74110);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = _changedViewJson(random);
      final String missingField = pickOne(random, <String>[
        'changed_at',
        'changed_by',
      ]);
      json[missingField] = null;
      final node.WorkflowView view = node.WorkflowView.fromJson(json);

      final WorkflowChange? change = mapPendingChangeFromNode(view);

      expect(change?.changedAt, view.changedAt);
      expect(change?.changedBy, view.changedBy);
      expect(change?.workflowId, view.workflow.id);
    }
  });
}
