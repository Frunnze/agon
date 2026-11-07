import 'dart:math';

import '../../../support/random_inputs.dart';

const int _largestDistanceOutside = 1000;
const List<int> _extremeNumbers = <int>[
  -9007199254740991,
  9007199254740991,
  -4294967296,
  4294967295,
];

int randomNumberOutsideRange(
  Random random, {
  required int least,
  required int most,
}) {
  if (random.nextInt(4) == 0) {
    return pickOne(random, _extremeNumbers);
  }

  final int distance = 1 + random.nextInt(_largestDistanceOutside);
  if (random.nextBool()) {
    return least - distance;
  }
  return most + distance;
}
