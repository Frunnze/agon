import 'package:agent_orchestration/screens/files/syntax_languages.dart';

enum SyntaxKind { plain, keyword, string, function }

final class SyntaxToken {
  const SyntaxToken(this.text, this.kind);

  final String text;
  final SyntaxKind kind;
}

const String _escapeCharacter = r'\';
const String _callOpening = '(';
final RegExp _identifierStart = RegExp(r'[A-Za-z_$]');
final RegExp _identifierPart = RegExp(r'[A-Za-z0-9_$]');

List<SyntaxToken> highlightLine(String line, SyntaxLanguage language) {
  final List<SyntaxToken> tokens = <SyntaxToken>[];
  final StringBuffer plainText = StringBuffer();
  int index = 0;

  while (index < line.length) {
    final String character = line[index];

    if (language.stringDelimiters.contains(character)) {
      final int end = _findStringEnd(line, index);
      _addPlainText(plainText, tokens);
      tokens.add(SyntaxToken(line.substring(index, end), SyntaxKind.string));
      index = end;
    } else if (_identifierStart.hasMatch(character)) {
      final int end = _findIdentifierEnd(line, index);
      final String word = line.substring(index, end);
      final SyntaxKind kind = _classifyWord(word, line, end, language);
      if (kind == SyntaxKind.plain) {
        plainText.write(word);
      } else {
        _addPlainText(plainText, tokens);
        tokens.add(SyntaxToken(word, kind));
      }
      index = end;
    } else {
      plainText.write(character);
      index += 1;
    }
  }

  _addPlainText(plainText, tokens);
  return List<SyntaxToken>.unmodifiable(tokens);
}

int _findStringEnd(String line, int start) {
  final String delimiter = line[start];
  int index = start + 1;

  while (index < line.length) {
    final String character = line[index];
    if (character == _escapeCharacter) {
      index += 2;
    } else if (character == delimiter) {
      return index + 1;
    } else {
      index += 1;
    }
  }

  return line.length;
}

int _findIdentifierEnd(String line, int start) {
  int index = start + 1;

  while (index < line.length && _identifierPart.hasMatch(line[index])) {
    index += 1;
  }

  return index;
}

SyntaxKind _classifyWord(
  String word,
  String line,
  int end,
  SyntaxLanguage language,
) {
  if (language.keywords.contains(word)) {
    return SyntaxKind.keyword;
  }
  final bool isCalled = end < line.length && line[end] == _callOpening;
  if (isCalled) {
    return SyntaxKind.function;
  }
  return SyntaxKind.plain;
}

void _addPlainText(StringBuffer plainText, List<SyntaxToken> tokens) {
  if (plainText.isEmpty) {
    return;
  }
  tokens.add(SyntaxToken(plainText.toString(), SyntaxKind.plain));
  plainText.clear();
}
