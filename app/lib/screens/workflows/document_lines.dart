import 'dart:math';

import 'package:agent_orchestration/widgets/code_block.dart';

const int diffMarkerWidth = 2;
const String _unchangedMarker = '  ';
const String _removedMarker = '- ';
const String _addedMarker = '+ ';
const String _lineBreak = '\n';

List<String> _readLines(String document) {
  final List<String> lines = document.split(_lineBreak);
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

List<CodeBlockLine> splitDocumentLines(String document) {
  return <CodeBlockLine>[
    for (final String line in _readLines(document)) CodeBlockLine(line),
  ];
}

List<List<int>> _measureCommonTails(List<String> before, List<String> after) {
  final List<List<int>> lengths = <List<int>>[
    for (int row = 0; row <= before.length; row += 1)
      List<int>.filled(after.length + 1, 0),
  ];

  for (int row = before.length - 1; row >= 0; row -= 1) {
    for (int column = after.length - 1; column >= 0; column -= 1) {
      if (before[row] == after[column]) {
        lengths[row][column] = lengths[row + 1][column + 1] + 1;
      } else {
        lengths[row][column] = max(
          lengths[row + 1][column],
          lengths[row][column + 1],
        );
      }
    }
  }
  return lengths;
}

List<CodeBlockLine> diffDocumentLines(String before, String after) {
  final List<String> beforeLines = _readLines(before);
  final List<String> afterLines = _readLines(after);
  final List<List<int>> common = _measureCommonTails(beforeLines, afterLines);
  final List<CodeBlockLine> lines = <CodeBlockLine>[];
  int row = 0;
  int column = 0;

  while (row < beforeLines.length && column < afterLines.length) {
    if (beforeLines[row] == afterLines[column]) {
      lines.add(CodeBlockLine('$_unchangedMarker${beforeLines[row]}'));
      row += 1;
      column += 1;
    } else if (common[row + 1][column] >= common[row][column + 1]) {
      lines.add(CodeBlockLine.removed('$_removedMarker${beforeLines[row]}'));
      row += 1;
    } else {
      lines.add(CodeBlockLine.added('$_addedMarker${afterLines[column]}'));
      column += 1;
    }
  }
  while (row < beforeLines.length) {
    lines.add(CodeBlockLine.removed('$_removedMarker${beforeLines[row]}'));
    row += 1;
  }
  while (column < afterLines.length) {
    lines.add(CodeBlockLine.added('$_addedMarker${afterLines[column]}'));
    column += 1;
  }

  return lines;
}
