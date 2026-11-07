import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';
import 'support/repository_file_inputs.dart';

RepositoryFileSource _randomSource(Random random) {
  if (random.nextBool()) {
    return FilesWithoutRunner(holders: const <RepositoryHolder>[]);
  }
  return FilesFromRunner(
    runnerId: DeviceId(randomText(random)),
    runnerName: randomText(random),
    branches: <String>['main', randomText(random)],
    taskBranches: const <String>[],
  );
}

void main() {
  test('test_fake_repository_file_new_property_keeps_every_field', () {
    final Random random = seededRandom(64601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomText(random);
      final String path = randomFilePath(random);
      final int size = random.nextInt(1 << 31);
      final FilePreview preview = randomFilePreview(random);

      final FakeRepositoryFile file = FakeRepositoryFile(
        repositoryAddress: address,
        path: path,
        size: size,
        preview: preview,
      );

      expect(file.repositoryAddress, address);
      expect(file.path, path);
      expect(file.size, size);
      expect(file.preview, same(preview));
    }
  });

  test('test_fake_repository_file_new_property_belongs_only_to_its_'
      'repository', () async {
    final Random random = seededRandom(64603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestOtherAddress,
      );
      final FakeFileRepository repository = buildFileRepository(files);

      for (final FakeRepositoryFile file in files) {
        await expectLater(
          repository.readFile(
            location: buildFileTestLocation(fileTestAddress),
            path: file.path,
          ),
          throwsStateError,
        );
      }
    }
  });

  test('test_fake_file_repository_new_property_later_changes_to_the_seeds_'
      'do_not_leak', () async {
    final Random random = seededRandom(64604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final RepositoryFileSource source = _randomSource(random);
      final Map<String, RepositoryFileSource> sources =
          <String, RepositoryFileSource>{fileTestAddress: source};
      final FakeFileRepository repository = FakeFileRepository(
        sources: sources,
        files: files,
      );
      final List<String> rootBefore = describeEntryNames(
        await repository.listFolder(
          location: buildFileTestLocation(fileTestAddress),
          folder: '',
        ),
      );

      files.clear();
      sources.clear();

      final List<RepositoryEntry> rootAfter = await repository.listFolder(
        location: buildFileTestLocation(fileTestAddress),
        folder: '',
      );
      expect(describeEntryNames(rootAfter), rootBefore);
      final RepositoryFileSource opened = await repository.openRepository(
        projectId: const ProjectId('project'),
        repositoryAddress: fileTestAddress,
        preferredRunnerId: null,
      );
      expect(opened, same(source));
    }
  });

  test('test_fake_file_repository_new_property_without_files_the_root_is_'
      'empty', () async {
    final Random random = seededRandom(64605);
    final FakeFileRepository repository = buildFileRepository(
      const <FakeRepositoryFile>[],
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryEntry> root = await repository.listFolder(
        location: buildFileTestLocation(randomText(random)),
        folder: '',
      );

      expect(root, isEmpty);
      await expectLater(
        repository.readFile(
          location: buildFileTestLocation(fileTestAddress),
          path: randomFilePath(random),
        ),
        throwsStateError,
      );
    }
  });

  test('test_fake_file_repository_new_property_two_repositories_never_'
      'mix', () async {
    final Random random = seededRandom(64606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> own = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final List<FakeRepositoryFile> other = randomRepositoryFiles(
        random,
        address: fileTestOtherAddress,
      );
      final FakeFileRepository alone = buildFileRepository(own);
      final FakeFileRepository mixed = buildFileRepository(
        <FakeRepositoryFile>[...other, ...own],
      );

      final List<RepositoryEntry> fromAlone = await alone.listFolder(
        location: buildFileTestLocation(fileTestAddress),
        folder: '',
      );
      final List<RepositoryEntry> fromMixed = await mixed.listFolder(
        location: buildFileTestLocation(fileTestAddress),
        folder: '',
      );

      expect(describeEntryNames(fromMixed), describeEntryNames(fromAlone));
    }
  });

  test('test_open_repository_property_returns_the_seeded_source', () async {
    final Random random = seededRandom(64607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomText(random);
      final RepositoryFileSource source = _randomSource(random);
      final FakeFileRepository repository = FakeFileRepository(
        sources: <String, RepositoryFileSource>{address: source},
        files: const <FakeRepositoryFile>[],
      );

      final RepositoryFileSource opened = await repository.openRepository(
        projectId: ProjectId(randomText(random)),
        repositoryAddress: address,
        preferredRunnerId: null,
      );

      expect(opened, same(source));
    }
  });

  test('test_open_repository_property_unknown_addresses_have_no_'
      'holders', () async {
    final Random random = seededRandom(64608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomText(random);
      final FakeFileRepository repository = FakeFileRepository(
        sources: <String, RepositoryFileSource>{
          '$address-known': _randomSource(random),
        },
        files: randomRepositoryFiles(random, address: address),
      );

      final RepositoryFileSource opened = await repository.openRepository(
        projectId: const ProjectId('project'),
        repositoryAddress: address,
        preferredRunnerId: DeviceId(randomText(random)),
      );

      expect(opened, isA<FilesWithoutRunner>());
      expect((opened as FilesWithoutRunner).holders, isEmpty);
    }
  });

  test('test_open_repository_property_ignores_the_project_and_preferred_'
      'runner', () async {
    final Random random = seededRandom(64609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryFileSource source = _randomSource(random);
      final FakeFileRepository repository = FakeFileRepository(
        sources: <String, RepositoryFileSource>{fileTestAddress: source},
        files: const <FakeRepositoryFile>[],
      );

      final RepositoryFileSource first = await repository.openRepository(
        projectId: ProjectId(randomText(random)),
        repositoryAddress: fileTestAddress,
        preferredRunnerId: DeviceId(randomText(random)),
      );
      final RepositoryFileSource second = await repository.openRepository(
        projectId: ProjectId(randomText(random)),
        repositoryAddress: fileTestAddress,
        preferredRunnerId: null,
      );

      expect(first, same(second));
    }
  });
}
