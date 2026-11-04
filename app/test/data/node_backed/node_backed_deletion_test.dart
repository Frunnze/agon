import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_catalog_node.dart';
import 'support/simulated_deletions.dart';
import 'support/simulated_work_node.dart';
import 'support/simulated_workflow_node.dart';
import 'support/workflow_repository_harness.dart';

const int _deletionIterations = 20;

NodeBackedWorkspaceRepository _openWorkspaces(SimulatedCatalogNode node) {
  return NodeBackedWorkspaceRepository(
    channel: node.channel,
    clock: FixedClock(DateTime.utc(2026, 11, 2)),
    retryInterval: const Duration(seconds: 30),
    choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
  );
}

typedef _WorkFixture = ({
  SimulatedWorkNode node,
  NodeBackedTaskRepository tasks,
  NodeBackedJobRepository jobs,
});

_WorkFixture _openWork() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final NodeCommandChannel channel = buildSimulatedChannel(simulated.answer);
  final NodeBackedJobRepository jobs = NodeBackedJobRepository(
    channel: channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
    clock: const SystemClock(),
  );
  final NodeBackedTaskRepository tasks = NodeBackedTaskRepository(
    channel: channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
    livePollInterval: Duration.zero,
    jobRepository: jobs,
  );
  return (node: simulated, tasks: tasks, jobs: jobs);
}

void main() {
  test('test_delete_project_property_leaves_the_other_projects', () async {
    final Random random = seededRandom(7201);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id']! as String,
    );
    final NodeBackedWorkspaceRepository workspaces = _openWorkspaces(
      simulated,
    );
    final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
      channel: simulated.channel,
      workspaceRepository: workspaces,
    );
    await workspaces.load();

    for (int i = 0; i < _deletionIterations; i += 1) {
      await projects.createProject(
        ProjectDraft(
          workspaceId: workspaceId,
          name: 'site-$i',
          repositories: const <Repository>[],
          approvalPolicy: null,
        ),
      );
      final List<Project> before = projects.listProjects(workspaceId);
      final Project doomed = pickOne(random, before);

      await projects.deleteProject(doomed.id);

      final List<Project> expected = <Project>[
        for (final Project project in before)
          if (project.id != doomed.id) project,
      ];
      expect(projects.listProjects(workspaceId), expected);
      expect(simulated.projects.length, expected.length);
    }
    projects.dispose();
    workspaces.dispose();
  });

  test('test_delete_workspace_property_switches_away_and_keeps_one', () async {
    final Random random = seededRandom(7202);

    for (int i = 0; i < _deletionIterations; i += 1) {
      final SimulatedCatalogNode simulated = SimulatedCatalogNode(
        hasAccount: true,
      );
      final int workspaceCount = 1 + random.nextInt(4);
      for (int index = 0; index < workspaceCount; index += 1) {
        simulated.addWorkspace('space-$index');
      }
      final NodeBackedWorkspaceRepository workspaces = _openWorkspaces(
        simulated,
      );
      await workspaces.load();

      while (workspaces.listWorkspaces().length > 1) {
        final Workspace current = workspaces.currentWorkspace();
        await workspaces.deleteWorkspace(current.id);
        expect(workspaces.currentWorkspace().id, isNot(current.id));
        expect(workspaces.listWorkspaces(), isNot(contains(current)));
      }

      await expectLater(
        workspaces.deleteWorkspace(workspaces.currentWorkspace().id),
        throwsA(
          isA<StateError>().having(
            (StateError problem) => problem.message,
            'message',
            simulatedLastWorkspaceRefusal,
          ),
        ),
      );
      expect(workspaces.listWorkspaces().length, 1);
      workspaces.dispose();
    }
  });

  test('test_delete_task_property_drops_tasks_and_jobs_alike', () async {
    final Random random = seededRandom(7203);
    final _WorkFixture fixture = _openWork();

    for (int i = 0; i < _deletionIterations; i += 1) {
      final String taskId = fixture.node.addTaskFromElsewhere(random);
      await fixture.tasks.load();
      await fixture.jobs.load();
      final bool isJob = fixture.node.tasks[taskId]!['schedule'] != null;

      if (isJob) {
        await fixture.jobs.deleteJob(TaskId(taskId));
      } else {
        await fixture.tasks.deleteTask(TaskId(taskId));
      }

      final List<String> listed = <String>[
        for (final Task task in fixture.tasks.listTasks()) task.id.value,
        for (final Task job in fixture.jobs.listJobs()) job.id.value,
      ];
      expect(listed, isNot(contains(taskId)));
      expect(fixture.node.tasks, isNot(contains(taskId)));
    }
    fixture.tasks.dispose();
    fixture.jobs.dispose();
  });

  test('test_delete_task_property_running_tasks_stay', () async {
    final Random random = seededRandom(7204);
    final _WorkFixture fixture = _openWork();

    for (int i = 0; i < _deletionIterations; i += 1) {
      final String taskId = fixture.node.addTaskFromElsewhere(random);
      final String runId = fixture.node.addRunFromElsewhere(random, taskId);
      fixture.node.runs[runId]!['status'] = 'running';
      await fixture.tasks.load();

      await expectLater(
        fixture.tasks.deleteTask(TaskId(taskId)),
        throwsA(
          isA<StateError>().having(
            (StateError problem) => problem.message,
            'message',
            simulatedRunningTaskRefusal,
          ),
        ),
      );
      expect(fixture.node.tasks, contains(taskId));
    }
    fixture.tasks.dispose();
    fixture.jobs.dispose();
  });

  test('test_delete_workflow_property_removes_only_that_workflow', () async {
    final Random random = seededRandom(7205);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);

    for (int i = 0; i < _deletionIterations; i += 1) {
      simulated.addWorkflow(name: 'flow-$i', state: signedState);
      await repository.load();
      final List<Workflow> before = repository.listWorkflows();
      final Workflow doomed = pickOne(random, before);

      await repository.deleteWorkflow(doomed.id);

      final List<WorkflowId> expected = <WorkflowId>[
        for (final Workflow workflow in before)
          if (workflow.id != doomed.id) workflow.id,
      ];
      final List<WorkflowId> remaining = <WorkflowId>[
        for (final Workflow workflow in repository.listWorkflows())
          workflow.id,
      ];
      expect(remaining, expected);
    }
    repository.dispose();
  });
}
