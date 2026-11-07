import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import 'support/workflow_view_values.dart';

const String _sharedTablePath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'document_diff_cases.json';
const String _addedSubject = 'Added';
const String _removedSubject = 'Removed';
const List<String> _whiteSpaceCharacters = <String>[' ', '\t', ' ', '　'];
const int _longestIndentation = 6;

List<List<String>> _describeDifferences(List<WorkflowDifference> differences) {
  return <List<String>>[
    for (final WorkflowDifference difference in differences)
      <String>[difference.subject, difference.change],
  ];
}

List<List<String>> _expectShownLines(List<node.DiffLine> lines) {
  return <List<String>>[
    for (final node.DiffLine line in lines)
      if (line.change == node.DiffLineChange.added)
        <String>[_addedSubject, line.text]
      else if (line.change == node.DiffLineChange.removed)
        <String>[_removedSubject, line.text],
  ];
}

String _randomWhiteSpace(Random random) {
  final int length = random.nextInt(_longestIndentation);
  final StringBuffer whiteSpace = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    whiteSpace.write(pickOne(random, _whiteSpaceCharacters));
  }
  return whiteSpace.toString();
}

List<List<node.DiffLine>> _readSharedDiffs() {
  final String tableText = File(_sharedTablePath).readAsStringSync();
  final Object? table = jsonDecode(tableText);
  if (table is! Map<String, Object?>) {
    throw const FormatException('the shared diff table is no object');
  }
  final Object? cases = table['cases'];
  if (cases is! List<Object?>) {
    throw const FormatException('the shared diff table has no cases');
  }

  final List<List<node.DiffLine>> diffs = <List<node.DiffLine>>[];
  for (final Object? sharedCase in cases) {
    if (sharedCase is! Map<String, Object?>) {
      throw FormatException('a shared diff case is no object: $sharedCase');
    }
    final Object? diff = sharedCase['diff'];
    if (diff is! List<Object?>) {
      throw FormatException('a shared diff case has no diff: $sharedCase');
    }
    diffs.add(<node.DiffLine>[
      for (final Object? line in diff) node.DiffLine.fromJson(line),
    ]);
  }
  return diffs;
}

void main() {
  test('test_list_document_differences_property_agrees_with_shared_table', () {
    final List<List<node.DiffLine>> sharedDiffs = _readSharedDiffs();
    expect(sharedDiffs, isNotEmpty);

    for (final List<node.DiffLine> diff in sharedDiffs) {
      final List<WorkflowDifference> differences = listDocumentDifferences(
        diff,
      );

      expect(_describeDifferences(differences), _expectShownLines(diff));
    }
  });

  test('test_list_document_differences_property_shows_indentation_change', () {
    final Random random = seededRandom(75301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomDocumentLine(random);
      final String signedIndentation = _randomWhiteSpace(random);
      final String changedIndentation = _randomWhiteSpace(random);
      if (signedIndentation == changedIndentation) {
        continue;
      }
      final List<node.DiffLine> diff = <node.DiffLine>[
        node.DiffLine(
          change: node.DiffLineChange.removed,
          text: '$signedIndentation$text',
        ),
        node.DiffLine(
          change: node.DiffLineChange.added,
          text: '$changedIndentation$text',
        ),
      ];

      final List<WorkflowDifference> differences = listDocumentDifferences(
        diff,
      );

      expect(differences.length, 2);
      expect(differences.first.change, isNot(differences.last.change));
      expect(differences.first.change, startsWith(signedIndentation));
      expect(differences.last.change, startsWith(changedIndentation));
    }
  });

  test('test_list_document_differences_property_keeps_padding_exactly', () {
    final Random random = seededRandom(75302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> padded = <node.DiffLine>[
        for (final node.DiffLine line in randomNodeDiffLines(
          random,
          leastCount: 1,
        ))
          node.DiffLine(
            change: line.change,
            text:
                '${_randomWhiteSpace(random)}${line.text}'
                '${_randomWhiteSpace(random)}',
          ),
      ];

      final List<WorkflowDifference> differences = listDocumentDifferences(
        padded,
      );

      expect(_describeDifferences(differences), _expectShownLines(padded));
    }
  });
}
