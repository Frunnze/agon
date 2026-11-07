import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';

Workflow randomEmptyWorkflow(Random random) {
  return Workflow(
    id: WorkflowId('workflow-${random.nextInt(1000)}'),
    name: 'flow-${random.nextInt(1000)}',
    availability: const AllWorkspaces(),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
}

Workflow _addBlankStepTo(Random random, FakeWorkflowRepository repository) {
  final Workflow stored = pickOne(random, repository.listWorkflows());
  return addAgent(stored, buildBlankAgent(stored));
}

void main() {
  test('test_list_workflows_property_ids_stay_unique_after_saves', () async {
    final Random random = seededRandom(601);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      await repository.saveWorkflow(_addBlankStepTo(random, repository));
      await expectLater(
        repository.saveWorkflow(randomEmptyWorkflow(random)),
        throwsA(isA<RecordNotFound>()),
      );
      final List<Workflow> workflows = repository.listWorkflows();
      expect(
        workflows.map((Workflow workflow) => workflow.id).toSet().length,
        workflows.length,
      );
      expect(workflows, hasLength(galleryWorkflows.length));
    }
  });

  test('test_find_workflow_property_finds_every_seeded_workflow', () {
    final Random random = seededRandom(602);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, galleryWorkflows);
      expect(repository.findWorkflow(workflow.id).name, workflow.name);
    }
    expect(
      () => repository.findWorkflow(const WorkflowId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_find_pending_change_property_only_changed_workflows', () {
    final Random random = seededRandom(603);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final WorkflowChange? change = repository.findPendingChange(workflow.id);
      expect(change != null, workflow.id == GalleryWorkflowIds.trainRanker);
    }
  });

  test('test_save_workflow_property_saved_version_is_found', () async {
    final Random random = seededRandom(604);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _addBlankStepTo(random, repository);
      await repository.saveWorkflow(workflow);
      final Workflow found = repository.findWorkflow(workflow.id);
      expect(hasSameDesign(found, workflow), isTrue);
    }
  });

  test('test_sign_workflow_property_signed_and_change_cleared', () async {
    final Random random = seededRandom(605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final WorkflowChange? change = repository.findPendingChange(workflow.id);
      final Workflow signed = await repository.signWorkflow(workflow.id);

      expect(signed.signature?.signedBy, GalleryDeviceIds.airLaptop);
      expect(repository.findPendingChange(workflow.id), isNull);
      if (change != null) {
        expect(signed.signature?.signedDocument, change.changedDocument);
      }
    }
  });

  test('test_discard_change_property_keeps_old_signature', () async {
    final Random random = seededRandom(606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();
      final Workflow workflow = pickOne(random, galleryWorkflows);

      if (workflow.id == GalleryWorkflowIds.trainRanker) {
        final Workflow kept = await repository.discardChange(workflow.id);
        expect(kept.signature?.signedDocument, trainRankerSignedDocument);
        expect(repository.findPendingChange(workflow.id), isNull);
      } else {
        await expectLater(
          repository.discardChange(workflow.id),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
  });
}
