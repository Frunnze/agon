import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/random_inputs.dart';

const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789';
const Map<String, String> _nameExamples = <String, String>{
  'Billing UI': 'billing-ui',
  'site_2': 'site-2',
  '.dotfiles': 'dotfiles',
  'My  App (old)': 'my-app-old',
  '___': fallbackProjectName,
};

String _randomLettersAndDigits(Random random) {
  final int length = 1 + random.nextInt(nameMaximumLength);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    final int index = random.nextInt(_nameCharacters.length);
    buffer.write(_nameCharacters[index]);
  }
  return buffer.toString();
}

void main() {
  test('test_convert_to_project_name_property_always_gives_a_valid_name', () {
    final Random random = seededRandom(9601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folderOrRepositoryName = randomText(random);

      final String projectName = convertToProjectName(folderOrRepositoryName);

      expect(describeNameProblem(projectName), isNull, reason: projectName);
    }
  });

  test('test_convert_to_project_name_property_is_idempotent', () {
    final Random random = seededRandom(9602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String projectName = convertToProjectName(randomText(random));

      final String convertedAgain = convertToProjectName(projectName);

      expect(convertedAgain, projectName);
    }
  });

  test('test_convert_to_project_name_property_never_empty_for_a_name', () {
    final Random random = seededRandom(9603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folderOrRepositoryName = '${randomText(random)} ';

      final String projectName = convertToProjectName(folderOrRepositoryName);

      expect(projectName, isNotEmpty);
    }
  });

  test('test_convert_to_project_name_property_keeps_a_lowercase_name', () {
    final Random random = seededRandom(9604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folderOrRepositoryName = _randomLettersAndDigits(random);

      final String projectName = convertToProjectName(folderOrRepositoryName);

      expect(projectName, folderOrRepositoryName);
    }
  });

  test('other characters become single dashes', () {
    for (final MapEntry<String, String> example in _nameExamples.entries) {
      expect(convertToProjectName(example.key), example.value);
    }
  });
}
