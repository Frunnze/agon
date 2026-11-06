import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';

const int _largestElementCount = 6;

final class ListCopy<Value, Element> {
  const ListCopy({
    required this.testNamePrefix,
    required this.seed,
    required this.buildElement,
    required this.construct,
    required this.readList,
  });

  final String testNamePrefix;
  final int seed;
  final Element Function(Random random) buildElement;
  final Value Function(Random random, List<Element> elements) construct;
  final List<Element> Function(Value value) readList;
}

void testListCopyProperties<Value, Element>(ListCopy<Value, Element> copy) {
  test('${copy.testNamePrefix}_keeps_every_element_in_order', () {
    final Random random = seededRandom(copy.seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Element> givenElements = _buildElements(random, copy);

      final Value value = copy.construct(random, givenElements);

      expect(copy.readList(value), orderedEquals(givenElements));
    }
  });

  test('${copy.testNamePrefix}_ignores_later_caller_changes', () {
    final Random random = seededRandom(copy.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Element> givenElements = _buildElements(random, copy);
      final List<Element> elementsAtConstruction = List<Element>.of(
        givenElements,
      );
      final Value value = copy.construct(random, givenElements);

      givenElements.insert(0, copy.buildElement(random));
      givenElements.add(copy.buildElement(random));
      if (random.nextBool()) {
        givenElements.clear();
      }

      expect(copy.readList(value), orderedEquals(elementsAtConstruction));
    }
  });

  test('${copy.testNamePrefix}_cannot_be_changed', () {
    final Random random = seededRandom(copy.seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Element> givenElements = _buildElements(random, copy);
      final Value value = copy.construct(random, givenElements);
      final List<Element> storedElements = copy.readList(value);
      final Element extraElement = copy.buildElement(random);

      expect(() => storedElements.add(extraElement), throwsUnsupportedError);
      expect(
        () => storedElements.insert(0, extraElement),
        throwsUnsupportedError,
      );
      expect(storedElements.clear, throwsUnsupportedError);
      if (storedElements.isNotEmpty) {
        expect(
          () => storedElements[0] = extraElement,
          throwsUnsupportedError,
        );
      }
      expect(storedElements, orderedEquals(givenElements));
    }
  });
}

List<Element> _buildElements<Value, Element>(
  Random random,
  ListCopy<Value, Element> copy,
) {
  final int count = random.nextInt(_largestElementCount);
  final List<Element> elements = <Element>[];

  for (int i = 0; i < count; i += 1) {
    elements.add(copy.buildElement(random));
  }

  return elements;
}
