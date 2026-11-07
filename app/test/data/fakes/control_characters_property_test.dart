import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/control_characters.dart';

import '../../support/random_inputs.dart';

const int _firstPrintable = 0x20;
const int _deleteCharacter = 0x7f;
const int _lastSecondControl = 0x9f;
const int _checkedCodePointCount = 0x300;
const int _largestTextLength = 12;
const List<int> _printableStarts = <int>[0x20, 0xa0, 0x3000, 0x1f600];
const int _printableSpan = 0x5e;

bool _isRustControl(int codePoint) {
  final bool isFirstBlock = codePoint < _firstPrintable;
  final bool isSecondBlock =
      codePoint >= _deleteCharacter && codePoint <= _lastSecondControl;
  return isFirstBlock || isSecondBlock;
}

String _randomPrintableText(Random random) {
  final StringBuffer text = StringBuffer();
  final int length = random.nextInt(_largestTextLength);
  for (int i = 0; i < length; i += 1) {
    final int start = pickOne(random, _printableStarts);
    text.writeCharCode(start + random.nextInt(_printableSpan));
  }
  return text.toString();
}

int _randomControl(Random random) {
  if (random.nextBool()) {
    return random.nextInt(_firstPrintable);
  }
  const int secondBlockSize = _lastSecondControl - _deleteCharacter + 1;
  return _deleteCharacter + random.nextInt(secondBlockSize);
}

void main() {
  test('test_has_control_character_property_matches_the_rust_control_'
      'range', () {
    final Random random = seededRandom(65201);

    for (
      int codePoint = 0;
      codePoint < _checkedCodePointCount;
      codePoint += 1
    ) {
      final String text =
          '${_randomPrintableText(random)}'
          '${String.fromCharCode(codePoint)}'
          '${_randomPrintableText(random)}';

      expect(
        hasControlCharacter(text),
        _isRustControl(codePoint),
        reason: codePoint.toRadixString(16),
      );
    }
  });

  test('test_has_control_character_property_printable_text_has_none', () {
    final Random random = seededRandom(65202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _randomPrintableText(random);

      expect(hasControlCharacter(text), isFalse, reason: text);
    }
  });

  test('test_has_control_character_property_one_control_anywhere_is_'
      'found', () {
    final Random random = seededRandom(65203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> codePoints = _randomPrintableText(random).runes.toList();
      codePoints.insert(
        random.nextInt(codePoints.length + 1),
        _randomControl(random),
      );

      expect(hasControlCharacter(String.fromCharCodes(codePoints)), isTrue);
    }
  });
}
