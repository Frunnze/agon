import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';
import 'support/repository_file_inputs.dart';

const List<String> _harmlessPathNoise = <String>['/', '/./', '//'];

String _addHarmlessNoise(Random random, String path) {
  final List<String> segments = path.split(fileTestSeparator);
  final StringBuffer noisy = StringBuffer();
  if (random.nextBool()) {
    noisy.write('./');
  }
  for (int index = 0; index < segments.length; index += 1) {
    if (index > 0) {
      noisy.write(pickOne(random, _harmlessPathNoise));
    }
    noisy.write(segments[index]);
  }
  if (random.nextBool()) {
    noisy.write(fileTestSeparator);
  }
  return noisy.toString();
}

String _makePathLeaveTheRepository(Random random, String path) {
  return pickOne(random, <String>[
    '/$path',
    '../$path',
    '$path/../${findLastPart(path)}',
    '${findParentFolder(path)}\\${findLastPart(path)}',
    '$path\u0000',
  ]);
}

void main() {
  test('test_fake_repository_file_new_property_read_file_hands_back_its_'
      'fields', () async {
    final Random random = seededRandom(64602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeRepositoryFile chosen = pickOne(random, files);

      final RepositoryFile read = await buildFileRepository(files).readFile(
        location: buildFileTestLocation(fileTestAddress),
        path: chosen.path,
      );

      expect(read.path, chosen.path);
      expect(read.size, chosen.size);
      expect(read.preview, same(chosen.preview));
    }
  });

  test('test_read_file_property_normalizes_the_path_like_the_node', () async {
    final Random random = seededRandom(64610);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeRepositoryFile chosen = pickOne(random, files);
      final String typed = _addHarmlessNoise(random, chosen.path);

      final RepositoryFile read = await buildFileRepository(files).readFile(
        location: buildFileTestLocation(fileTestAddress),
        path: typed,
      );

      expect(read.path, chosen.path, reason: typed);
      expect(read.size, chosen.size);
    }
  });

  test('test_read_file_property_paths_leaving_the_repository_are_'
      'refused', () async {
    final Random random = seededRandom(64611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeRepositoryFile chosen = pickOne(random, files);
      final String hostile = _makePathLeaveTheRepository(random, chosen.path);

      await expectLater(
        buildFileRepository(files).readFile(
          location: buildFileTestLocation(fileTestAddress),
          path: hostile,
        ),
        throwsStateError,
        reason: hostile,
      );
    }
  });

  test('test_read_file_property_folders_are_not_files', () async {
    final Random random = seededRandom(64612);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);

      for (final FakeRepositoryFile file in files) {
        for (final String folder in listFolderPrefixes(file.path)) {
          await expectLater(
            repository.readFile(
              location: buildFileTestLocation(fileTestAddress),
              path: folder,
            ),
            throwsStateError,
          );
        }
      }
    }
  });

  test('test_normalize_repository_path_property_listing_and_reading_agree_'
      'on_noisy_paths', () async {
    final Random random = seededRandom(64613);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      final FakeRepositoryFile chosen = pickOne(random, files);
      final String noisyPath = _addHarmlessNoise(random, chosen.path);
      final String parent = findParentFolder(chosen.path);
      final String noisyParent = parent.isEmpty
          ? '.'
          : _addHarmlessNoise(random, parent);

      final RepositoryFile read = await repository.readFile(
        location: buildFileTestLocation(fileTestAddress),
        path: noisyPath,
      );
      final List<RepositoryEntry> listed = await listFileTestFolder(
        repository,
        noisyParent,
      );

      expect(describeEntryNames(listed), contains(findLastPart(read.path)));
      expect(read.path, chosen.path);
    }
  });

  test('test_normalize_repository_path_property_a_parent_part_anywhere_is_'
      'refused', () async {
    final Random random = seededRandom(64614);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      final List<String> segments = pickOne(
        random,
        files,
      ).path.split(fileTestSeparator);
      segments.insert(random.nextInt(segments.length + 1), '..');
      final String hostile = segments.join(fileTestSeparator);

      await expectLater(
        repository.readFile(
          location: buildFileTestLocation(fileTestAddress),
          path: hostile,
        ),
        throwsStateError,
      );
      await expectLater(
        listFileTestFolder(repository, hostile),
        throwsStateError,
      );
    }
  });

  test('test_normalize_repository_path_property_absolute_and_forbidden_'
      'characters_are_refused', () async {
    final Random random = seededRandom(64615);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      final String folder = pickOne(random, listEveryFileTestFolder(files));
      final String hostile = pickOne(random, <String>[
        '/$folder',
        '$folder\\',
        '$folder\u0001',
        '\u007f$folder',
      ]);

      await expectLater(
        listFileTestFolder(repository, hostile),
        throwsStateError,
      );
    }
  });
}
