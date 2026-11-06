import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';

import '../../support/random_inputs.dart';
import '../../support/task_repositories.dart';
import '../../support/workflow_repositories.dart';

const List<ProjectId> _projectIds = <ProjectId>[
  GalleryProjectIds.acmeApp,
  ProjectId('project-billing'),
  ProjectId('project-site'),
];

Workflow _pickWorkflow(Random random) {
  final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();
  return pickOne(random, repository.listWorkflows());
}

Workflow _renameWorkflow(Workflow workflow, String name) {
  return Workflow(
    id: workflow.id,
    name: name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

void main() {
  test('test_build_quick_start_task_property_title_names_the_workflow', () {
    final Random random = seededRandom(7601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = 'flow-${random.nextInt(1000)}';
      final Workflow workflow = _renameWorkflow(_pickWorkflow(random), name);

      final TaskDraft draft = buildQuickStartTask(
        workflow: workflow,
        projectId: pickOne(random, _projectIds),
      );

      expect(draft.title, '$quickStartTitleStart$name');
      expect(draft.details, isEmpty);
    }
  });

  test('test_build_quick_start_task_property_runs_this_workflow_there', () {
    final Random random = seededRandom(7602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _pickWorkflow(random);
      final ProjectId projectId = pickOne(random, _projectIds);

      final TaskDraft draft = buildQuickStartTask(
        workflow: workflow,
        projectId: projectId,
      );

      expect(draft.doer, WorkflowDoer(workflow.id));
      expect(draft.projectId, projectId);
    }
  });

  test('test_build_quick_start_task_property_uses_the_form_defaults', () {
    final Random random = seededRandom(7603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = buildQuickStartTask(
        workflow: _pickWorkflow(random),
        projectId: pickOne(random, _projectIds),
      );

      expect(draft.runsOn, const AnyFreeRunner());
      expect(draft.agentPlace, defaultAgentPlace);
      expect(draft.skills, isEmpty);
      expect(draft.usesAutomaticSkills, isTrue);
      expect(draft.approvalPolicy, isNull);
    }
  });

  test('test_start_workflow_now_property_starts_one_new_task', () async {
    final Random random = seededRandom(7604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeTaskRepository tasks = buildGalleryTaskRepository();
      final int taskCountBefore = tasks.listTasks().length;
      final Workflow workflow = _pickWorkflow(random);

      final RunId runId = await startWorkflowNow(
        taskRepository: tasks,
        workflow: workflow,
        projectId: GalleryProjectIds.acmeApp,
      );

      expect(tasks.listTasks().length, taskCountBefore + 1);
      final Run run = tasks.findRun(runId);
      final Task task = tasks.findTask(run.taskId);
      expect(task.doer, WorkflowDoer(workflow.id));
    }
  });

  test('test_start_workflow_now_property_the_run_is_listed', () async {
    final Random random = seededRandom(7605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeTaskRepository tasks = buildGalleryTaskRepository();

      final RunId runId = await startWorkflowNow(
        taskRepository: tasks,
        workflow: _pickWorkflow(random),
        projectId: GalleryProjectIds.acmeApp,
      );

      final Run run = tasks.findRun(runId);
      final List<RunId> listedRunIds = <RunId>[
        for (final Run listed in tasks.listRuns(run.taskId)) listed.id,
      ];
      expect(listedRunIds, contains(runId));
    }
  });

  test('test_start_workflow_now_property_each_start_is_its_own', () async {
    final Random random = seededRandom(7606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeTaskRepository tasks = buildGalleryTaskRepository();
      final Workflow workflow = _pickWorkflow(random);
      final int startCount = 2 + random.nextInt(3);
      final Set<TaskId> startedTaskIds = <TaskId>{};

      for (int j = 0; j < startCount; j += 1) {
        final RunId runId = await startWorkflowNow(
          taskRepository: tasks,
          workflow: workflow,
          projectId: GalleryProjectIds.acmeApp,
        );
        startedTaskIds.add(tasks.findRun(runId).taskId);
      }

      expect(startedTaskIds, hasLength(startCount));
    }
  });
}
