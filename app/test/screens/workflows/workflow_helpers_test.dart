import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);
final Workflow _pipeline = galleryWorkflows[2];

List<Run> _listGalleryRuns(TaskId taskId) {
  return <Run>[
    for (final Run run in galleryRuns)
      if (run.taskId == taskId) run,
  ];
}

void main() {
  test('test_describe_agent_node_property_unconnected_agents_say_so', () {
    final Random random = seededRandom(9205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      for (final WorkflowAgent agent in workflow.agents) {
        final DiagramNode node = describeAgentNode(
          agent: agent,
          workflow: workflow,
          deviceNames: _deviceNames,
          look: NodeLook.normal,
        );

        expect(node.name, agent.name);
        expect(node.position, same(agent.position));
        expect(
          node.targetText == unconnectedTargetText,
          isAgentUnconnected(workflow, agent.id),
        );
      }
    }
  });

  test('test_describe_pending_node_property_pending_look_no_target', () {
    final Random random = seededRandom(9206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PendingAgent pending = PendingAgent(
        name: randomWordPhrase(random),
        position: randomCanvasPosition(random),
      );
      final DiagramNode node = describePendingNode(pending);

      expect(node.look, NodeLook.pending);
      expect(node.targetText, isNull);
      expect(node.kindText, pendingKindText);
      expect(node.name, pending.name);
    }
  });

  test('test_find_last_workflow_use_property_latest_run_start', () {
    for (final WorkflowId workflowId in <WorkflowId>[
      GalleryWorkflowIds.release,
      GalleryWorkflowIds.featurePipeline,
    ]) {
      final DateTime? lastUse = findLastWorkflowUse(
        workflowId: workflowId,
        tasks: galleryTasks,
        listRuns: _listGalleryRuns,
      );

      if (workflowId == GalleryWorkflowIds.featurePipeline) {
        expect(lastUse, isNull);
      } else {
        expect(describeLastUse(lastUse, galleryNow), '4 min ago');
      }
    }
  });

  test('test_describe_step_runs_on_property_specific_runners_say_runs_on', () {
    final Random random = seededRandom(9207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = pickOne(random, <RunnerTarget>[
        const AnyFreeRunner(),
        const SpecificRunner(GalleryDeviceIds.officeServer),
        RunnerWithLabels(const <String>['gpu']),
      ]);
      final List<TextSegment> segments = describeStepRunsOn(
        target,
        _deviceNames,
      );

      expect(segments.first.text == 'Runs on ', target is SpecificRunner);
    }
  });

  test('test_describe_change_summary_property_names_device_and_age', () {
    expect(
      describeChangeSummary(
        change: galleryWorkflowChanges.first,
        deviceNames: _deviceNames,
        now: galleryNow,
      ),
      'Changed 1 h ago on air-laptop',
    );
    expect(
      describeKeptVersion(galleryWorkflows[3].signature, galleryNow),
      'Until then, runners keep using the version signed 2 days ago.',
    );
    expect(
      describeKeptVersion(null, galleryNow),
      'Until then, runners cannot run it.',
    );
  });

  test('test_find_workflow_route_property_every_state_has_a_page', () {
    for (final SignatureState state in SignatureState.values) {
      final AppRoute route = findWorkflowRoute(_pipeline.id, state);

      switch (state) {
        case SignatureState.signed:
          expect(route, isA<WorkflowDetailRoute>());
        case SignatureState.notSignedYet:
          expect(route, isA<WorkflowBuilderRoute>());
        case SignatureState.changedNotSigned:
          expect(route, isA<WorkflowChangeRoute>());
      }
      expect(route.section, AppSection.workflows);
    }
  });
}
