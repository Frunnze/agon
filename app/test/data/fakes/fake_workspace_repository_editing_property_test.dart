import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_inputs.dart';

void _expectSameExceptPatterns(Workspace actual, Workspace expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.appServerAddress, expected.appServerAddress);
  expect(actual.approvalPolicy, expected.approvalPolicy);
}

void main() {
  test('test_create_workspace_property_refuses_names_breaking_rule', () async {
    final Random random = seededRandom(68001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final String name = randomWorkspaceName(random);
      final String? problem = describeNameProblem(name.trim());

      if (problem == null) {
        final Workspace created = await seeded.repository.createWorkspace(
          name: name,
        );
        expect(created.name, name.trim());
      } else {
        await expectLater(
          seeded.repository.createWorkspace(name: name),
          throwsArgumentError,
        );
        expect(
          seeded.repository.listWorkspaces(),
          orderedEquals(seeded.workspaces),
        );
      }
    }
  });

  test('test_create_workspace_property_starts_with_defaults', () async {
    final Random random = seededRandom(68002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      final Workspace created = await seeded.repository.createWorkspace(
        name: 'team-$i',
      );

      expect(created.protectedFiles, galleryDefaultProtectedFiles);
      expect(created.approvalPolicy, ApprovalPolicy.neverAsk);
      expect(
        created.appServerAddress,
        seeded.repository.findAppServerStatus().address,
      );
      expect(seeded.repository.listWorkspaces().last, same(created));
    }
  });

  test('test_create_workspace_property_keeps_the_current_one', () async {
    final Random random = seededRandom(68003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace current = seeded.repository.currentWorkspace();
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);

      await seeded.repository.createWorkspace(name: 'team-$i');

      expect(seeded.repository.currentWorkspace(), same(current));
      expect(notifications.count, 1);
    }
  });

  test('test_save_protected_files_property_only_that_workspace', () async {
    final Random random = seededRandom(68004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final List<String> patterns = randomPatterns(random);

      final Workspace saved = await seeded.repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: patterns,
      );

      expect(saved.protectedFiles, orderedEquals(patterns));
      _expectSameExceptPatterns(saved, target);
      expectOtherWorkspacesUntouched(
        seeded.repository,
        seeded.workspaces,
        saved,
      );
    }
  });

  test('test_save_protected_files_property_keeps_a_frozen_copy', () async {
    final Random random = seededRandom(68005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final List<String> patterns = randomPatterns(random);
      final List<String> expected = List<String>.of(patterns);

      await seeded.repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: patterns,
      );
      patterns.add('added-after-saving');

      final Workspace stored = seeded.repository.listWorkspaces().firstWhere(
        (Workspace workspace) => workspace.id == target.id,
      );
      expect(stored.protectedFiles, orderedEquals(expected));
    }
  });

  test('test_save_protected_files_property_saving_twice_is_once', () async {
    final Random random = seededRandom(68006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final List<String> patterns = randomPatterns(random);

      final Workspace once = await seeded.repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: patterns,
      );
      final Workspace twice = await seeded.repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: patterns,
      );

      expect(twice.protectedFiles, orderedEquals(once.protectedFiles));
      _expectSameExceptPatterns(twice, once);
    }
  });

  test('test_reset_protected_files_property_restores_defaults', () async {
    final Random random = seededRandom(68007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);

      final Workspace reset = await seeded.repository.resetProtectedFiles(
        target.id,
      );

      expect(
        reset.protectedFiles,
        orderedEquals(galleryDefaultProtectedFiles),
      );
      _expectSameExceptPatterns(reset, target);
    }
  });

  test(
    'test_reset_protected_files_property_resetting_is_idempotent',
    () async {
      final Random random = seededRandom(68008);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SeededWorkspaces seeded = seedRandomWorkspaces(random);
        final Workspace target = pickOne(random, seeded.workspaces);

        final Workspace once = await seeded.repository.resetProtectedFiles(
          target.id,
        );
        final Workspace twice = await seeded.repository.resetProtectedFiles(
          target.id,
        );

        expect(twice.protectedFiles, orderedEquals(once.protectedFiles));
      }
    },
  );

  test('test_reset_protected_files_property_undoes_any_save', () async {
    final Random random = seededRandom(68009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      await seeded.repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: randomPatterns(random),
      );

      final Workspace reset = await seeded.repository.resetProtectedFiles(
        target.id,
      );

      expect(
        reset.protectedFiles,
        orderedEquals(galleryDefaultProtectedFiles),
      );
      expectOtherWorkspacesUntouched(
        seeded.repository,
        seeded.workspaces,
        reset,
      );
    }
  });

  test('test_replace_protected_files_property_notifies_once', () async {
    final Random random = seededRandom(68010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);
      final Workspace target = pickOne(random, seeded.workspaces);

      if (random.nextBool()) {
        await seeded.repository.resetProtectedFiles(target.id);
      } else {
        await seeded.repository.saveProtectedFiles(
          workspaceId: target.id,
          patterns: randomPatterns(random),
        );
      }

      expect(notifications.count, 1);
    }
  });

  test('test_replace_protected_files_property_list_is_frozen', () async {
    final Random random = seededRandom(68011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace saved = await seeded.repository.saveProtectedFiles(
        workspaceId: pickOne(random, seeded.workspaces).id,
        patterns: randomPatterns(random),
      );

      expect(() => saved.protectedFiles.add('x'), throwsUnsupportedError);
    }
  });

  test('test_replace_protected_files_property_keeps_current', () async {
    final Random random = seededRandom(68012);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace current = seeded.repository.currentWorkspace();
      final Workspace target = pickOne(random, seeded.workspaces);

      final Workspace saved = await seeded.repository.saveProtectedFiles(
        workspaceId: target.id,
        patterns: randomPatterns(random),
      );

      final Workspace expected = current.id == target.id ? saved : current;
      expect(seeded.repository.currentWorkspace(), same(expected));
    }
  });
}
