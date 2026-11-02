const String _lineBreak = '\n';
final RegExp _trailingCarriageReturns = RegExp('\r+\$');

List<String> splitTextLines(String text) {
  if (text.isEmpty) {
    return const <String>[];
  }

  final List<String> rawLines = text.split(_lineBreak);
  final bool endsWithLineBreak = rawLines.length > 1 && rawLines.last.isEmpty;
  final List<String> keptLines = endsWithLineBreak
      ? rawLines.sublist(0, rawLines.length - 1)
      : rawLines;
  final List<String> lines = <String>[];

  for (final String line in keptLines) {
    lines.add(line.replaceFirst(_trailingCarriageReturns, ''));
  }

  return List<String>.unmodifiable(lines);
}
