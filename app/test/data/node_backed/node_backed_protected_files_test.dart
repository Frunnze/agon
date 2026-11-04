import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';
import 'support/simulated_protected_files.dart';

const Duration _retryInterval = Duration(seconds: 30);
final DateTime _now = DateTime.utc(2026, 11, 4, 12);
const int _largestPatternCount = 6;
const int _workspaceCount = 3;

final class _LoadedRepository {
  const _LoadedRepository({required this.simulated, required this.repository});

  final SimulatedCatalogNode simulated;
  final NodeBackedWorkspaceRepository repository;
}

Future<_LoadedRepository> _loadRepository() async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (int i = 0; i < _workspaceCount; i += 1) {
    simulated.addWorkspace('workspace-$i');
  }
  final NodeBackedWorkspaceRepository repository =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(_now),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await repository.load();
  return _LoadedRepository(simulated: simulated, repository: repository);
}

List<String> _randomPatterns(Random random) {
  final int patternCount = random.nextInt(_largestPatternCount);
  return <String>[
    for (int i = 0; i < patternCount; i += 1)
      'pattern-$i-${randomText(random)}',
  ];
}

List<Object?> _readNodePatterns(
  SimulatedCatalogNode simulated,
  WorkspaceId workspaceId,
) {
  for (final Map<String, Object?> workspace in simulated.workspaces) {
    if (workspace['id'] == workspaceId.value) {
      final Map<String, Object?> protectedFiles =
          workspace['protected_files']! as Map<String, Object?>;
      return protectedFiles['patterns']! as List<Object?>;
    }
  }
  throw StateError('the simulated node has no workspace $workspaceId');
}

Workspace _findListedWorkspace(
  NodeBackedWorkspaceRepository repository,
  WorkspaceId workspaceId,
) {
  for (final Workspace workspace in repository.listWorkspaces()) {
    if (workspace.id == workspaceId) {
      return workspace;
    }
  }
  throw StateError('the repository lists no workspace $workspaceId');
}

List<List<String>> _listEveryWorkspacePatterns(
  NodeBackedWorkspaceRepository repository,
) {
  return <List<String>>[
    for (final Workspace workspace in repository.listWorkspaces())
      workspace.protectedFiles,
  ];
}

void main() {
  test('test_load_property_reads_every_workspace_patterns', () async {
    final _LoadedRepository loaded = await _loadRepository();

    for (final Workspace workspace in loaded.repository.listWorkspaces()) {
      expect(workspace.protectedFiles, simulatedDefaultProtectedFiles);
    }
    loaded.repository.dispose();
  });

  test('test_save_protected_files_property_mirrors_node_patterns', () async {
    final Random random = seededRandom(9651);
    final _LoadedRepository loaded = await _loadRepository();
    final NodeBackedWorkspaceRepository repository = loaded.repository;

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace chosen = pickOne(random, repository.listWorkspaces());
      final List<String> patterns = _randomPatterns(random);

      final Workspace saved = await repository.saveProtectedFiles(
        workspaceId: chosen.id,
        patterns: patterns,
      );

      expect(saved.id, chosen.id);
      expect(saved.protectedFiles, patterns);
      expect(_readNodePatterns(loaded.simulated, chosen.id), patterns);
      expect(repository.listWorkspaces().length, _workspaceCount);
      expect(_findListedWorkspace(repository, chosen.id), same(saved));
    }
    repository.dispose();
  });

  test('test_save_protected_files_property_leaves_others_alone', () async {
    final Random random = seededRandom(9652);
    final _LoadedRepository loaded = await _loadRepository();
    final NodeBackedWorkspaceRepository repository = loaded.repository;

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<List<String>> before = _listEveryWorkspacePatterns(
        repository,
      );
      final int chosenIndex = random.nextInt(_workspaceCount);
      final WorkspaceId chosenId = repository.listWorkspaces()[chosenIndex].id;

      await repository.saveProtectedFiles(
        workspaceId: chosenId,
        patterns: _randomPatterns(random),
      );

      final List<List<String>> after = _listEveryWorkspacePatterns(repository);
      for (int index = 0; index < _workspaceCount; index += 1) {
        if (index != chosenIndex) {
          expect(after[index], before[index]);
        }
      }
    }
    repository.dispose();
  });

  test('test_reset_protected_files_property_restores_node_defaults', () async {
    final Random random = seededRandom(9653);
    final _LoadedRepository loaded = await _loadRepository();
    final NodeBackedWorkspaceRepository repository = loaded.repository;

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace chosen = pickOne(random, repository.listWorkspaces());
      await repository.saveProtectedFiles(
        workspaceId: chosen.id,
        patterns: _randomPatterns(random),
      );

      final Workspace reset = await repository.resetProtectedFiles(chosen.id);

      final Workspace listed = _findListedWorkspace(repository, chosen.id);
      expect(reset.protectedFiles, simulatedDefaultProtectedFiles);
      expect(listed.protectedFiles, simulatedDefaultProtectedFiles);
    }
    repository.dispose();
  });

  test('test_save_protected_files_property_notifies_once_per_save', () async {
    final Random random = seededRandom(9654);
    final _LoadedRepository loaded = await _loadRepository();
    final NodeBackedWorkspaceRepository repository = loaded.repository;
    int notificationCount = 0;
    repository.addListener(() => notificationCount += 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = repository.currentWorkspace().id;
      if (random.nextBool()) {
        await repository.saveProtectedFiles(
          workspaceId: workspaceId,
          patterns: _randomPatterns(random),
        );
      } else {
        await repository.resetProtectedFiles(workspaceId);
      }

      expect(notificationCount, i + 1);
    }
    repository.dispose();
  });

  test('test_save_protected_files_property_refusal_keeps_the_copy', () async {
    final Random random = seededRandom(9655);
    final _LoadedRepository loaded = await _loadRepository();
    final NodeBackedWorkspaceRepository repository = loaded.repository;
    final WorkspaceId workspaceId = repository.currentWorkspace().id;
    loaded.simulated.failingCommands.addAll(<String>{
      'set_protected_files',
      'reset_protected_files',
    });

    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        repository.saveProtectedFiles(
          workspaceId: workspaceId,
          patterns: _randomPatterns(random),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.resetProtectedFiles(workspaceId),
        throwsStateError,
      );

      expect(
        repository.currentWorkspace().protectedFiles,
        simulatedDefaultProtectedFiles,
      );
    }
    repository.dispose();
  });

  test('test_save_protected_files_property_missing_workspace_fails', () async {
    final Random random = seededRandom(9656);
    final _LoadedRepository loaded = await _loadRepository();
    final NodeBackedWorkspaceRepository repository = loaded.repository;

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
      expect(repository.listWorkspaces().length, _workspaceCount);
    }
    repository.dispose();
  });
}
