import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/markdown_view.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const List<String> _markdownPieces = <String>[
  '# Title\n',
  '## Part\n',
  '- item\n',
  '1. first\n',
  '```\ncode\n```\n',
  '`inline`',
  '*soft*',
  '**bold**',
  '[link](https://example.com)',
  '> quoted\n',
  '---\n',
  '| a | b |\n|---|---|\n| 1 | 2 |\n',
  '\n\n',
  '<b>html</b>',
];
const List<String> _fileNames = <String>[
  'redirect.ts',
  'README.md',
  'notes',
  'icon.png',
  'clip.mp4',
];

String _randomMarkdown(Random random) {
  final StringBuffer text = StringBuffer();
  for (int index = 0; index < random.nextInt(10); index += 1) {
    if (random.nextInt(4) == 0) {
      text.write(randomText(random));
    } else {
      text.write(pickOne(random, _markdownPieces));
    }
  }
  return text.toString();
}

FilePreview _randomPreview(Random random) {
  return switch (random.nextInt(3)) {
    0 => TextFilePreview(_randomMarkdown(random)),
    1 => ImageFilePreview(width: 64, height: 64, bytes: galleryIconBytes),
    _ => UnavailableFilePreview(
      pickOne(random, PreviewUnavailableReason.values),
    ),
  };
}

void main() {
  testWidgets('test_code_view_property_numbers_every_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int lineCount = 1 + random.nextInt(30);
      final String text = List<String>.generate(
        lineCount,
        (int index) => 'line$index ${randomText(random)}',
      ).join('\n');
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: CodeView(text: text, language: findSyntaxLanguage('ts')),
      );

      expect(find.text('$lineCount'), findsOneWidget);
      expect(find.text('${lineCount + 1}'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_markdown_view_property_fuzz_renders_any_text', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 9602,
      buildChild: (Random random) =>
          MarkdownView(text: _randomMarkdown(random)),
    );
  });

  testWidgets('test_file_content_view_property_renders_every_preview', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 9603,
      buildChild: (Random random) => FileContentView(
        file: RepositoryFile(
          path: 'folder/${pickOne(random, _fileNames)}',
          size: random.nextInt(1 << 30),
          preview: _randomPreview(random),
        ),
        repositoryPath: randomWordPhrase(random),
      ),
    );
  });

  testWidgets('test_file_tree_row_property_renders_any_name', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 9604,
      buildChild: (Random random) => FileTreeRow(
        name: randomText(random),
        size: random.nextBool() ? random.nextInt(1 << 30) : null,
        depth: random.nextInt(6),
        folderState: pickOne(random, FolderState.values),
        emphasis: pickOne(random, RowEmphasis.values),
        onTap: () {},
      ),
    );
  });
}
