import 'dart:math';

import '../../support/random_inputs.dart';

const List<String> _hostileTexts = <String>[
  '',
  ' ',
  '\t',
  '\n',
  ' padded ',
  'line\nbreak',
  'quote"inside',
  'back\\slash',
  '\u200b',
  '\u202eright to left',
  'e\u0301',
  '\u{1F600}',
  '\u{1F469}\u{200D}\u{1F4BB}',
  'null',
  'true',
  '0',
  '{}',
  '[]',
];

String randomHostileText(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _hostileTexts);
  }
  return randomText(random);
}

List<String> randomHostileTexts(Random random) {
  final int count = random.nextInt(_hostileTexts.length ~/ 3);
  final List<String> texts = <String>[];
  for (int i = 0; i < count; i += 1) {
    texts.add(randomHostileText(random));
  }
  return texts;
}
