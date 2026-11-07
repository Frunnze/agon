import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/workflow_signed_content.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/workflow_inputs.dart';

Workflow _randomWorkflow(Random random, int index) {
  return randomValidWorkflow(
    random,
    index: index,
    signature: random.nextBool() ? buildSampleSignature() : null,
  );
}

Workflow _moveEveryStep(Random random, Workflow workflow) {
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        agent.copyWith(position: randomCanvasPosition(random)),
    ],
    connections: workflow.connections,
  );
}

void main() {
  test('test_has_same_signed_content_property_reflexive_symmetric', () {
    final Random random = seededRandom(67701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow first = _randomWorkflow(random, i);
      final Workflow second = random.nextBool()
          ? _moveEveryStep(random, first)
          : addBlankStep(first);

      expect(hasSameSignedContent(first, first), isTrue);
      expect(
        hasSameSignedContent(first, second),
        hasSameSignedContent(second, first),
      );
    }
  });

  test('test_has_same_signed_content_property_steps_and_names_count', () {
    final Random random = seededRandom(67702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);

      expect(hasSameSignedContent(workflow, addBlankStep(workflow)), isFalse);
      expect(
        hasSameSignedContent(workflow, workflow.withName('renamed-$i')),
        isFalse,
      );
      if (workflow.agents.isNotEmpty) {
        final WorkflowAgent retasked = workflow.agents.first.copyWith(
          task: '${workflow.agents.first.task} and more',
        );
        expect(
          hasSameSignedContent(workflow, replaceAgent(workflow, retasked)),
          isFalse,
        );
      }
    }
  });

  test('test_replace_signature_property_keeps_every_other_field', () {
    final Random random = seededRandom(67705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final WorkflowSignature signature = buildSampleSignature();

      final Workflow replaced = replaceSignature(workflow, signature);

      expect(replaced.id, workflow.id);
      expect(replaced.availability, same(workflow.availability));
      expect(hasSameDesign(replaced, workflow), isTrue);
      expect(replaced.signature, same(signature));
    }
  });

  test('test_replace_signature_property_clearing_is_unsigned', () {
    final Random random = seededRandom(67706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);

      expect(replaceSignature(workflow, null).signature, isNull);
    }
  });

  test('test_replace_signature_property_last_replacement_wins', () {
    final Random random = seededRandom(67707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final WorkflowSignature first = buildSampleSignature();
      final WorkflowSignature second = buildSampleSignature();

      final Workflow twice = replaceSignature(
        replaceSignature(workflow, first),
        second,
      );

      expect(twice.signature, same(second));
      expect(hasSameDesign(twice, workflow), isTrue);
    }
  });

  test('test_describe_fake_workflow_document_property_names_it', () {
    final Random random = seededRandom(67708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final String document = describeFakeWorkflowDocument(workflow);

      expect(document, startsWith('name: ${workflow.name}'));
      expect(document, endsWith('\n'));
    }
  });

  test('test_describe_fake_workflow_document_property_follows_name', () {
    final Random random = seededRandom(67709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);
      final Workflow renamed = workflow.withName('renamed-$i');

      expect(
        describeFakeWorkflowDocument(renamed),
        isNot(describeFakeWorkflowDocument(workflow)),
      );
    }
  });

  test('test_describe_fake_workflow_document_property_ignores_steps', () {
    final Random random = seededRandom(67710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random, i);

      expect(
        describeFakeWorkflowDocument(addBlankStep(workflow)),
        describeFakeWorkflowDocument(workflow),
      );
    }
  });

  test('test_collect_signed_versions_property_only_signed_ones', () {
    final Random random = seededRandom(67711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);

      final Map<WorkflowId, Workflow> collected = collectSignedVersions(
        workflows,
      );

      for (final Workflow workflow in workflows) {
        final Workflow? found = collected[workflow.id];
        expect(found, workflow.signature == null ? isNull : same(workflow));
      }
    }
  });

  test('test_collect_signed_versions_property_size_counts_signed', () {
    final Random random = seededRandom(67712);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);
      final int signedCount = workflows
          .where((Workflow workflow) => workflow.signature != null)
          .length;

      expect(collectSignedVersions(workflows), hasLength(signedCount));
    }
  });

  test('test_collect_signed_versions_property_is_a_fresh_copy', () {
    final Random random = seededRandom(67713);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);
      final Map<WorkflowId, Workflow> first = collectSignedVersions(workflows);
      final int signedCount = first.length;
      first.clear();

      final Map<WorkflowId, Workflow> second = collectSignedVersions(
        workflows,
      );
      expect(second, hasLength(signedCount));
      expect(workflows, hasLength(greaterThanOrEqualTo(signedCount)));
    }
  });

  test('test_describe_unsigned_edit_property_names_who_and_when', () {
    final Random random = seededRandom(67714);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow edited = _randomWorkflow(random, i);
      final DateTime changedAt = randomUtcMoment(random);

      final WorkflowChange change = describeUnsignedEdit(
        edited: edited,
        signature: buildSampleSignature(),
        changedBy: GalleryDeviceIds.pixelPhone,
        changedAt: changedAt,
      );

      expect(change.workflowId, edited.id);
      expect(change.changedBy, GalleryDeviceIds.pixelPhone);
      expect(change.changedAt, changedAt);
      expect(change.summary, isNotEmpty);
    }
  });

  test('test_describe_unsigned_edit_property_documents_both_sides', () {
    final Random random = seededRandom(67715);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow edited = _randomWorkflow(random, i);
      final WorkflowSignature signature = buildSampleSignature();

      final WorkflowChange change = describeUnsignedEdit(
        edited: edited,
        signature: signature,
        changedBy: GalleryDeviceIds.airLaptop,
        changedAt: randomUtcMoment(random),
      );

      expect(change.signedDocument, signature.signedDocument);
      expect(change.changedDocument, describeFakeWorkflowDocument(edited));
    }
  });

  test('test_describe_unsigned_edit_property_differences_frozen', () {
    final Random random = seededRandom(67716);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowChange change = describeUnsignedEdit(
        edited: _randomWorkflow(random, i),
        signature: buildSampleSignature(),
        changedBy: GalleryDeviceIds.airLaptop,
        changedAt: randomUtcMoment(random),
      );

      expect(
        () => change.differences.add(
          const WorkflowDifference(subject: 'x', change: 'y'),
        ),
        throwsUnsupportedError,
      );
    }
  });
}
