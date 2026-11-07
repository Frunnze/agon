import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

void main() {
  test('test_sign_workflow_property_signs_here_and_now', () async {
    final Random random = seededRandom(67301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final Workflow workflow = pickOne(random, seeded.workflows);
      final WorkflowChange? change = seeded.repository.findPendingChange(
        workflow.id,
      );

      final Workflow signed = await seeded.repository.signWorkflow(
        workflow.id,
      );

      expect(signed.signature?.signedBy, GalleryDeviceIds.airLaptop);
      expect(signed.signature?.signedAt, galleryNow);
      expect(seeded.repository.findPendingChange(workflow.id), isNull);
      expect(hasSameDesign(signed, workflow), isTrue);
      final String? expectedDocument =
          change?.changedDocument ?? workflow.signature?.signedDocument;
      if (expectedDocument != null) {
        expect(signed.signature?.signedDocument, expectedDocument);
      } else {
        expect(signed.signature?.signedDocument, contains(workflow.name));
      }
    }
  });

  test('test_sign_workflow_property_refuses_unknown_and_broken', () async {
    final Random random = seededRandom(67302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow broken = breakWorkflow(
        random,
        randomValidWorkflow(random, index: i, signature: null),
      );
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[broken],
        changes: const <WorkflowChange>[],
      );

      await expectLater(
        repository.signWorkflow(WorkflowId('missing-$i')),
        throwsA(isA<RecordNotFound>()),
      );
      if (describeWorkflowProblem(broken) == null) {
        await repository.signWorkflow(broken.id);
        expect(
          readSignatureState(repository, broken.id),
          SignatureState.signed,
        );
      } else {
        await expectLater(
          repository.signWorkflow(broken.id),
          throwsArgumentError,
        );
        expect(repository.findWorkflow(broken.id).signature, isNull);
      }
    }
  });

  test('test_sign_workflow_property_edits_then_sign_is_signed', () async {
    final Random random = seededRandom(67303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final FakeWorkflowRepository repository = seeded.repository;
      final Workflow workflow = pickOne(random, seeded.workflows);
      final Workflow edited = await repository.saveWorkflow(
        addBlankStep(workflow),
      );

      await repository.signWorkflow(workflow.id);

      final Workflow found = repository.findWorkflow(workflow.id);
      expect(
        readSignatureState(repository, workflow.id),
        SignatureState.signed,
      );
      expect(hasSameDesign(found, edited), isTrue);
      await expectLater(
        repository.discardChange(workflow.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_discard_change_property_needs_a_pending_change', () async {
    final Random random = seededRandom(67304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final Workflow workflow = pickOne(random, seeded.workflows);
      final bool hasChange =
          seeded.repository.findPendingChange(workflow.id) != null;
      if (hasChange) {
        continue;
      }

      await expectLater(
        seeded.repository.discardChange(workflow.id),
        throwsA(
          isA<RecordNotFound>().having(
            (RecordNotFound error) => error.kind,
            'kind',
            'workflow change',
          ),
        ),
      );
      expect(seeded.repository.findWorkflow(workflow.id), same(workflow));
    }
  });

  test('test_discard_change_property_restores_the_signed_steps', () async {
    final Random random = seededRandom(67305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow signed = randomValidWorkflow(
        random,
        index: i,
        signature: buildSampleSignature(),
      );
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[signed],
        changes: const <WorkflowChange>[],
      );
      final int editCount = 1 + random.nextInt(4);
      for (int edit = 0; edit < editCount; edit += 1) {
        final Workflow current = repository.findWorkflow(signed.id);
        await repository.saveWorkflow(addBlankStep(current));
      }
      expect(repository.findPendingChange(signed.id), isNotNull);

      final Workflow kept = await repository.discardChange(signed.id);

      expect(hasSameDesign(kept, signed), isTrue);
      expect(kept.signature, same(signed.signature));
      expect(repository.findWorkflow(signed.id), same(kept));
      expect(readSignatureState(repository, signed.id), SignatureState.signed);
    }
  });

  test('test_discard_change_property_seeded_change_keeps_seed', () async {
    final Random random = seededRandom(67306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null || seeded.changes.isEmpty) {
        continue;
      }
      final WorkflowChange change = pickOne(random, seeded.changes);
      final Workflow seed = seeded.repository.findWorkflow(change.workflowId);

      final Workflow kept = await seeded.repository.discardChange(
        change.workflowId,
      );

      expect(hasSameDesign(kept, seed), isTrue);
      expect(kept.signature, same(seed.signature));
      expect(seeded.repository.findPendingChange(change.workflowId), isNull);
    }
  });
}
