import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';

const String _typePrefix = 'test_build_gallery_dependencies';
const int _galleryIterations = 12;

List<Task> _listWork(AppDependencies dependencies) {
  return <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
}

bool _isRunning(AppDependencies dependencies, TaskId taskId) {
  return dependencies.taskRepository.listRuns(taskId).any(isRunActive);
}

Set<RunId> _runIdsOf(AppDependencies dependencies, TaskId taskId) {
  return <RunId>{
    for (final Run run in dependencies.taskRepository.listRuns(taskId)) run.id,
  };
}

List<ProjectId> _scopedProjects(Scope scope) {
  final ProjectScope projects = scope.projects;
  if (projects is OnlyProjects) {
    return projects.projects;
  }
  return const <ProjectId>[];
}

bool _isAvailableIn(Workflow workflow, WorkspaceId workspaceId) {
  final WorkspaceScope availability = workflow.availability;
  return availability is AllWorkspaces ||
      (availability is OnlyWorkspaces &&
          availability.workspaces.contains(workspaceId));
}

void main() {
  test('${_typePrefix}_property_a_deleted_skill_leaves_every_gallery_'
      'task', () async {
    final Random random = seededRandom(92801);

    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Skill doomed = pickOne(
        random,
        dependencies.skillRepository.listSkills(),
      );

      await dependencies.skillRepository.deleteSkill(doomed.id);

      for (final Task task in _listWork(dependencies)) {
        expect(task.skills, isNot(contains(doomed.id)));
      }
    }
  });

  test('${_typePrefix}_property_a_deleted_task_takes_the_approvals_of_its_'
      'runs', () async {
    final Random random = seededRandom(92802);

    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Task> idle = <Task>[
        for (final Task task in dependencies.taskRepository.listTasks())
          if (!_isRunning(dependencies, task.id)) task,
      ];
      final Task doomed = pickOne(random, idle);
      final Set<RunId> removedRunIds = _runIdsOf(dependencies, doomed.id);
      final List<ApprovalRequest> before = dependencies.approvalRepository
          .listApprovals();

      await dependencies.taskRepository.deleteTask(doomed.id);

      expect(
        dependencies.approvalRepository.listApprovals(),
        <ApprovalRequest>[
          for (final ApprovalRequest approval in before)
            if (!removedRunIds.contains(approval.runId)) approval,
        ],
      );
    }
  });

  test('${_typePrefix}_property_a_deleted_project_leaves_no_library_'
      'scope', () async {
    for (final Project project in galleryProjects) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final bool isRunning = _listWork(dependencies).any(
        (Task task) =>
            task.projectId == project.id && _isRunning(dependencies, task.id),
      );
      if (isRunning) {
        continue;
      }

      await dependencies.projectRepository.deleteProject(project.id);

      for (final Skill skill in dependencies.skillRepository.listSkills()) {
        expect(_scopedProjects(skill.scope), isNot(contains(project.id)));
      }
      for (final Rule rule in dependencies.ruleRepository.listRules()) {
        expect(_scopedProjects(rule.scope), isNot(contains(project.id)));
      }
    }
  });

  test('${_typePrefix}_property_a_created_workspace_belongs_to_this_'
      'device', () async {
    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();

      final Workspace created = await dependencies.workspaceRepository
          .createWorkspace(name: 'made-$i');

      final Device current = dependencies.deviceRepository.currentDevice();
      expect(current.workspaces, contains(created.id));
      expect(current.id, GalleryDeviceIds.airLaptop);
    }
  });

  test('${_typePrefix}_property_workflows_follow_the_current_'
      'workspace', () async {
    for (final Workspace workspace in galleryWorkspaces) {
      final AppDependencies dependencies = buildGalleryDependencies();

      await dependencies.workspaceRepository.switchWorkspace(workspace.id);

      expect(dependencies.workflowRepository.listWorkflows(), <Workflow>[
        for (final Workflow workflow in galleryWorkflows)
          if (_isAvailableIn(workflow, workspace.id)) workflow,
      ]);
    }
  });
}
