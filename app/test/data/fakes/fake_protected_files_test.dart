import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';

const int _largestPatternCount = 6;

FakeWorkspaceRepository _buildRepository() {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
}

List<String> _randomPatterns(Random random) {
  final int patternCount = random.nextInt(_largestPatternCount);
  return <String>[
    for (int i = 0; i < patternCount; i += 1)
      'pattern-$i-${randomText(random)}',
  ];
}

Workspace _findListed(FakeWorkspaceRepository repository, WorkspaceId id) {
  for (final Workspace workspace in repository.listWorkspaces()) {
    if (workspace.id == id) {
      return workspace;
    }
  }
  throw StateError('the fake lists no workspace $id');
}

void main() {
  test('test_save_protected_files_property_only_that_workspace', () async {
    final Random random = seededRandom(9821);
    final FakeWorkspaceRepository repository = _buildRepository();
    int notificationCount = 0;
    repository.addListener(() => notificationCount += 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace target = pickOne(random, repository.listWorkspaces());
      final List<Workspace> before = repository.listWorkspaces();
      final List<String> patterns = _randomPatterns(random);

      final Workspace saved = await repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: patterns,
      );

      expect(saved.id, target.id);
      expect(saved.name, target.name);
      expect(saved.protectedFiles, patterns);
      expect(notificationCount, i + 1);
      for (final Workspace earlier in before) {
        final Workspace listed = _findListed(repository, earlier.id);
        final List<String> expected = earlier.id == target.id
            ? patterns
            : earlier.protectedFiles;
        expect(listed.protectedFiles, expected);
      }
    }
  });

  test('test_save_protected_files_property_keeps_a_frozen_copy', () async {
    final Random random = seededRandom(9822);
    final FakeWorkspaceRepository repository = _buildRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random);
      final List<String> patternsBefore = List<String>.of(patterns);

      final Workspace saved = await repository.saveProtectedFiles(
        workspaceId: GalleryWorkspaceIds.acme,
        patterns: patterns,
      );
      patterns.add(randomText(random));

      expect(saved.protectedFiles, patternsBefore);
      expect(
        () => saved.protectedFiles.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_reset_protected_files_property_restores_defaults', () async {
    final Random random = seededRandom(9823);
    final FakeWorkspaceRepository repository = _buildRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace target = pickOne(random, repository.listWorkspaces());
      await repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: _randomPatterns(random),
      );

      final Workspace reset = await repository.resetProtectedFiles(target.id);

      expect(reset.protectedFiles, galleryDefaultProtectedFiles);
      expect(
        _findListed(repository, target.id).protectedFiles,
        galleryDefaultProtectedFiles,
      );
    }
  });

  test('test_create_workspace_property_starts_with_defaults', () async {
    final Random random = seededRandom(9824);
    final FakeWorkspaceRepository repository = _buildRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace created = await repository.createWorkspace(
        name: 'created ${random.nextInt(1000)}',
      );

      expect(created.protectedFiles, galleryDefaultProtectedFiles);
    }
  });

  test('test_save_protected_files_property_unknown_workspace_fails', () async {
    final Random random = seededRandom(9825);
    final FakeWorkspaceRepository repository = _buildRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId missing = WorkspaceId('missing-$i');

      await expectLater(
        repository.saveProtectedFiles(
          workspaceId: missing,
          patterns: _randomPatterns(random),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        repository.resetProtectedFiles(missing),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
