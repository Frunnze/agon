import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const List<String> _unsafeParts = <String>['', '.', '..'];
const List<String> _reservedParts = <String>['.', '..'];
const List<String> _unsafeNames = <String>[
  '',
  '.',
  '..',
  ' padded',
  'padded ',
  'a/b',
  'a\\b',
  'tab\there',
  'bell\u0007',
];

String _randomUnsafePath(Random random) {
  final String safePath = randomAbsoluteFolderPath(random);
  return pickOne(random, <String>[
    '/',
    '$safePath/${pickOne(random, _unsafeParts)}/end',
    '$safePath/${pickOne(random, _reservedParts)}',
    '$safePath/bell\u0007',
    '$safePath\u0000/end',
  ]);
}

void main() {
  test('test_check_local_folder_property_trailing_noise_is_dropped_like_'
      'the_node', () async {
    final Random random = seededRandom(64201);
    final FakeDeviceRepository repository = buildFolderTestRepository(
      <String>{},
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomAbsoluteFolderPath(random);
      final String typed =
          '${pickOne(random, <String>['', ' '])}$path'
          '${randomTrailingFolderNoise(random)}';

      final CheckedFolder checked = await repository.checkLocalFolder(typed);

      expect(readCheckedFolderPath(checked), path, reason: typed);
      expect(checked.repository.defaultBranch, isNotEmpty);
    }
  });

  test('test_check_local_folder_property_unsafe_paths_are_refused_like_'
      'the_node', () async {
    final Random random = seededRandom(64202);
    final FakeDeviceRepository repository = buildFolderTestRepository(
      <String>{},
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String unsafePath = _randomUnsafePath(random);

      await expectLater(
        repository.checkLocalFolder(unsafePath),
        throwsStateError,
        reason: unsafePath,
      );
    }
  });

  test('test_check_local_folder_property_relative_paths_are_'
      'refused', () async {
    final Random random = seededRandom(64203);
    final FakeDeviceRepository repository = buildFolderTestRepository(
      <String>{},
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String relative = randomAbsoluteFolderPath(random).substring(1);
      final String typed = pickOne(random, <String>[
        relative,
        '',
        '   ',
        './$relative',
      ]);

      await expectLater(repository.checkLocalFolder(typed), throwsStateError);
    }
  });

  test('test_check_local_folder_property_checking_the_checked_path_is_'
      'idempotent', () async {
    final Random random = seededRandom(64204);
    final FakeDeviceRepository repository = buildFolderTestRepository(
      <String>{},
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomAbsoluteFolderPath(random);
      final String typed = '$path${randomTrailingFolderNoise(random)}';
      final CheckedFolder first = await repository.checkLocalFolder(typed);

      final CheckedFolder second = await repository.checkLocalFolder(
        readCheckedFolderPath(first)!,
      );

      expect(second.repository.address, first.repository.address);
      expect(second.hasStartedGit, first.hasStartedGit);
    }
  });

  test('test_check_local_folder_property_starts_git_only_in_gitless_'
      'folders', () async {
    final Random random = seededRandom(64205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String gitless = randomAbsoluteFolderPath(random);
      final String other = randomAbsoluteFolderPath(random);
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{gitless},
      );

      final CheckedFolder checkedGitless = await repository.checkLocalFolder(
        '$gitless${randomTrailingFolderNoise(random)}',
      );
      final CheckedFolder checkedOther = await repository.checkLocalFolder(
        other,
      );

      expect(checkedGitless.hasStartedGit, isTrue);
      expect(checkedOther.hasStartedGit, other == gitless);
    }
  });

  test('test_create_local_folder_property_joins_parent_and_name_with_one_'
      'separator', () async {
    final Random random = seededRandom(64206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String parent = randomAbsoluteFolderPath(random);
      final String name = pickOne(random, sampleFolderParts);

      final CheckedFolder created = await repository.createLocalFolder(
        parent: '$parent${randomTrailingFolderNoise(random)}',
        name: name,
      );

      expect(readCheckedFolderPath(created), '$parent/$name');
      expect(created.hasStartedGit, isTrue);
      final LocalFolderAddress? folder = parseLocalFolderAddress(
        created.repository.address,
      );
      expect(folder?.deviceId, deviceTestThisDevice);
    }
  });

  test('test_create_local_folder_property_unsafe_names_are_refused_like_'
      'the_node', () async {
    final Random random = seededRandom(64207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String parent = randomAbsoluteFolderPath(random);
      final String unsafeName = pickOne(random, _unsafeNames);

      await expectLater(
        repository.createLocalFolder(parent: parent, name: unsafeName),
        throwsStateError,
        reason: unsafeName,
      );
    }
  });

  test('test_create_local_folder_property_unsafe_or_relative_parents_are_'
      'refused', () async {
    final Random random = seededRandom(64208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String parent = random.nextBool()
          ? _randomUnsafePath(random)
          : randomAbsoluteFolderPath(random).substring(1);

      await expectLater(
        repository.createLocalFolder(parent: parent, name: 'fresh'),
        throwsStateError,
        reason: parent,
      );
    }
  });

  test('test_create_local_folder_property_the_same_folder_is_made_only_'
      'once', () async {
    final Random random = seededRandom(64209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String parent = randomAbsoluteFolderPath(random);
      final String name = pickOne(random, sampleFolderParts);
      await repository.createLocalFolder(parent: parent, name: name);

      await expectLater(
        repository.createLocalFolder(
          parent: '$parent${randomTrailingFolderNoise(random)}',
          name: name,
        ),
        throwsStateError,
      );
      final CheckedFolder sibling = await repository.createLocalFolder(
        parent: parent,
        name: '$name-sibling',
      );
      expect(readCheckedFolderPath(sibling), '$parent/$name-sibling');
    }
  });
}
