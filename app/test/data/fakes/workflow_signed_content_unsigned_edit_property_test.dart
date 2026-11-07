import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/workflow_signed_content.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';
import 'support/workflow_signing_inputs.dart';

const int _largestOtherChangeCount = 4;
const int _largestShift = 500;

List<WorkflowChange> _randomOtherChanges(Random random) {
  final int count = random.nextInt(_largestOtherChangeCount + 1);
  final List<WorkflowChange> changes = <WorkflowChange>[];
  for (int index = 0; index < count; index += 1) {
    changes.add(buildSampleChange(WorkflowId('other-workflow-$index')));
  }
  return changes;
}

Workflow _shiftDiagram(Random random, Workflow workflow) {
  final double horizontalShift = random.nextInt(_largestShift).toDouble();
  final double verticalShift = random.nextInt(_largestShift).toDouble();
  final List<WorkflowAgent> shifted = <WorkflowAgent>[];
  for (final WorkflowAgent agent in workflow.agents) {
    final CanvasPosition position = CanvasPosition(
      horizontal: agent.position.horizontal + horizontalShift,
      vertical: agent.position.vertical + verticalShift,
    );
    shifted.add(agent.copyWith(position: position));
  }
  return workflow.withGraph(
    agents: shifted,
    connections: workflow.connections,
  );
}

Workflow _withAvailability(Workflow workflow, WorkspaceScope availability) {
  return Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

void main() {
  test('test_record_unsigned_edit_property_unsigned_returns_the_same_'
      'list', () {
    final Random random = seededRandom(95185);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final List<WorkflowChange> changes = _randomOtherChanges(random);

      final List<WorkflowChange> recorded = recordUnsignedEdit(
        changes: changes,
        stored: stored,
        edited: addBlankStep(stored).withName('renamed-$i'),
        changedBy: DeviceId(randomText(random)),
        changedAt: randomUtcMoment(random),
      );

      expect(recorded, same(changes));
    }
  });

  test('test_record_unsigned_edit_property_pending_change_returns_the_'
      'same_list', () {
    final Random random = seededRandom(95186);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = randomSignedWorkflow(random, i);
      final List<WorkflowChange> others = _randomOtherChanges(random);
      final List<WorkflowChange> changes = <WorkflowChange>[
        ...others.sublist(0, random.nextInt(others.length + 1)),
        randomChangeFor(random, stored.id),
      ];

      final List<WorkflowChange> recorded = recordUnsignedEdit(
        changes: changes,
        stored: stored,
        edited: addBlankStep(stored).withName('renamed-$i'),
        changedBy: DeviceId(randomText(random)),
        changedAt: randomUtcMoment(random),
      );

      expect(recorded, same(changes));
    }
  });

  test('test_record_unsigned_edit_property_real_edit_appends_one_'
      'change', () {
    final Random random = seededRandom(95187);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = randomSignedWorkflow(random, i);
      final Workflow edited = random.nextBool()
          ? addBlankStep(stored)
          : stored.withName('renamed-$i');
      final List<WorkflowChange> changes = _randomOtherChanges(random);
      final DeviceId editor = DeviceId(randomText(random));
      final DateTime moment = randomUtcMoment(random);

      final List<WorkflowChange> recorded = recordUnsignedEdit(
        changes: changes,
        stored: stored,
        edited: edited,
        changedBy: editor,
        changedAt: moment,
      );

      expect(recorded.sublist(0, changes.length), orderedEquals(changes));
      expect(recorded.length, changes.length + 1);
      final WorkflowChange added = recorded.last;
      expect(added.workflowId, stored.id);
      expect(added.changedBy, editor);
      expect(added.changedAt, moment);
      expect(added.signedDocument, stored.signature?.signedDocument);
      expect(added.changedDocument, describeFakeWorkflowDocument(edited));
    }
  });

  test('test_record_unsigned_edit_property_availability_edit_appends_'
      'a_change', () {
    final Random random = seededRandom(95190);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = _withAvailability(
        randomSignedWorkflow(random, i),
        const AllWorkspaces(),
      );
      final WorkspaceScope narrowed = OnlyWorkspaces(<WorkspaceId>[
        WorkspaceId('workspace-${randomText(random)}'),
      ]);
      final List<WorkflowChange> changes = _randomOtherChanges(random);

      final List<WorkflowChange> recorded = recordUnsignedEdit(
        changes: changes,
        stored: stored,
        edited: _withAvailability(stored, narrowed),
        changedBy: DeviceId(randomText(random)),
        changedAt: randomUtcMoment(random),
      );

      expect(recorded.length, changes.length + 1);
      expect(recorded.last.workflowId, stored.id);
    }
  });

  test('test_record_unsigned_edit_property_shifted_diagram_records_'
      'nothing', () {
    final Random random = seededRandom(95188);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = randomSignedWorkflow(random, i);
      final List<WorkflowChange> changes = _randomOtherChanges(random);

      final List<WorkflowChange> recorded = recordUnsignedEdit(
        changes: changes,
        stored: stored,
        edited: _shiftDiagram(random, stored),
        changedBy: DeviceId(randomText(random)),
        changedAt: randomUtcMoment(random),
      );

      expect(recorded, same(changes));
    }
  });

  test('test_record_unsigned_edit_property_never_mutates_the_given_'
      'list', () {
    final Random random = seededRandom(95189);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow stored = randomMaybeSignedWorkflow(random, i);
      final List<WorkflowChange> changes = _randomOtherChanges(random);
      final List<WorkflowChange> before = List<WorkflowChange>.of(changes);

      final List<WorkflowChange> recorded = recordUnsignedEdit(
        changes: changes,
        stored: stored,
        edited: addBlankStep(stored),
        changedBy: DeviceId(randomText(random)),
        changedAt: randomUtcMoment(random),
      );

      expect(changes, orderedEquals(before));
      if (!identical(recorded, changes)) {
        expect(recorded.clear, throwsUnsupportedError);
      }
    }
  });
}
