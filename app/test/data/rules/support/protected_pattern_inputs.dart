import 'dart:math';

import '../../../support/random_inputs.dart';

const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-_*?[]é';
const List<String> _placePrefixes = <String>['', '~/', '/'];
const int _longestName = 8;
const int _mostSegments = 4;
const int _mostPatterns = 12;
const List<int> unicodeWhiteSpaceOtherThanSpace = <int>[
  0x09,
  0x0A,
  0x0B,
  0x0C,
  0x0D,
  0x85,
  0xA0,
  0x1680,
  0x2000,
  0x2001,
  0x2002,
  0x2003,
  0x2004,
  0x2005,
  0x2006,
  0x2007,
  0x2008,
  0x2009,
  0x200A,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
];
final RegExp _asciiLetter = RegExp('[a-zA-Z]');

String flipAsciiCase(String pattern) {
  return pattern.replaceAllMapped(_asciiLetter, (Match letter) {
    final String character = letter[0]!;
    final String lowercase = character.toLowerCase();
    if (character == lowercase) {
      return character.toUpperCase();
    }
    return lowercase;
  });
}

String randomPatternName(Random random) {
  final int length = 1 + random.nextInt(_longestName);
  final StringBuffer name = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    name.write(_nameCharacters[random.nextInt(_nameCharacters.length)]);
  }
  return name.toString();
}

String randomValidPattern(Random random) {
  final int segmentCount = 1 + random.nextInt(_mostSegments);
  final List<String> segments = <String>[
    for (int i = 0; i < segmentCount; i += 1) randomPatternName(random),
  ];
  return '${pickOne(random, _placePrefixes)}${segments.join('/')}';
}

List<String> randomDistinctPatterns(Random random) {
  final int count = 1 + random.nextInt(_mostPatterns);
  final Set<String> patterns = <String>{};
  while (patterns.length < count) {
    patterns.add(randomValidPattern(random));
  }
  return patterns.toList();
}

String quotePrintableText(String text) {
  final String backslashesEscaped = text.replaceAll(r'\', r'\\');
  final String quotesEscaped = backslashesEscaped.replaceAll('"', r'\"');
  return '"$quotesEscaped"';
}
