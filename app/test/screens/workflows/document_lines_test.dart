import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../support/random_inputs.dart';

const List<String> _sampleLines = <String>[
  'name: release',
  'steps:',
  '  - name: plan',
  '    runs_on: office-server',
  '    timeout: 2h',
  '    timeout: 6h',
];

String _randomDocument(Random random) {
  final int count = random.nextInt(8);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i += 1) {
    buffer.writeln(pickOne(random, _sampleLines));
  }
  return buffer.toString();
}

String _rebuild(List<CodeBlockLine> lines, LineChange skipped) {
  final StringBuffer buffer = StringBuffer();
  for (final CodeBlockLine line in lines) {
    if (line.change != skipped) {
      buffer.writeln(line.text.substring(diffMarkerWidth));
    }
  }
  return buffer.toString();
}

void main() {
  test('test_diff_document_lines_property_both_sides_rebuild', () {
    final Random random = seededRandom(8701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String before = _randomDocument(random);
      final String after = _randomDocument(random);
      final List<CodeBlockLine> lines = diffDocumentLines(before, after);

      expect(_rebuild(lines, LineChange.added), before);
      expect(_rebuild(lines, LineChange.removed), after);
    }
  });

  test('test_diff_document_lines_property_same_text_has_no_changes', () {
    final Random random = seededRandom(8702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String document = _randomDocument(random);
      final List<CodeBlockLine> lines = diffDocumentLines(document, document);

      for (final CodeBlockLine line in lines) {
        expect(line.change, LineChange.unchanged);
      }
    }
  });

  test('test_diff_document_lines_fuzz_property_never_throws', () {
    final Random random = seededRandom(8703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String before = randomText(random);
      final String after = randomText(random);

      expect(diffDocumentLines(before, after), isA<List<CodeBlockLine>>());
    }
  });

  test('diff document lines pins the gallery train-ranker change', () {
    final List<CodeBlockLine> lines = diffDocumentLines(
      trainRankerSignedDocument,
      trainRankerChangedDocument,
    );

    expect(
      <String>[for (final CodeBlockLine line in lines) line.text],
      <String>[
        '  name: train-ranker',
        '  steps:',
        '    - name: prepare',
        '      runs_on: office-server',
        '    - name: train',
        '      requires: [gpu]',
        '-     timeout: 2h',
        '+     timeout: 6h',
        '+     egress: [huggingface.co]',
      ],
    );
  });

  test('test_split_document_lines_property_one_line_per_text_line', () {
    final Random random = seededRandom(8704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String document = _randomDocument(random);
      final List<CodeBlockLine> lines = splitDocumentLines(document);
      final String rebuilt = lines
          .map((CodeBlockLine line) => '${line.text}\n')
          .join();

      expect(rebuilt, document);
    }
    expect(splitDocumentLines(releaseDocument).length, 8);
  });
}
