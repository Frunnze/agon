import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../support/random_inputs.dart';

const List<String> _extensions = <String>['ts', 'dart', 'rs', 'py', 'json'];
const List<String> _codePieces = <String>[
  'const',
  ' ',
  'return',
  'readSession',
  '(',
  ')',
  '"/login"',
  "'it'",
  '`x`',
  r'"a\"b"',
  '"',
  "'",
  '{',
  '}',
  ';',
  '_value',
  r'$scope',
  '42',
  'null',
  'é',
  '\t',
];

final RegExp _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

String _randomCodeLine(Random random) {
  final StringBuffer line = StringBuffer();
  for (int index = 0; index < random.nextInt(12); index += 1) {
    if (random.nextInt(5) == 0) {
      line.write(randomText(random).replaceAll('\n', ''));
    } else {
      line.write(pickOne(random, _codePieces));
    }
  }
  return line.toString();
}

List<(String, SyntaxKind)> _describe(List<SyntaxToken> tokens) {
  return <(String, SyntaxKind)>[
    for (final SyntaxToken token in tokens) (token.text, token.kind),
  ];
}

void main() {
  final SyntaxLanguage script = findSyntaxLanguage('ts')!;

  test('test_highlight_line_property_marks_the_design_sample', () {
    expect(
      _describe(highlightLine('const LOGIN_PATH = "/login";', script)),
      <(String, SyntaxKind)>[
        ('const', SyntaxKind.keyword),
        (' LOGIN_PATH = ', SyntaxKind.plain),
        ('"/login"', SyntaxKind.string),
        (';', SyntaxKind.plain),
      ],
    );
    expect(
      _describe(highlightLine('  router.replace(LOGIN_PATH);', script)),
      <(String, SyntaxKind)>[
        ('  router.', SyntaxKind.plain),
        ('replace', SyntaxKind.function),
        ('(LOGIN_PATH);', SyntaxKind.plain),
      ],
    );
  });

  test('test_highlight_line_property_round_trips_the_line', () {
    final Random random = seededRandom(9201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = _randomCodeLine(random);
      final SyntaxLanguage language = findSyntaxLanguage(
        pickOne(random, _extensions),
      )!;
      final List<SyntaxToken> tokens = highlightLine(line, language);

      expect(tokens.map((SyntaxToken token) => token.text).join(), line);
      for (final SyntaxToken token in tokens) {
        expect(token.text, isNotEmpty);
      }
    }
  });

  test('test_highlight_line_property_kinds_follow_the_language', () {
    final Random random = seededRandom(9202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = _randomCodeLine(random);
      final SyntaxLanguage language = findSyntaxLanguage(
        pickOne(random, _extensions),
      )!;
      int offset = 0;

      for (final SyntaxToken token in highlightLine(line, language)) {
        final int end = offset + token.text.length;
        switch (token.kind) {
          case SyntaxKind.keyword:
            expect(language.keywords, contains(token.text));
          case SyntaxKind.string:
            expect(language.stringDelimiters, contains(token.text[0]));
          case SyntaxKind.function:
            expect(_identifier.hasMatch(token.text), isTrue);
            expect(line.substring(end, end + 1), '(');
          case SyntaxKind.plain:
            break;
        }
        offset = end;
      }
    }
  });
}
