import 'dart:math';

const String gitSuffix = '.git';
const String _lowercaseLetters = 'abcdefghijklmnopqrstuvwxyz';
const String _uppercaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const String _digits = '0123456789';
const String _labelEdgeCharacters = '$_lowercaseLetters$_digits';
const String _labelInnerCharacters = '$_labelEdgeCharacters-';
const String _pathFirstCharacters =
    '$_lowercaseLetters$_uppercaseLetters${_digits}_';
const String _pathCharacters = '$_pathFirstCharacters.-';
const String _nameEnding = '_';
const int _largestLabelMiddleLength = 6;
const int _largestInnerLabelCount = 3;
const int _shortestTopLevelLength = 2;
const int _topLevelLengthSpan = 5;
const int _largestPathRestLength = 12;

String randomCharacters(Random random, String alphabet, int length) {
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < length; i += 1) {
    buffer.write(alphabet[random.nextInt(alphabet.length)]);
  }

  return buffer.toString();
}

String randomHostLabel(Random random) {
  final String first = randomCharacters(random, _labelEdgeCharacters, 1);
  if (random.nextBool()) {
    return first;
  }

  final int middleLength = random.nextInt(_largestLabelMiddleLength + 1);
  final String middle = randomCharacters(
    random,
    _labelInnerCharacters,
    middleLength,
  );
  final String last = randomCharacters(random, _labelEdgeCharacters, 1);
  return '$first$middle$last';
}

String randomRepositoryHost(Random random) {
  final int innerLabelCount = 1 + random.nextInt(_largestInnerLabelCount);
  final List<String> labels = <String>[];

  for (int i = 0; i < innerLabelCount; i += 1) {
    labels.add(randomHostLabel(random));
  }

  final int topLevelLength =
      _shortestTopLevelLength + random.nextInt(_topLevelLengthSpan);
  labels.add(randomCharacters(random, _lowercaseLetters, topLevelLength));
  return labels.join('.');
}

String randomRepositoryName(Random random) {
  final String first = randomCharacters(random, _pathFirstCharacters, 1);
  final int restLength = random.nextInt(_largestPathRestLength + 1);
  final String rest = randomCharacters(random, _pathCharacters, restLength);
  return '$first$rest';
}

String randomPathPartWithoutGitSuffix(Random random) {
  final String name = randomRepositoryName(random);
  if (name.endsWith(gitSuffix)) {
    return '$name$_nameEnding';
  }
  return name;
}

String scrambleLetterCase(Random random, String text) {
  final StringBuffer buffer = StringBuffer();

  for (final String character in text.split('')) {
    final bool isUppercase = random.nextBool();
    buffer.write(isUppercase ? character.toUpperCase() : character);
  }

  return buffer.toString();
}
