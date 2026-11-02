import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflow_agents.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

void main() {
  test(
    'test_build_gallery_dependencies_property_every_reference_resolves',
    () {
      final AppDependencies dependencies = buildGalleryDependencies();

      for (final Task task in dependencies.taskRepository.listTasks()) {
        dependencies.projectRepository.findProject(task.projectId);
        for (final Run run in dependencies.taskRepository.listRuns(task.id)) {
          expect(run.taskId, task.id);
          for (final RunStep step in run.steps) {
            final DeviceId? runner = step.runner;
            if (runner != null) {
              dependencies.deviceRepository.findDevice(runner);
            }
          }
        }
      }
      for (final ApprovalRequest request
          in dependencies.approvalRepository.listApprovals()) {
        dependencies.deviceRepository.findDevice(request.requestedBy);
        final RunId? runId = request.runId;
        if (runId != null) {
          dependencies.taskRepository.findRun(runId);
        }
      }
      for (final Task job in dependencies.jobRepository.listJobs()) {
        dependencies.projectRepository.findProject(job.projectId);
        expect(job.schedule, isNotNull);
      }
    },
  );

  test('test_gallery_today_property_keeps_the_gallery_date', () {
    final Random random = seededRandom(7101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int hour = random.nextInt(24);
      final int minute = random.nextInt(60);
      final DateTime today = galleryToday(hour, minute);

      expect(today.day, galleryNow.day);
      expect(<int>[today.hour, today.minute], <int>[hour, minute]);
    }
  });

  test('test_gallery_yesterday_property_one_calendar_day_earlier', () {
    final Random random = seededRandom(7102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime yesterday = galleryYesterday(
        random.nextInt(24),
        random.nextInt(60),
      );
      final DateTime galleryDate = DateTime(
        galleryNow.year,
        galleryNow.month,
        galleryNow.day,
      );

      expect(galleryDate.difference(yesterday).inHours < 24, isTrue);
      expect(yesterday.isBefore(galleryDate), isTrue);
    }
  });

  test('test_gallery_days_ago_property_exact_day_offsets', () {
    final Random random = seededRandom(7103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int days = random.nextInt(400);
      expect(galleryNow.difference(galleryDaysAgo(days)).inDays, days);
    }
  });

  test('test_build_gallery_agent_property_ids_follow_the_names', () {
    final Random random = seededRandom(7104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = 'step-${random.nextInt(100)}';
      final WorkflowAgent agent = buildGalleryAgent(
        workflowName: 'flow',
        name: name,
        kind: pickOne(random, AgentKind.values),
        runsOn: randomRunnerTarget(random),
        position: stackedPosition(random.nextInt(5)),
      );

      expect(agent.id, WorkflowAgentId('agent-flow-$name'));
      expect(agent.task, contains(name));
    }
  });

  test('test_stacked_position_property_rows_grow_downward', () {
    final Random random = seededRandom(7105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int row = random.nextInt(20);
      expect(
        stackedPosition(row + 1).vertical > stackedPosition(row).vertical,
        isTrue,
      );
      expect(stackedPosition(row).horizontal, stackedPosition(0).horizontal);
    }
  });

  test('test_connect_in_order_property_one_link_between_neighbours', () {
    final Random random = seededRandom(7106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = <WorkflowAgent>[
        for (int index = 0; index < random.nextInt(6); index += 1)
          buildGalleryAgent(
            workflowName: 'flow',
            name: 'step-$index',
            kind: AgentKind.codex,
            runsOn: randomRunnerTarget(random),
            position: stackedPosition(index),
          ),
      ];
      final List<AgentConnection> links = connectInOrder(agents);

      expect(links.length, agents.isEmpty ? 0 : agents.length - 1);
      for (int index = 0; index < links.length; index += 1) {
        expect(links[index].from, agents[index].id);
        expect(links[index].to, agents[index + 1].id);
      }
    }
  });

  test('test_connect_feature_pipeline_property_review_joins_both_paths', () {
    final List<AgentConnection> links = connectFeaturePipeline();
    final WorkflowAgentId review = featurePipelineAgents[3].id;

    expect(links.where((AgentConnection link) => link.to == review).length, 2);
    expect(links.length, 5);
  });
}
