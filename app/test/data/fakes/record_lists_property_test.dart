import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';

import '../../support/random_inputs.dart';
import 'support/refusals.dart';

const String _recordKind = 'record';
const int _largestRecordCount = 8;
const int _identifierSpan = 6;

List<String> _randomIdentifiers(Random random) {
  final List<String> identifiers = <String>[];
  final int count = random.nextInt(_largestRecordCount);
  for (int i = 0; i < count; i += 1) {
    identifiers.add('id-${random.nextInt(_identifierSpan)}');
  }
  return identifiers;
}

String _identifyText(String identifier) => identifier;

String? _findFirstRepeatedIdentifier(List<String> identifiers) {
  final Set<String> seen = <String>{};
  for (final String identifier in identifiers) {
    if (seen.contains(identifier)) {
      return identifier;
    }
    seen.add(identifier);
  }
  return null;
}

bool _isDuplicateRefusal(Object error) => error is ArgumentError;

Future<bool> _isRefused(List<String> identifiers) {
  return isRefused(
    () async => refuseDuplicateIdentifiers(
      identifiers,
      identify: _identifyText,
      kind: _recordKind,
    ),
    isRefusal: _isDuplicateRefusal,
  );
}

void main() {
  test('test_refuse_duplicate_identifiers_property_refuses_exactly_'
      'repeated_identifiers', () async {
    final Random random = seededRandom(66401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> identifiers = _randomIdentifiers(random);
      final bool hasRepeat = identifiers.toSet().length < identifiers.length;

      expect(await _isRefused(identifiers), hasRepeat, reason: '$identifiers');
    }
  });

  test('test_refuse_duplicate_identifiers_property_names_the_first_'
      'repeated_identifier', () {
    final Random random = seededRandom(66402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> identifiers = _randomIdentifiers(random);
      final String? repeated = _findFirstRepeatedIdentifier(identifiers);
      if (repeated == null) {
        continue;
      }

      expect(
        () => refuseDuplicateIdentifiers(
          identifiers,
          identify: _identifyText,
          kind: _recordKind,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((ArgumentError e) => e.invalidValue, 'value', repeated)
              .having(
                (ArgumentError e) => e.message,
                'message',
                contains(_recordKind),
              ),
        ),
      );
    }
  });

  test('test_refuse_duplicate_identifiers_property_order_does_not_change_'
      'the_verdict', () async {
    final Random random = seededRandom(66403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> identifiers = _randomIdentifiers(random);
      final List<String> shuffled = List<String>.of(identifiers);
      shuffled.shuffle(random);

      expect(await _isRefused(shuffled), await _isRefused(identifiers));
    }
  });
}
