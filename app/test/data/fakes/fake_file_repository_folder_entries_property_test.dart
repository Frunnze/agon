import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';
import 'support/repository_file_inputs.dart';

void main() {
  test('test_describe_folder_property_folder_entries_have_no_size', () async {
    final Random random = seededRandom(64707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);

      for (final String folder in listEveryFileTestFolder(files)) {
        for (final RepositoryEntry entry in await listFileTestFolder(
          repository,
          folder,
        )) {
          final bool isFolder = entry.kind == RepositoryEntryKind.folder;
          expect(entry.size == null, isFolder);
        }
      }
    }
  });

  test('test_describe_folder_property_one_entry_per_folder', () async {
    final Random random = seededRandom(64708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);

      for (final String folder in listEveryFileTestFolder(files)) {
        final List<String> names = describeEntryNames(
          await listFileTestFolder(repository, folder),
        );
        expect(names.toSet().length, names.length);
      }
    }
  });

  test('test_describe_folder_property_every_listed_folder_can_be_'
      'listed', () async {
    final Random random = seededRandom(64709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      final String folder = pickOne(random, listEveryFileTestFolder(files));

      for (final RepositoryEntry entry in await listFileTestFolder(
        repository,
        folder,
      )) {
        if (entry.kind != RepositoryEntryKind.folder) {
          continue;
        }
        final String child = folder.isEmpty
            ? entry.name
            : '$folder$fileTestSeparator${entry.name}';
        expect(await listFileTestFolder(repository, child), isNotEmpty);
      }
    }
  });
}
