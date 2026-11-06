import 'dart:math';

const int _largestPieceCount = 12;
const int _deleteCodeUnit = 0x7f;
const int _firstPrintableCodeUnit = 0x20;
const List<String> _hostilePathPieces = <String>[
  'a',
  'Z',
  '7',
  ' ',
  '  ',
  '"',
  "'",
  '`',
  r'$',
  r'$(touch x)',
  r'${HOME}',
  r'\',
  r'\\',
  r'\s',
  r'\n',
  r'\"',
  r'\$',
  '%',
  '%f',
  '%U',
  '%%',
  '=',
  ';',
  '#',
  '[Desktop Entry]',
  'Exec=',
  '~',
  '*',
  '?',
  '&',
  '|',
  '<',
  '>',
  '(',
  ')',
  '!',
  'é',
  'e\u0301',
  '火',
  '😀',
  '\u202e',
  '\u200b',
  '\u2028',
  '\u00a0',
  '/',
  '//',
  '..',
  '.',
];
const List<String> _relativePrefixes = <String>[
  '',
  ' /',
  './',
  '../',
  '~/',
  'C:/',
  r'\',
  'relative/',
  'file:///',
  'a',
];

String _randomPieces(Random random) {
  final StringBuffer text = StringBuffer();
  final int pieceCount = random.nextInt(_largestPieceCount);
  for (int i = 0; i < pieceCount; i += 1) {
    text.write(_hostilePathPieces[random.nextInt(_hostilePathPieces.length)]);
  }
  return text.toString();
}

String randomHostileAbsolutePath(Random random) {
  return '/${_randomPieces(random)}';
}

String randomRelativePath(Random random) {
  final String prefix =
      _relativePrefixes[random.nextInt(_relativePrefixes.length)];
  final String relativePath = '$prefix${_randomPieces(random)}';
  if (relativePath.startsWith('/')) {
    return 'a$relativePath';
  }
  return relativePath;
}

List<int> controlCodeUnits() {
  final List<int> codeUnits = <int>[];
  for (int codeUnit = 0; codeUnit < _firstPrintableCodeUnit; codeUnit += 1) {
    codeUnits.add(codeUnit);
  }
  codeUnits.add(_deleteCodeUnit);
  return codeUnits;
}

String insertAtRandomPlace(Random random, String text, String insertion) {
  final int place = 1 + random.nextInt(text.length);
  return '${text.substring(0, place)}$insertion${text.substring(place)}';
}
