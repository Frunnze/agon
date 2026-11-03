import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';

const List<String> _segmentWords = <String>[
  'src',
  'Src',
  'auth',
  '.github',
  'README.md',
  'a.ts',
  'B.ts',
  'z',
];
const String _address = 'github.com/acme/app';

RepositoryBranchLocation _locationOf(String address) {
  return RepositoryBranchLocation(
    projectId: GalleryProjectIds.acmeApp,
    repositoryAddress: address,
    runnerId: GalleryDeviceIds.officeServer,
    branch: 'main',
  );
}

List<FakeRepositoryFile> _randomFiles(Random random) {
  final Map<String, FakeRepositoryFile> files = <String, FakeRepositoryFile>{};
  for (int index = 0; index < 1 + random.nextInt(8); index += 1) {
    final String path = <String>[
      for (int depth = 0; depth <= random.nextInt(3); depth += 1)
        pickOne(random, _segmentWords),
    ].join('/');
    files[path] = FakeRepositoryFile(
      repositoryAddress: _address,
      path: path,
      size: random.nextInt(100000),
      preview: const TextFilePreview('text'),
    );
  }
  final Set<String> folders = <String>{};
  for (final String path in files.keys) {
    folders.addAll(_listFolderPrefixes(path));
  }
  return <FakeRepositoryFile>[
    for (final FakeRepositoryFile file in files.values)
      if (!folders.contains(file.path)) file,
  ];
}

List<String> _listFolderPrefixes(String path) {
  final List<String> segments = path.split('/');
  return <String>[
    for (int index = 1; index < segments.length; index += 1)
      segments.sublist(0, index).join('/'),
  ];
}

bool _isOrdered(List<RepositoryEntry> entries) {
  for (int index = 1; index < entries.length; index += 1) {
    final RepositoryEntry previous = entries[index - 1];
    final RepositoryEntry current = entries[index];
    final bool previousIsFolder = previous.kind == RepositoryEntryKind.folder;
    final bool currentIsFolder = current.kind == RepositoryEntryKind.folder;
    if (previousIsFolder != currentIsFolder) {
      if (!previousIsFolder) {
        return false;
      }
      continue;
    }
    final int order = previous.name.toLowerCase().compareTo(
      current.name.toLowerCase(),
    );
    if (order > 0) {
      return false;
    }
  }
  return true;
}

void main() {
  test('test_list_folder_property_folders_first_then_names', () async {
    final Random random = seededRandom(9501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = _randomFiles(random);
      final FakeFileRepository repository = FakeFileRepository(
        sources: const <String, RepositoryFileSource>{},
        files: files,
      );

      for (final FakeRepositoryFile file in files) {
        final int separator = file.path.lastIndexOf('/');
        final String folder = separator < 0
            ? ''
            : file.path.substring(0, separator);
        final List<RepositoryEntry> entries = await repository.listFolder(
          location: _locationOf(_address),
          folder: folder,
        );
        final RepositoryEntry entry = entries.singleWhere(
          (RepositoryEntry entry) =>
              entry.name == file.path.substring(separator + 1),
        );

        expect(_isOrdered(entries), isTrue);
        expect(entry.kind, RepositoryEntryKind.file);
        expect(entry.size, file.size);
      }
    }
  });

  test('test_read_file_property_returns_the_declared_file', () async {
    final Random random = seededRandom(9502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = _randomFiles(random);
      final FakeFileRepository repository = FakeFileRepository(
        sources: const <String, RepositoryFileSource>{},
        files: files,
      );
      final FakeRepositoryFile chosen = pickOne(random, files);
      final RepositoryFile file = await repository.readFile(
        location: _locationOf(_address),
        path: chosen.path,
      );

      expect(file.path, chosen.path);
      expect(file.size, chosen.size);
      await expectLater(
        repository.readFile(
          location: _locationOf(_address),
          path: '${chosen.path}/missing',
        ),
        throwsStateError,
      );
    }
  });

  test('test_open_repository_property_unknown_has_no_holders', () async {
    final FakeFileRepository repository = FakeFileRepository(
      sources: galleryFileSources,
      files: galleryRepositoryFiles,
    );
    final RepositoryFileSource unknown = await repository.openRepository(
      projectId: const ProjectId('project'),
      repositoryAddress: 'github.com/acme/unknown',
      preferredRunnerId: null,
    );

    expect(unknown, isA<FilesWithoutRunner>());
    expect((unknown as FilesWithoutRunner).holders, isEmpty);
  });

  test('gallery root lists the design tree', () async {
    final FakeFileRepository repository = FakeFileRepository(
      sources: galleryFileSources,
      files: galleryRepositoryFiles,
    );
    final List<RepositoryEntry> root = await repository.listFolder(
      location: _locationOf(galleryAppRepositoryAddress),
      folder: '',
    );

    expect(root.map((RepositoryEntry entry) => entry.name), <String>[
      '.github',
      'android',
      'assets',
      'ios',
      'src',
      '.gitignore',
      'package.json',
      'README.md',
      'tsconfig.json',
    ]);
  });
}
