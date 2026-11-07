import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/workflow_inputs.dart';

bool _isArgumentRefusal(Object error) => error is ArgumentError;

Workflow _signedSeed(Random random, int index) {
  return randomValidWorkflow(
    random,
    index: index,
    signature: buildSampleSignature(),
  );
}

FakeWorkflowRepository _buildWith(List<Workflow> workflows) {
  return buildWorkflowRepository(
    workflows: workflows,
    changes: const <WorkflowChange>[],
  );
}

void main() {
  test('test_refuse_upload_problem_property_create_and_save_agree', () async {
    final Random random = seededRandom(68410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[stored],
        changes: const <WorkflowChange>[],
      );
      final Workflow candidate = random.nextBool()
          ? breakWorkflow(random, stored)
          : addBlankStep(stored);
      final bool shouldRefuse = describeUploadProblem(candidate) != null;

      final bool createRefused = await isRefused(
        () => repository.createWorkflow(candidate),
        isRefusal: _isArgumentRefusal,
      );
      final bool saveRefused = await isRefused(
        () => repository.saveWorkflow(candidate),
        isRefusal: _isArgumentRefusal,
      );

      expect(createRefused, shouldRefuse);
      expect(saveRefused, shouldRefuse);
    }
  });

  test('test_refuse_upload_problem_property_names_alone_refused', () async {
    final Random random = seededRandom(68411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow valid = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[valid],
        changes: const <WorkflowChange>[],
      );
      final Workflow renamed = valid.withName(
        pickOne(random, brokenWorkflowNames),
      );

      await expectLater(repository.saveWorkflow(renamed), throwsArgumentError);
      await expectLater(
        repository.createWorkflow(renamed),
        throwsArgumentError,
      );
    }
  });

  test('test_refuse_upload_problem_property_sign_ignores_name', () async {
    final Random random = seededRandom(68412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow renamed = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      ).withName(pickOne(random, brokenWorkflowNames));
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[renamed],
        changes: const <WorkflowChange>[],
      );

      final Workflow signed = await repository.signWorkflow(renamed.id);

      expect(signed.signature, isNotNull);
    }
  });

  test('test_store_edit_property_returns_the_listed_version', () async {
    final Random random = seededRandom(68413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = _signedSeed(random, i);
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);

      final Workflow stored = await repository.changeWorkflow(
        seed.id,
        'Add tests',
        AgentKind.codex,
      );

      expect(repository.listWorkflows().single, same(stored));
    }
  });

  test('test_store_edit_property_refusals_store_nothing', () async {
    final Random random = seededRandom(68414);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = _signedSeed(random, i);
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);

      await expectLater(
        repository.saveWorkflow(breakWorkflow(random, seed)),
        throwsArgumentError,
      );

      expect(repository.listWorkflows().single, same(seed));
      expect(repository.findPendingChange(seed.id), isNull);
      expect(notifications.count, 0);
    }
  });

  test('test_store_edit_property_every_edit_path_keeps_signature', () async {
    final Random random = seededRandom(68415);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = addBlankStep(_signedSeed(random, i));
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);

      await repository.saveWorkflow(addBlankStep(seed));
      await repository.changeWorkflow(seed.id, 'More', AgentKind.geminiCli);
      await repository.fillAgentSettings(seed.id, seed.agents.last.id);

      expect(repository.findWorkflow(seed.id).signature, same(seed.signature));
    }
  });

  test('test_record_unsigned_edit_property_one_change_kept', () async {
    final Random random = seededRandom(68416);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = _signedSeed(random, i);
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);
      await repository.saveWorkflow(addBlankStep(seed));
      final WorkflowChange? first = repository.findPendingChange(seed.id);
      final int editCount = 1 + random.nextInt(3);

      for (int edit = 0; edit < editCount; edit += 1) {
        final Workflow current = repository.findWorkflow(seed.id);
        await repository.saveWorkflow(addBlankStep(current));
      }

      expect(first, isNotNull);
      expect(repository.findPendingChange(seed.id), same(first));
    }
  });

  test('test_record_unsigned_edit_property_says_who_and_when', () async {
    final Random random = seededRandom(68417);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = _signedSeed(random, i);
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);

      await repository.saveWorkflow(addBlankStep(seed));

      final WorkflowChange? change = repository.findPendingChange(seed.id);
      expect(change?.changedBy, GalleryDeviceIds.airLaptop);
      expect(change?.changedAt, galleryNow);
      expect(change?.signedDocument, seed.signature?.signedDocument);
    }
  });

  test('test_record_unsigned_edit_property_unsigned_never_changed', () async {
    final Random random = seededRandom(68418);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow seed = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final FakeWorkflowRepository repository = _buildWith(<Workflow>[seed]);

      await repository.saveWorkflow(addBlankStep(seed));
      await repository.changeWorkflow(seed.id, 'More', AgentKind.claudeCode);

      expect(repository.findPendingChange(seed.id), isNull);
    }
  });
}
