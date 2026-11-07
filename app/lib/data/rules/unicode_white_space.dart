const String _whiteSpaceCharacter =
    r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A'
    r'\u2028\u2029\u202F\u205F\u3000]';
final RegExp _whiteSpaceRun = RegExp('$_whiteSpaceCharacter+');
final RegExp _edgeWhiteSpace = RegExp(
  '^$_whiteSpaceCharacter+|$_whiteSpaceCharacter+\$',
);

String trimUnicodeWhiteSpace(String text) {
  return text.replaceAll(_edgeWhiteSpace, '');
}

String collapseUnicodeWhiteSpace(String text) {
  final String trimmed = trimUnicodeWhiteSpace(text);
  return trimmed.replaceAll(_whiteSpaceRun, ' ');
}
