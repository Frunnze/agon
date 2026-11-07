import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const int _largestOverflow = 3;

const List<DeviceId> _drafterDevices = <DeviceId>[
  GalleryDeviceIds.officeServer,
  GalleryDeviceIds.macStudio,
];

int _randomAddedCount(Random random, Workflow drafted) {
  return random.nextInt(drafted.agents.length + 1);
}

WorkflowDraftProgress _randomProgress(Random random, Workflow drafted) {
  return buildDraftProgress(
    drafted: drafted,
    addedAgentCount: _randomAddedCount(random, drafted),
    drafterDeviceId: pickOne(random, _drafterDevices),
  );
}

void main() {
  test('test_build_drafted_workflow_property_keeps_the_template_graph', () {
    final Random random = seededRandom(68501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow template = randomBranchingWorkflow(random);
      final Workflow drafted = buildDraftedWorkflow(
        template: template,
        chosenName: 'drafted-$i',
        workflowId: WorkflowId('drafted-$i'),
      );

      expect(drafted.agents, template.agents);
      expect(drafted.connections, template.connections);
      expect(drafted.availability, same(template.availability));
    }
  });

  test('test_build_drafted_workflow_property_is_never_signed', () {
    for (final Workflow template in galleryWorkflows) {
      final Workflow drafted = buildDraftedWorkflow(
        template: template,
        chosenName: '${template.name}-copy',
        workflowId: WorkflowId('${template.id.value}-copy'),
      );

      expect(drafted.signature, isNull, reason: template.name);
    }
  });

  test('test_build_drafted_workflow_property_takes_the_chosen_id_and_'
      'name', () {
    final Random random = seededRandom(68502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String chosenName = randomText(random);
      final WorkflowId workflowId = WorkflowId(randomText(random));
      final Workflow drafted = buildDraftedWorkflow(
        template: randomBranchingWorkflow(random),
        chosenName: chosenName,
        workflowId: workflowId,
      );

      expect(drafted.name, chosenName);
      expect(drafted.id, workflowId);
    }
  });

  test('test_build_draft_progress_property_adds_agents_in_drafted_'
      'order', () {
    final Random random = seededRandom(68503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow drafted = randomBranchingWorkflow(random);
      final int added = _randomAddedCount(random, drafted);
      final WorkflowDraftProgress progress = buildDraftProgress(
        drafted: drafted,
        addedAgentCount: added,
        drafterDeviceId: GalleryDeviceIds.officeServer,
      );
      final List<WorkflowAgent> rest = drafted.agents.sublist(added);

      expect(progress.workflow.agents, drafted.agents.sublist(0, added));
      expect(progress.pendingAgents.length, rest.length);
      for (int index = 0; index < rest.length; index += 1) {
        expect(progress.pendingAgents[index].name, rest[index].name);
        expect(progress.pendingAgents[index].position, rest[index].position);
      }
    }
  });

  test('test_build_draft_progress_property_keeps_connections_between_'
      'added_agents', () {
    final Random random = seededRandom(68504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow drafted = randomBranchingWorkflow(random);
      final WorkflowDraftProgress progress = _randomProgress(random, drafted);
      final Set<WorkflowAgentId> addedIds = <WorkflowAgentId>{
        for (final WorkflowAgent agent in progress.workflow.agents) agent.id,
      };
      final List<AgentConnection> expected = <AgentConnection>[
        for (final AgentConnection connection in drafted.connections)
          if (addedIds.contains(connection.from) &&
              addedIds.contains(connection.to))
            connection,
      ];

      expect(progress.workflow.connections, expected);
    }
  });

  test('test_build_draft_progress_property_names_the_fake_drafter', () {
    final Random random = seededRandom(68505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow drafted = randomBranchingWorkflow(random);
      final int added = _randomAddedCount(random, drafted);
      final DeviceId drafter = pickOne(random, _drafterDevices);
      final WorkflowDraftProgress progress = buildDraftProgress(
        drafted: drafted,
        addedAgentCount: added,
        drafterDeviceId: drafter,
      );

      expect(progress.drafterKind, fakeDrafterKind);
      expect(progress.drafterDeviceId, drafter);
      expect(progress.isFinished, added == drafted.agents.length);
      expect(progress.workflow.id, drafted.id);
    }
  });

  test('test_build_draft_progress_property_refuses_counts_outside_the_'
      'draft', () {
    final Random random = seededRandom(68506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow drafted = randomBranchingWorkflow(random);
      final int outside = random.nextBool()
          ? -1 - random.nextInt(drafted.agents.length + 1)
          : drafted.agents.length + 1 + random.nextInt(_largestOverflow);

      expect(
        () => buildDraftProgress(
          drafted: drafted,
          addedAgentCount: outside,
          drafterDeviceId: GalleryDeviceIds.officeServer,
        ),
        throwsRangeError,
      );
    }
  });
}
