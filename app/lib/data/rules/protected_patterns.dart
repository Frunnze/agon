import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const int maximumProtectedPatternLength = 200;
const int maximumProtectedPatternCount = 200;
const String _pathSeparator = '/';
const String _homeMarker = '~';
const String _homePrefix = '$_homeMarker$_pathSeparator';
const String _parentFolderSegment = '..';
const String _currentFolderSegment = '.';
const String _plainSpace = ' ';
const String _emptyPatternProblem = 'a pattern cannot be empty';
const String _forbiddenCharacterRule =
    'quotes, backslashes and brackets are not allowed';
const Map<String, String> _quotedForbiddenCharacters = <String, String>{
  '"': "'\"'",
  "'": r"'\''",
  r'\': r"'\\'",
  '(': "'('",
  ')': "')'",
};
const Map<int, String> _namedEscapes = <int, String>{
  0x00: r'\0',
  0x09: r'\t',
  0x0A: r'\n',
  0x0D: r'\r',
  0x22: r'\"',
  0x5C: r'\\',
};
const int _lastLowControlCharacter = 0x1F;
const int _firstHighControlCharacter = 0x7F;
const int _lastHighControlCharacter = 0x9F;
const int _hexadecimalRadix = 16;
final RegExp _asciiUppercaseLetters = RegExp('[A-Z]+');

enum _PatternPlace { underHome, fromRoot, atAnyDepth }

typedef _ReadPattern = ({_PatternPlace place, List<String> segments});

bool _isControlCharacter(int rune) {
  final bool isLowControl = rune <= _lastLowControlCharacter;
  final bool isHighControl =
      rune >= _firstHighControlCharacter && rune <= _lastHighControlCharacter;
  return isLowControl || isHighControl;
}

String _escapeCharacter(int rune) {
  final String? namedEscape = _namedEscapes[rune];
  if (namedEscape != null) {
    return namedEscape;
  }

  final String character = String.fromCharCode(rune);
  final bool isWhiteSpace = trimUnicodeWhiteSpace(character).isEmpty;
  final bool isHiddenSpace = isWhiteSpace && character != _plainSpace;
  if (_isControlCharacter(rune) || isHiddenSpace) {
    return '\\u{${rune.toRadixString(_hexadecimalRadix)}}';
  }
  return character;
}

String _quoteText(String text) {
  final StringBuffer quoted = StringBuffer('"');
  for (final int rune in text.runes) {
    quoted.write(_escapeCharacter(rune));
  }
  quoted.write('"');
  return quoted.toString();
}

String? _findQuotedForbiddenCharacter(String pattern) {
  for (final int rune in pattern.runes) {
    final String? quoted =
        _quotedForbiddenCharacters[String.fromCharCode(rune)];
    if (quoted != null) {
      return quoted;
    }
  }
  return null;
}

List<String> _splitPathSegments(String path) {
  return <String>[
    for (final String segment in path.split(_pathSeparator))
      if (segment.isNotEmpty && segment != _currentFolderSegment) segment,
  ];
}

_ReadPattern _readPattern(String pattern) {
  if (pattern == _homeMarker) {
    return (place: _PatternPlace.underHome, segments: const <String>[]);
  }
  if (pattern.startsWith(_homePrefix)) {
    final String path = pattern.substring(_homePrefix.length);
    return (
      place: _PatternPlace.underHome,
      segments: _splitPathSegments(path),
    );
  }
  if (pattern.startsWith(_pathSeparator)) {
    final String path = pattern.substring(_pathSeparator.length);
    return (place: _PatternPlace.fromRoot, segments: _splitPathSegments(path));
  }
  return (
    place: _PatternPlace.atAnyDepth,
    segments: _splitPathSegments(pattern),
  );
}

String _normalisePattern(String pattern) {
  final _ReadPattern read = _readPattern(pattern);
  final String path = read.segments.join(_pathSeparator);
  final String lowercasePath = path.replaceAllMapped(
    _asciiUppercaseLetters,
    (Match letters) => letters[0]!.toLowerCase(),
  );
  return '${read.place.name}$_pathSeparator$lowercasePath';
}

String? _describePatternProblem(String pattern) {
  if (pattern.isEmpty) {
    return _emptyPatternProblem;
  }

  final String quoted = _quoteText(pattern);
  if (trimUnicodeWhiteSpace(pattern) != pattern) {
    return 'the pattern $quoted starts or ends with a space';
  }

  final int length = pattern.runes.length;
  if (length > maximumProtectedPatternLength) {
    return 'a pattern can have at most $maximumProtectedPatternLength '
        'characters, this one has $length';
  }

  final String? forbidden = _findQuotedForbiddenCharacter(pattern);
  if (forbidden != null) {
    return 'the pattern $quoted cannot contain $forbidden: '
        '$_forbiddenCharacterRule';
  }
  if (pattern.runes.any(_isControlCharacter)) {
    return 'the pattern $quoted cannot contain control characters';
  }
  if (pattern.split(_pathSeparator).contains(_parentFolderSegment)) {
    return 'the pattern $quoted cannot use .. to leave a folder';
  }
  if (_readPattern(pattern).segments.isEmpty) {
    return 'the pattern $quoted names no file or folder';
  }
  return null;
}

String? _describeRepeatedPatternProblem(
  List<String> earlierPatterns,
  String pattern,
) {
  final String normalised = _normalisePattern(pattern);
  for (final String earlierPattern in earlierPatterns) {
    if (_normalisePattern(earlierPattern) == normalised) {
      return 'the pattern ${_quoteText(pattern)} is listed twice: it '
          'protects the same files as ${_quoteText(earlierPattern)}';
    }
  }
  return null;
}

String? describeProtectedFilesProblem(List<String> patterns) {
  final int count = patterns.length;
  if (count > maximumProtectedPatternCount) {
    return 'the list can have at most $maximumProtectedPatternCount '
        'patterns, this one has $count';
  }

  for (int position = 0; position < count; position += 1) {
    final String pattern = patterns[position];
    final List<String> earlierPatterns = patterns.sublist(0, position);
    final String? problem =
        _describePatternProblem(pattern) ??
        _describeRepeatedPatternProblem(earlierPatterns, pattern);
    if (problem != null) {
      return problem;
    }
  }
  return null;
}
