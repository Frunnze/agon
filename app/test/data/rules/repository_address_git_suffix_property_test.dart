import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/repository_address.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';

const int _largestGitSuffixCount = 5;
const int _largestTrailingSlashCount = 3;
const String _pathSeparator = '/';

String _randomCanonicalAddress(Random random) {
  final String host = randomRepositoryHost(random);
  final String owner = randomPathPartWithoutGitSuffix(random);
  final String repository = randomPathPartWithoutGitSuffix(random);
  return '$host/$owner/$repository';
}

String _randomGitSuffixes(Random random) {
  return gitSuffix * random.nextInt(_largestGitSuffixCount + 1);
}

void main() {
  test('test_remove_trailing_property_drops_every_git_suffix', () {
    final Random random = seededRandom(47311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _randomCanonicalAddress(random);
      final String suffixes = _randomGitSuffixes(random);
      final String slashes =
          _pathSeparator * random.nextInt(_largestTrailingSlashCount);
      final List<String> forms = <String>[
        '$address$suffixes$slashes',
        'https://$address$suffixes$slashes',
      ];

      for (final String form in forms) {
        expect(parseRepositoryAddress(form), address, reason: form);
      }
    }
  });

  test('test_remove_trailing_property_reparsing_changes_nothing', () {
    final Random random = seededRandom(47312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = randomPathPartWithoutGitSuffix(random);
      final String repository = randomRepositoryName(random);
      final String suffixes = _randomGitSuffixes(random);
      final String address = 'git@$host:$owner/$repository$suffixes';

      final String? parsedOnce = parseRepositoryAddress(address);

      expect(parsedOnce, isNotNull, reason: address);
      expect(parseRepositoryAddress(parsedOnce!), parsedOnce, reason: address);
    }
  });

  test('test_remove_trailing_property_clone_url_reads_back', () {
    final Random random = seededRandom(47313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = randomPathPartWithoutGitSuffix(random);
      final String repository = randomRepositoryName(random);
      final String? canonical = parseRepositoryAddress(
        '$host/$owner/$repository',
      );

      final String? readBack = parseRepositoryAddress(
        'https://$canonical$gitSuffix',
      );

      expect(canonical, isNotNull);
      expect(readBack, canonical);
    }
  });

  test('test_remove_trailing_property_only_suffixes_is_no_name', () {
    final Random random = seededRandom(47314);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = randomPathPartWithoutGitSuffix(random);
      final int suffixCount = 1 + random.nextInt(_largestGitSuffixCount);
      final String address = '$host/$owner/${gitSuffix * suffixCount}';

      expect(parseRepositoryAddress(address), isNull, reason: address);
    }
  });

  test('test_parse_repository_address_property_name_never_ends_in_git', () {
    final Random random = seededRandom(47315);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = random.nextBool()
          ? randomText(random)
          : '${_randomCanonicalAddress(random)}${_randomGitSuffixes(random)}';

      final String? parsed = parseRepositoryAddress(text);

      if (parsed != null) {
        expect(parsed.endsWith(gitSuffix), isFalse, reason: text);
        expect(parseRepositoryAddress(parsed), parsed, reason: text);
      }
    }
  });
}
