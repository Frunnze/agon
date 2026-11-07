import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import 'support/gallery_records.dart';

final RegExp _documentStepPattern = RegExp(
  r'^  - name: (.+)$',
  multiLine: true,
);

List<String> _listDocumentSteps(String document) {
  return <String>[
    for (final RegExpMatch match in _documentStepPattern.allMatches(document))
      match.group(1)!,
  ];
}

List<String> _listOrderedNames(Workflow workflow) {
  return <String>[
    for (final WorkflowAgent agent in orderAgents(workflow)) agent.name,
  ];
}

void _expectSignedByAClient({
  required DeviceId deviceId,
  required DateTime at,
}) {
  final Device device = findGalleryDevice(deviceId);

  expect(device.role, isNot(DeviceRole.runner));
  expect(device.pairedAt.isAfter(at), isFalse);
  expect(at.isAfter(galleryNow), isFalse);
}

void main() {
  test('test_gallery_workflows_property_names_and_ids_are_unique', () {
    final List<String> names = <String>[
      for (final Workflow workflow in galleryWorkflows) workflow.name,
    ];
    final List<WorkflowId> identifiers = <WorkflowId>[
      for (final Workflow workflow in galleryWorkflows) workflow.id,
    ];

    for (final String name in names) {
      expect(describeNameProblem(name), isNull, reason: name);
    }
    expect(hasNoRepeats(names), isTrue);
    expect(hasNoRepeats(identifiers), isTrue);
  });

  test('test_gallery_workflows_property_pass_the_workflow_rules', () {
    final List<WorkflowAgentId> agentIds = <WorkflowAgentId>[
      for (final Workflow workflow in galleryWorkflows)
        for (final WorkflowAgent agent in workflow.agents) agent.id,
    ];

    for (final Workflow workflow in galleryWorkflows) {
      final List<String> stepNames = <String>[
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      ];

      expect(describeWorkflowProblem(workflow), isNull, reason: workflow.name);
      expect(hasNoRepeats(stepNames), isTrue, reason: workflow.name);
      expect(workflow.agents, isNotEmpty);
    }
    expect(hasNoRepeats(agentIds), isTrue);
  });

  test('test_gallery_workflows_property_signed_by_a_client_for_this_'
      'design', () {
    for (final Workflow workflow in galleryWorkflows) {
      final WorkflowSignature? signature = workflow.signature;
      if (signature == null) {
        continue;
      }
      final List<String> signedSteps = _listDocumentSteps(
        signature.signedDocument,
      );

      _expectSignedByAClient(
        deviceId: signature.signedBy,
        at: signature.signedAt!,
      );
      expect(signature.signedDocument, startsWith('name: ${workflow.name}\n'));
      if (signedSteps.isNotEmpty) {
        expect(signedSteps, _listOrderedNames(workflow));
      }
    }
  });

  test('test_gallery_workflows_property_release_uses_the_release_agents', () {
    final Workflow release = findGalleryWorkflow(GalleryWorkflowIds.release);

    expect(release.agents, releaseAgents);
    expect(_listDocumentSteps(releaseDocument), _listOrderedNames(release));
    expect(
      () => releaseAgents.add(releaseAgents.first),
      throwsUnsupportedError,
    );
  });

  test('test_gallery_workflow_changes_property_start_from_the_signed_'
      'document', () {
    for (final WorkflowChange change in galleryWorkflowChanges) {
      final Workflow workflow = findGalleryWorkflow(change.workflowId);
      final WorkflowSignature? signature = workflow.signature;

      expect(signature, isNotNull, reason: workflow.name);
      expect(change.signedDocument, signature!.signedDocument);
      expect(change.changedDocument, isNot(change.signedDocument));
      expect(change.changedAt!.isAfter(signature.signedAt!), isTrue);
    }
  });

  test('test_gallery_workflow_changes_property_describe_the_change', () {
    for (final WorkflowChange change in galleryWorkflowChanges) {
      final Workflow workflow = findGalleryWorkflow(change.workflowId);

      _expectSignedByAClient(
        deviceId: change.changedBy!,
        at: change.changedAt!,
      );
      expect(change.summary.trim(), isNotEmpty);
      expect(change.differences, isNotEmpty);
      expect(change.changedDocument, startsWith('name: ${workflow.name}\n'));
    }
  });

  test('test_gallery_workflow_changes_property_keep_the_step_names', () {
    for (final WorkflowChange change in galleryWorkflowChanges) {
      final Workflow workflow = findGalleryWorkflow(change.workflowId);

      expect(
        _listDocumentSteps(change.changedDocument),
        _listOrderedNames(workflow),
      );
    }
  });
}
