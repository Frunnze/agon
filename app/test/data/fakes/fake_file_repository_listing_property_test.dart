import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';
import 'support/repository_file_inputs.dart';

int _compareLikeTheNode(ListedEntryView first, ListedEntryView second) {
  final int firstRank = first.kind == RepositoryEntryKind.folder ? 0 : 1;
  final int secondRank = second.kind == RepositoryEntryKind.folder ? 0 : 1;
  if (firstRank != secondRank) {
    return firstRank - secondRank;
  }
  final int ignoringCase = compareFileTestCodePoints(
    first.name.toLowerCase(),
    second.name.toLowerCase(),
  );
  if (ignoringCase != 0) {
    return ignoringCase;
  }
  return compareFileTestCodePoints(first.name, second.name);
}

List<ListedEntryView> _modelListing(
  List<FakeRepositoryFile> files,
  String folder,
) {
  final String prefix = folder.isEmpty ? '' : '$folder$fileTestSeparator';
  final Map<String, ListedEntryView> byName = <String, ListedEntryView>{};
  for (final FakeRepositoryFile file in files) {
    if (!file.path.startsWith(prefix)) {
      continue;
    }
    final List<String> rest = file.path
        .substring(prefix.length)
        .split(fileTestSeparator);
    final bool isDirect = rest.length == 1;
    byName[rest.first] = (
      name: rest.first,
      kind: isDirect ? RepositoryEntryKind.file : RepositoryEntryKind.folder,
      size: isDirect ? file.size : null,
    );
  }
  final List<ListedEntryView> ordered = byName.values.toList();
  ordered.sort(_compareLikeTheNode);
  return ordered;
}

void main() {
  test('test_list_folder_property_matches_a_reference_model', () async {
    final Random random = seededRandom(64701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);

      for (final String folder in listEveryFileTestFolder(files)) {
        final List<RepositoryEntry> listed = await listFileTestFolder(
          repository,
          folder,
        );

        expect(
          describeListedEntries(listed),
          orderedEquals(_modelListing(files, folder)),
          reason: folder,
        );
      }
    }
  });

  test('test_list_folder_property_normalizes_the_folder_like_the_'
      'node', () async {
    final Random random = seededRandom(64702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      final String folder = pickOne(random, listEveryFileTestFolder(files));
      final String typed = pickOne(random, <String>[
        './$folder',
        './/$folder/.',
        folder.replaceAll(fileTestSeparator, '//'),
        folder.replaceAll(fileTestSeparator, '/./'),
      ]);

      final List<RepositoryEntry> plain = await listFileTestFolder(
        repository,
        folder,
      );
      final List<RepositoryEntry> noisy = await listFileTestFolder(
        repository,
        typed,
      );

      expect(
        describeListedEntries(noisy),
        orderedEquals(describeListedEntries(plain)),
      );
    }
  });

  test('test_list_folder_property_missing_or_leaving_folders_are_'
      'refused', () async {
    final Random random = seededRandom(64703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      final FakeRepositoryFile file = pickOne(random, files);
      final String refused = pickOne(random, <String>[
        file.path,
        '${file.path}/deeper',
        'missing-${randomText(random)}',
        '/${findParentFolder(file.path)}',
        '../${findParentFolder(file.path)}',
        'src\\auth',
      ]);

      await expectLater(
        listFileTestFolder(repository, refused),
        throwsStateError,
        reason: refused,
      );
    }
  });

  test('test_describe_file_property_file_entries_carry_their_size', () async {
    final Random random = seededRandom(64704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeRepositoryFile file = pickOne(random, files);

      final List<RepositoryEntry> listed = await listFileTestFolder(
        buildFileRepository(files),
        findParentFolder(file.path),
      );

      final RepositoryEntry entry = listed.singleWhere(
        (RepositoryEntry entry) => entry.name == findLastPart(file.path),
      );
      expect(entry.kind, RepositoryEntryKind.file);
      expect(entry.size, file.size);
    }
  });

  test('test_describe_file_property_every_file_is_listed_exactly_'
      'once', () async {
    final Random random = seededRandom(64705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);
      int fileEntryCount = 0;

      for (final String folder in listEveryFileTestFolder(files)) {
        final List<RepositoryEntry> listed = await listFileTestFolder(
          repository,
          folder,
        );
        fileEntryCount += listed
            .where((RepositoryEntry e) => e.kind == RepositoryEntryKind.file)
            .length;
      }

      expect(fileEntryCount, files.length);
    }
  });

  test('test_describe_file_property_names_never_hold_a_separator', () async {
    final Random random = seededRandom(64706);

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
          expect(entry.name, isNot(contains(fileTestSeparator)));
          expect(entry.name, isNotEmpty);
        }
      }
    }
  });

  test('test_list_folder_property_is_unmodifiable', () async {
    final Random random = seededRandom(64712);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final List<RepositoryEntry> root = await listFileTestFolder(
        buildFileRepository(files),
        '',
      );

      expect(() => root.add(root.first), throwsUnsupportedError);
    }
  });
}
