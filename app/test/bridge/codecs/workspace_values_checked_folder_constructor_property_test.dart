import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';

const int _firstSeed = 9430000;
const String _addressField = 'address';
const String _branchField = 'default_branch';
const String _startedGitField = 'has_started_git';
const List<bool> _flagValues = <bool>[true, false];

JsonObject _randomCheckedFolderJson(Random random) {
  return <String, Object?>{
    _addressField: randomHostileText(random),
    _branchField: randomHostileText(random),
    _startedGitField: random.nextBool(),
  };
}

void main() {
  test('test_checked_local_folder_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomHostileText(random);
      final String defaultBranch = randomHostileText(random);
      final bool hasStartedGit = random.nextBool();

      final CheckedLocalFolder folder = CheckedLocalFolder(
        address: address,
        defaultBranch: defaultBranch,
        hasStartedGit: hasStartedGit,
      );

      expect(folder.address, address);
      expect(folder.defaultBranch, defaultBranch);
      expect(folder.hasStartedGit, hasStartedGit);
    }
  });

  test('test_checked_local_folder_constructor_property_'
      'keeps_both_flag_values_apart_from_the_texts', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = ' ${randomHostileText(random)} ';
      final String defaultBranch = '\t${randomHostileText(random)}\n';

      for (final bool hasStartedGit in _flagValues) {
        final CheckedLocalFolder folder = CheckedLocalFolder(
          address: address,
          defaultBranch: defaultBranch,
          hasStartedGit: hasStartedGit,
        );

        expect(folder.hasStartedGit, hasStartedGit);
        expect(folder.address, address);
        expect(folder.defaultBranch, defaultBranch);
      }
    }
  });

  test('test_checked_local_folder_constructor_property_'
      'rebuilt_from_a_decoded_folder_matches_it', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _randomCheckedFolderJson(random);
      final CheckedLocalFolder decoded = CheckedLocalFolder.fromJson(wireJson);

      final CheckedLocalFolder rebuilt = CheckedLocalFolder(
        address: decoded.address,
        defaultBranch: decoded.defaultBranch,
        hasStartedGit: decoded.hasStartedGit,
      );

      expect(rebuilt.address, wireJson[_addressField]);
      expect(rebuilt.defaultBranch, wireJson[_branchField]);
      expect(rebuilt.hasStartedGit, wireJson[_startedGitField]);
    }
  });
}
