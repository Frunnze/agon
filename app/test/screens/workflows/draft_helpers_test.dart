import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);
final Workflow _pipeline = galleryWorkflows[2];

void main() {
  test('test_join_names_in_prose_property_every_name_once', () {
    final Random random = seededRandom(9204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(5);
      final List<String> names = <String>[
        for (int index = 0; index < count; index += 1) 'agent$index',
      ];
      final String prose = joinNamesInProse(names);

      for (final String name in names) {
        expect(prose, contains(name));
      }
      expect(prose.contains(' and '), names.length > 1);
    }
    expect(joinNamesInProse(<String>['review', 'ship']), 'review and ship');
  });

  test('test_describe_draft_progress_property_one_line_per_agent', () {
    for (int added = 0; added <= _pipeline.agents.length; added += 1) {
      final WorkflowDraftProgress progress = buildDraftProgress(
        drafted: _pipeline,
        addedAgentCount: added,
        drafterDeviceId: GalleryDeviceIds.officeServer,
      );
      final List<DraftProgressLine> lines = describeDraftProgress(
        progress: progress,
        deviceNames: _deviceNames,
        skills: gallerySkills,
      );
      final int pendingLines = progress.isFinished ? 0 : 1;

      expect(lines.length, 1 + added + pendingLines);
      expect(lines.last.isDone, progress.isFinished);
    }
    expect(
      describeDraftProgress(
        progress: null,
        deviceNames: _deviceNames,
        skills: gallerySkills,
      ).single.isDone,
      isFalse,
    );
  });

  test('test_describe_added_agent_property_names_agent_and_runner', () {
    for (final WorkflowAgent agent in _pipeline.agents) {
      final String line = describeAddedAgent(
        agent: agent,
        deviceNames: _deviceNames,
        skills: gallerySkills,
      );

      expect(line, startsWith('Added ${agent.name}, '));
      expect(line.contains(' with '), agent.skills.isNotEmpty);
    }
  });

  test('test_describe_drafter_property_names_kind_and_device', () {
    final WorkflowDraftProgress progress = buildDraftProgress(
      drafted: _pipeline,
      addedAgentCount: 0,
      drafterDeviceId: GalleryDeviceIds.officeServer,
    );

    expect(
      describeDrafter(progress: progress, deviceNames: _deviceNames),
      'Claude Code is drafting on office-server',
    );
    expect(
      describeDrafter(progress: null, deviceNames: _deviceNames),
      'Starting the draft',
    );
  });

  test('test_append_requested_agent_property_new_agent_feeds_nothing', () {
    final Random random = seededRandom(9208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final Workflow changed = appendRequestedAgent(workflow, 'do it');
      final WorkflowAgent added = changed.agents.last;

      expect(
        changed.connections.every(
          (AgentConnection connection) => connection.from != added.id,
        ),
        isTrue,
      );
      expect(fillInAgent(added, workflow.name).task, 'do it');
    }
  });
}
