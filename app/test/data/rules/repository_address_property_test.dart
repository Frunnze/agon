import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/repository_address.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';

const String _supportedScheme = 'https';
const String _hyphen = '-';
const String _anyLabelCharacters =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-';
const String _otherSchemeCharacters = 'abcdefghijklmnopqrstuvwxyzHTPS+.-';
const int _largestEdgeHyphenCount = 3;
const int _largestAnyLabelLength = 8;
const int _largestOtherSchemeLength = 8;
final RegExp _alphanumericPattern = RegExp(r'^[A-Za-z0-9]$');

bool _isAlphanumeric(String character) {
  return _alphanumericPattern.hasMatch(character);
}

bool _isLabelCharacter(String character) {
  return _isAlphanumeric(character) || character == _hyphen;
}

bool _followsDnsLabelRule(String label) {
  if (label.isEmpty) {
    return false;
  }
  final bool hasAlphanumericEdges =
      _isAlphanumeric(label[0]) && _isAlphanumeric(label[label.length - 1]);
  final bool hasOnlyLabelCharacters = label.split('').every(_isLabelCharacter);
  return hasAlphanumericEdges && hasOnlyLabelCharacters;
}

String _randomCanonicalAddress(Random random) {
  final String host = randomRepositoryHost(random);
  final String owner = randomPathPartWithoutGitSuffix(random);
  final String repository = randomPathPartWithoutGitSuffix(random);
  return '$host/$owner/$repository';
}

String _randomEdgeHyphens(Random random) {
  return _hyphen * (1 + random.nextInt(_largestEdgeHyphenCount));
}

String _randomScheme(Random random) {
  if (random.nextBool()) {
    return scrambleLetterCase(random, _supportedScheme);
  }
  final int length = 1 + random.nextInt(_largestOtherSchemeLength);
  return randomCharacters(random, _otherSchemeCharacters, length);
}

String _taintOneHostLabel(
  Random random,
  String host,
  String Function(String) taint,
) {
  final List<String> labels = host.split('.');
  final int position = random.nextInt(labels.length);
  final List<String> taintedLabels = List<String>.of(labels);
  taintedLabels[position] = taint(labels[position]);
  return taintedLabels.join('.');
}

void main() {
  test('test_is_host_property_refuses_a_leading_hyphen', () {
    final Random random = seededRandom(47301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hyphens = _randomEdgeHyphens(random);
      final String taintedHost = _taintOneHostLabel(
        random,
        randomRepositoryHost(random),
        (String label) => '$hyphens$label',
      );
      final String address = '$taintedHost/acme/app';

      expect(parseRepositoryAddress(address), isNull, reason: address);
    }
  });

  test('test_is_host_property_refuses_a_trailing_hyphen', () {
    final Random random = seededRandom(47302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hyphens = _randomEdgeHyphens(random);
      final String taintedHost = _taintOneHostLabel(
        random,
        randomRepositoryHost(random),
        (String label) => '$label$hyphens',
      );
      final String address = 'https://$taintedHost/acme/app.git';

      expect(parseRepositoryAddress(address), isNull, reason: address);
    }
  });

  test('test_is_host_property_refuses_edge_hyphens_in_every_form', () {
    final Random random = seededRandom(47303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = randomHostLabel(random);
      final String taintedLabel = random.nextBool()
          ? '$_hyphen$label'
          : '$label$_hyphen';
      final String host = '$taintedLabel.example';
      final List<String> forms = <String>[
        '$host/acme/app',
        'https://$host/acme/app.git',
        'HTTPS://$host/acme/app/',
        'git@$host:acme/app.git',
      ];

      for (final String form in forms) {
        expect(parseRepositoryAddress(form), isNull, reason: form);
      }
    }
  });

  test('test_is_host_property_matches_the_dns_label_rule', () {
    final Random random = seededRandom(47304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = 1 + random.nextInt(_largestAnyLabelLength);
      final String label = randomCharacters(
        random,
        _anyLabelCharacters,
        length,
      );
      final String host = random.nextBool()
          ? 'example.$label'
          : '$label.example';
      final String address = '$host/owner/app';

      final bool isAccepted = parseRepositoryAddress(address) != null;

      expect(isAccepted, _followsDnsLabelRule(label), reason: address);
    }
  });

  test('test_remove_address_prefix_property_https_is_read_in_any_case', () {
    final Random random = seededRandom(47305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _randomCanonicalAddress(random);
      final String scheme = scrambleLetterCase(random, _supportedScheme);
      final String withScheme = '$scheme://$address';

      expect(parseRepositoryAddress(withScheme), address, reason: withScheme);
    }
  });

  test('test_remove_address_prefix_property_refuses_only_non_https', () {
    final Random random = seededRandom(47306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _randomCanonicalAddress(random);
      final String scheme = _randomScheme(random);
      final String withScheme = '$scheme://$address';
      final bool isHttps = scheme.toLowerCase() == _supportedScheme;

      final String? parsed = parseRepositoryAddress(withScheme);

      expect(parsed, isHttps ? address : isNull, reason: withScheme);
    }
  });

  test('test_remove_address_prefix_property_scheme_case_never_matters', () {
    final Random random = seededRandom(47307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _randomCanonicalAddress(random);
      final String scheme = _randomScheme(random);
      final String lowerScheme = scheme.toLowerCase();
      final String mixedScheme = scrambleLetterCase(random, scheme);

      final String? lowerParsed = parseRepositoryAddress(
        '$lowerScheme://$address',
      );
      final String? mixedParsed = parseRepositoryAddress(
        '$mixedScheme://$address',
      );

      expect(mixedParsed, lowerParsed, reason: mixedScheme);
    }
  });

  test('test_parse_repository_address_property_lowercases_the_host', () {
    final Random random = seededRandom(47308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = randomPathPartWithoutGitSuffix(random);
      final String repository = randomPathPartWithoutGitSuffix(random);
      final String mixedHost = scrambleLetterCase(random, host);
      final String address = '$mixedHost/$owner/$repository';

      final String? parsed = parseRepositoryAddress(address);

      expect(parsed, '$host/$owner/$repository', reason: address);
    }
  });

  test('test_parse_repository_address_property_host_case_is_one_repo', () {
    final Random random = seededRandom(47309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = randomPathPartWithoutGitSuffix(random);
      final String repository = randomPathPartWithoutGitSuffix(random);
      final String firstHost = scrambleLetterCase(random, host);
      final String secondHost = scrambleLetterCase(random, host);

      final String? httpsParsed = parseRepositoryAddress(
        'https://$firstHost/$owner/$repository',
      );
      final String? gitAtParsed = parseRepositoryAddress(
        'git@$secondHost:$owner/$repository',
      );

      expect(httpsParsed, isNotNull);
      expect(gitAtParsed, httpsParsed);
    }
  });

  test('test_parse_repository_address_property_path_keeps_its_case', () {
    final Random random = seededRandom(47310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = scrambleLetterCase(
        random,
        randomPathPartWithoutGitSuffix(random),
      );
      final String repository = scrambleLetterCase(
        random,
        randomPathPartWithoutGitSuffix(random),
      );
      final String address = '$host/$owner/$repository';

      expect(parseRepositoryAddress(address), address);
    }
  });
}
