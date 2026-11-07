import 'dart:math';

import 'random_wire_values.dart';

const int endpointPublicKeyLength = 32;
const int _byteValueCount = 256;

int randomNegativeWholeNumber(Random random) {
  return -1 - randomWholeNumber(random);
}

int randomWholeNumberOutsideAByte(Random random) {
  if (random.nextBool()) {
    return randomNegativeWholeNumber(random);
  }
  return _byteValueCount + randomWholeNumber(random);
}

List<int> randomBytesOfLength(Random random, int length) {
  final List<int> bytes = <int>[];
  for (int i = 0; i < length; i += 1) {
    bytes.add(random.nextInt(_byteValueCount));
  }
  return bytes;
}

List<int> randomEndpointPublicKey(Random random) {
  return randomBytesOfLength(random, endpointPublicKeyLength);
}
