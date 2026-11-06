import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';

const List<int> _boundaryWholeNumbers = <int>[
  0,
  1,
  -1,
  255,
  256,
  (1 << 31) - 1,
  1 << 31,
  1 << 32,
  (1 << 53) + 1,
  (1 << 62) + 7,
];

List<String> randomTextList(Random random) {
  final List<String> texts = <String>[];
  for (final Object? text in randomTexts(random)) {
    texts.add(text.toString());
  }
  return texts;
}

int randomWholeNumber(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _boundaryWholeNumbers);
  }
  return randomCount(random);
}

DateTime? randomOptionalLocalMoment(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomLocalMoment(random);
}

String? randomOptionalText(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomText(random);
}
