import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/repository_address.dart';

import '../../support/random_inputs.dart';

const String _sharedCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'repository_address_cases.json';
const List<String> _surroundingWhitespace = <String>[
  '',
  ' ',
  '\t',
  '\n',
  ' \r\n',
];

class _SharedAddressCase {
  const _SharedAddressCase({required this.address, required this.canonical});

  final String address;
  final String? canonical;
}

_SharedAddressCase _readSharedCase(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw FormatException('a shared address case is not an object: $entry');
  }
  final Object? address = entry['address'];
  final Object? canonical = entry['canonical'];
  if (address is! String || canonical is! String?) {
    throw FormatException('a shared address case is malformed: $entry');
  }
  return _SharedAddressCase(address: address, canonical: canonical);
}

List<_SharedAddressCase> _readSharedCases() {
  final String sharedCasesText = File(_sharedCasesPath).readAsStringSync();
  final Object? entries = jsonDecode(sharedCasesText);
  if (entries is! List<Object?>) {
    throw const FormatException('the shared address cases are not a list');
  }
  return <_SharedAddressCase>[
    for (final Object? entry in entries) _readSharedCase(entry),
  ];
}

void main() {
  final List<_SharedAddressCase> sharedCases = _readSharedCases();

  test('test_parse_repository_address_property_agrees_with_shared_table', () {
    for (final _SharedAddressCase sharedCase in sharedCases) {
      final String? parsed = parseRepositoryAddress(sharedCase.address);

      expect(parsed, sharedCase.canonical, reason: sharedCase.address);
    }
  });

  test('test_parse_repository_address_property_shared_answers_are_fixed', () {
    for (final _SharedAddressCase sharedCase in sharedCases) {
      final String? canonical = sharedCase.canonical;
      if (canonical == null) {
        continue;
      }

      final String? reparsed = parseRepositoryAddress(canonical);
      final String? readBack = parseRepositoryAddress(
        'https://$canonical.git',
      );

      expect(reparsed, canonical);
      expect(readBack, canonical);
    }
  });

  test('test_parse_repository_address_property_shared_table_padding', () {
    final Random random = seededRandom(47316);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SharedAddressCase sharedCase = pickOne(random, sharedCases);
      final String leading = pickOne(random, _surroundingWhitespace);
      final String trailing = pickOne(random, _surroundingWhitespace);
      final String padded = '$leading${sharedCase.address}$trailing';

      final String? parsed = parseRepositoryAddress(padded);

      expect(parsed, sharedCase.canonical, reason: padded);
    }
  });
}
