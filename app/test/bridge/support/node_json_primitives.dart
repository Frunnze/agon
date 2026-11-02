import 'dart:math';

import '../../support/random_inputs.dart';

typedef NodeJsonBuilder = Object? Function(Random random);

const List<int> _uuidGroupLengths = <int>[8, 4, 4, 4, 12];
const String _hexadecimalDigits = '0123456789abcdef';
const int _deviceIdLength = 32;
const int _byteValueCount = 256;
const int _largestByteCount = 33;
const int _largestListLength = 4;
const int _largestCount = 100000;
const int _microsecondsPerSecond = 1000000;
const int _canvasExtent = 2000;

String randomUuidText(Random random) {
  final List<String> groups = <String>[];
  for (final int groupLength in _uuidGroupLengths) {
    groups.add(_randomHexadecimal(random, groupLength));
  }
  return groups.join('-');
}

String randomDeviceIdText(Random random) {
  return _randomHexadecimal(random, _deviceIdLength);
}

String randomMomentText(Random random) {
  final Duration fraction = Duration(
    microseconds: random.nextInt(_microsecondsPerSecond),
  );
  return randomUtcMoment(random).add(fraction).toIso8601String();
}

List<int> randomBytes(Random random) {
  final int count = random.nextInt(_largestByteCount);
  final List<int> bytes = <int>[];
  for (int i = 0; i < count; i += 1) {
    bytes.add(random.nextInt(_byteValueCount));
  }
  return bytes;
}

List<Object?> randomListOf(Random random, NodeJsonBuilder buildElement) {
  final int count = random.nextInt(_largestListLength);
  final List<Object?> elements = <Object?>[];
  for (int i = 0; i < count; i += 1) {
    elements.add(buildElement(random));
  }
  return elements;
}

List<Object?> randomTexts(Random random) => randomListOf(random, randomText);

List<Object?> randomUuidTexts(Random random) {
  return randomListOf(random, randomUuidText);
}

Object? randomOptional(Random random, NodeJsonBuilder buildValue) {
  if (random.nextBool()) {
    return null;
  }
  return buildValue(random);
}

int randomCount(Random random) => random.nextInt(_largestCount);

double randomCanvasCoordinate(Random random) {
  return random.nextDouble() * _canvasExtent - _canvasExtent / 2;
}

String _randomHexadecimal(Random random, int length) {
  final StringBuffer digits = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    final int digitIndex = random.nextInt(_hexadecimalDigits.length);
    digits.write(_hexadecimalDigits[digitIndex]);
  }
  return digits.toString();
}
