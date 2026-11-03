import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_find_run_label_property_known_runs_read_like_their_label', () {
    final Random random = seededRandom(9771);
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<Workflow> workflows = dependencies.workflowRepository
        .listWorkflows();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final Task task = dependencies.taskRepository.findTask(run.taskId);

      final String? label = findRunLabel(
        runId: run.id,
        taskRepository: dependencies.taskRepository,
        workflows: workflows,
      );

      expect(
        label,
        describeRunLabel(
          task: task,
          workflow: findWorkflowForDoer(task.doer, workflows),
          run: run,
        ),
      );
    }
  });

  test('test_find_run_label_property_unknown_runs_have_no_label', () {
    final Random random = seededRandom(9772);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? label = findRunLabel(
        runId: RunId('run-unknown-${random.nextInt(100000)}'),
        taskRepository: dependencies.taskRepository,
        workflows: dependencies.workflowRepository.listWorkflows(),
      );

      expect(label, isNull);
    }
  });
}
