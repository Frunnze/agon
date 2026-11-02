import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/random_inputs.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

void main() {
  test('test_find_step_target_property_agent_target_or_task_target', () {
    final Random random = seededRandom(6010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final RunStep step = pickOne(random, run.steps);
      final Task task = pickOne(random, galleryTasks);
      final Workflow? workflow = step.agentId == null
          ? null
          : galleryWorkflows.first;
      final RunnerTarget target = findStepTarget(
        step: step,
        task: task,
        workflow: workflow,
      );

      if (workflow == null) {
        expect(target, task.runsOn);
      } else {
        expect(target, workflow.findAgent(step.agentId!).runsOn);
      }
    }
  });

  test('test_status_label_builders_property_failures_are_danger', () {
    for (final TaskStatus status in TaskStatus.values) {
      final StatusLabel task = buildTaskStatusLabel(status);
      final StatusLabel job = buildJobLastRunLabel(status);
      expect(task.tone == StatusTone.danger, status == TaskStatus.failed);
      expect(job.tone == StatusTone.danger, status == TaskStatus.failed);
    }
    for (final StepStatus status in StepStatus.values) {
      final StatusLabel step = buildStepStatusLabel(status);
      expect(step.tone == StatusTone.danger, status == StepStatus.failed);
    }
  });

  test('test_build_runner_link_route_property_only_unreachable_breaks', () {
    for (final RunnerLink link in RunnerLink.values) {
      final RouteLine route = buildRunnerLinkRoute(
        startName: 'air-laptop',
        endName: 'mac-studio',
        link: link,
      );
      expect(route.path == RoutePath.broken, link == RunnerLink.unreachable);
      expect(route.path == RoutePath.relay, link == RunnerLink.relay);
    }
  });

  test('test_build_pairing_link_route_property_unknown_link_claims_none', () {
    final RouteLine unknown = buildPairingLinkRoute(
      startName: 'mac-mini',
      endName: 'air-laptop',
      link: null,
    );
    expect(unknown.badgeLabel, unknownLinkBadgeLabel);
    expect(unknown.path, isNot(RoutePath.broken));

    for (final RunnerLink link in RunnerLink.values) {
      final RouteLine known = buildPairingLinkRoute(
        startName: 'mac-mini',
        endName: 'air-laptop',
        link: link,
      );
      final RouteLine expected = buildRunnerLinkRoute(
        startName: 'mac-mini',
        endName: 'air-laptop',
        link: link,
      );
      expect(known.badgeLabel, expected.badgeLabel);
      expect(known.path, expected.path);
    }
  });

  test('test_chat_run_context_property_describes_the_current_step', () {
    final Random random = seededRandom(6013);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final Task task = <Task>[...galleryTasks]
          .firstWhere((Task candidate) => candidate.id == run.taskId);
      final ChatRunContext context = ChatRunContext(
        run: run,
        task: task,
        workflow: task.doer is WorkflowDoer ? galleryWorkflows.first : null,
        deviceNames: _deviceNames,
      );

      expect(
        context.agentSummary,
        endsWith('step ${context.currentStep.name}'),
      );
      expect(context.runLabel, endsWith('#${run.number}'));
      expect(context.agentTitle, contains(context.runnerName));
    }
    expect(galleryRunChat.length, greaterThan(3));
  });
}
