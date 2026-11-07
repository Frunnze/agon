import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';

import 'support/gallery_records.dart';

const String _taskBranchPrefix = 'task/';
const String _pathSeparator = '/';
const int _largestTextPreviewBytes = 1024 * 1024;
const int _largestImagePreviewBytes = 5 * 1024 * 1024;
const List<String> _unsafePathParts = <String>['', '.', '..'];

(Project, Repository) _findRepository(String address) {
  for (final Project project in galleryProjects) {
    for (final Repository repository in project.repositories) {
      if (repository.address == address) {
        return (project, repository);
      }
    }
  }
  throw StateError('No gallery project has the repository $address');
}

void main() {
  test('test_gallery_file_sources_property_keyed_by_canonical_project_'
      'repositories', () {
    for (final String address in galleryFileSources.keys) {
      expect(parseRepositoryAddress(address), address);
      _findRepository(address);
    }
    expect(galleryFileSources.keys, contains(galleryAppRepositoryAddress));
    expect(galleryFileSources.keys, contains(galleryApiRepositoryAddress));
  });

  test('test_gallery_file_sources_property_runners_hold_the_project_'
      'workspace', () {
    for (final MapEntry<String, RepositoryFileSource> entry
        in galleryFileSources.entries) {
      final RepositoryFileSource source = entry.value;
      if (source is! FilesFromRunner) {
        continue;
      }
      final (Project project, Repository repository) = _findRepository(
        entry.key,
      );
      final Device runner = findGalleryDevice(source.runnerId);

      expect(source.runnerName, runner.name);
      expect(roleRunsTasks(runner.role), isTrue);
      expect(runner.workspaces, contains(project.workspaceId));
      expect(source.branches, contains(repository.defaultBranch));
    }
  });

  test('test_gallery_file_sources_property_branch_lists_are_clean', () {
    for (final RepositoryFileSource source in galleryFileSources.values) {
      if (source is! FilesFromRunner) {
        continue;
      }
      final Set<String> branches = source.branches.toSet();

      expect(hasNoRepeats(source.branches), isTrue);
      expect(hasNoRepeats(source.taskBranches), isTrue);
      for (final String branch in source.taskBranches) {
        expect(branch, startsWith(_taskBranchPrefix));
        expect(branches.contains(branch), isFalse, reason: branch);
      }
    }
  });

  test('test_gallery_file_sources_property_holders_match_their_devices', () {
    for (final RepositoryFileSource source in galleryFileSources.values) {
      if (source is! FilesWithoutRunner) {
        continue;
      }
      expect(source.holders, isNotEmpty);
      for (final RepositoryHolder holder in source.holders) {
        final Device device = findGalleryDevice(holder.deviceId);

        expect(holder.name, device.name);
        expect(holder.lastSeen, device.lastSeen);
        expect(holder.lastSeen.isAfter(galleryNow), isFalse);
      }
    }
  });

  test('test_gallery_repository_files_property_read_from_a_runner', () {
    for (final FakeRepositoryFile file in galleryRepositoryFiles) {
      final RepositoryFileSource? source =
          galleryFileSources[file.repositoryAddress];

      expect(source, isA<FilesFromRunner>(), reason: file.path);
    }
  });

  test('test_gallery_repository_files_property_paths_are_unique_and_'
      'relative', () {
    final List<String> keys = <String>[
      for (final FakeRepositoryFile file in galleryRepositoryFiles)
        '${file.repositoryAddress} ${file.path}',
    ];

    expect(hasNoRepeats(keys), isTrue);
    for (final FakeRepositoryFile file in galleryRepositoryFiles) {
      final List<String> parts = file.path.split(_pathSeparator);
      for (final String part in parts) {
        expect(_unsafePathParts.contains(part), isFalse, reason: file.path);
      }
    }
  });

  test('test_gallery_repository_files_property_previews_follow_the_node_'
      'limits', () {
    for (final FakeRepositoryFile file in galleryRepositoryFiles) {
      final FilePreview preview = file.preview;
      expect(file.size, greaterThan(0), reason: file.path);

      switch (preview) {
        case TextFilePreview():
          expect(file.size, lessThanOrEqualTo(_largestTextPreviewBytes));
          expect(preview.text.trim(), isNotEmpty, reason: file.path);
        case ImageFilePreview():
          expect(file.size, lessThanOrEqualTo(_largestImagePreviewBytes));
          expect(preview.width, greaterThan(0));
          expect(preview.height, greaterThan(0));
          expect(preview.bytes, isNotEmpty);
        case UnavailableFilePreview():
          if (preview.reason == PreviewUnavailableReason.tooLarge) {
            expect(file.size, greaterThan(_largestTextPreviewBytes));
          }
      }
    }
  });
}
