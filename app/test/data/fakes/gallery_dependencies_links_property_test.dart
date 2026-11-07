import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
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

const int _galleryIterations = 12;

List<Task> _listWork(AppDependencies dependencies) {
  return <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
}

bool _isUsed(AppDependencies dependencies, WorkflowId workflowId) {
  final WorkflowDoer usingDoer = WorkflowDoer(workflowId);
  return _listWork(dependencies).any((Task task) => task.doer == usingDoer);
}

bool _hasRunningWork(AppDependencies dependencies, ProjectId projectId) {
  for (final Task task in _listWork(dependencies)) {
    final List<Run> runs = dependencies.taskRepository.listRuns(task.id);
    if (task.projectId == projectId && runs.any(isRunActive)) {
      return true;
    }
  }
  return false;
}

bool _asksToSign(ApprovalRequest request, WorkflowId workflowId) {
  final ApprovalAction action = request.action;
  return action is SignWorkflowAction && action.workflowId == workflowId;
}

List<RuleId> _expectRulesIn(WorkspaceId workspaceId) {
  final List<RuleId> expected = <RuleId>[];
  for (final Rule rule in galleryRules) {
    final WorkspaceScope workspaces = rule.scope.workspaces;
    final bool isUsable =
        workspaces is AllWorkspaces ||
        (workspaces is OnlyWorkspaces &&
            workspaces.workspaces.contains(workspaceId));
    if (isUsable) {
      expected.add(rule.id);
    }
  }
  return expected;
}

List<RuleId> _listRuleIds(AppDependencies dependencies) {
  return <RuleId>[
    for (final Rule rule in dependencies.ruleRepository.listRules()) rule.id,
  ];
}

void main() {
  test('test_build_workflow_repository_property_used_gallery_workflows_'
      'cannot_be_deleted', () async {
    for (final Workflow workflow in galleryWorkflows) {
      final AppDependencies dependencies = buildGalleryDependencies();
      if (!_isUsed(dependencies, workflow.id)) {
        continue;
      }

      await expectLater(
        dependencies.workflowRepository.deleteWorkflow(workflow.id),
        throwsStateError,
      );
      expect(
        dependencies.workflowRepository.findWorkflow(workflow.id).id,
        workflow.id,
      );
    }
  });

  test('test_build_workflow_repository_property_deleting_drops_only_its_'
      'signing_requests', () async {
    for (final Workflow workflow in galleryWorkflows) {
      final AppDependencies dependencies = buildGalleryDependencies();
      if (_isUsed(dependencies, workflow.id)) {
        continue;
      }
      final List<ApprovalRequest> before = dependencies.approvalRepository
          .listApprovals();

      await dependencies.workflowRepository.deleteWorkflow(workflow.id);

      expect(
        dependencies.approvalRepository.listApprovals(),
        <ApprovalRequest>[
          for (final ApprovalRequest request in before)
            if (!_asksToSign(request, workflow.id)) request,
        ],
      );
    }
  });

  test('test_build_workflow_repository_property_lists_every_gallery_'
      'workflow', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    expect(
      <WorkflowId>[
        for (final Workflow workflow
            in dependencies.workflowRepository.listWorkflows())
          workflow.id,
      ],
      <WorkflowId>[
        for (final Workflow workflow in galleryWorkflows) workflow.id,
      ],
    );
  });

  test('test_build_approval_repository_property_lists_every_gallery_'
      'approval', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    expect(dependencies.approvalRepository.listApprovals(), <ApprovalRequest>[
      ...galleryApprovals,
      galleryDeniedPushApproval,
    ]);
  });

  test(
    'test_build_approval_repository_property_builds_are_isolated',
    () async {
      final AppDependencies first = buildGalleryDependencies();
      final AppDependencies second = buildGalleryDependencies();
      for (final Workflow workflow in galleryWorkflows) {
        if (!_isUsed(first, workflow.id)) {
          await first.workflowRepository.deleteWorkflow(workflow.id);
        }
      }

      expect(second.approvalRepository.listApprovals(), <ApprovalRequest>[
        ...galleryApprovals,
        galleryDeniedPushApproval,
      ]);
    },
  );

  test('test_build_workspace_repository_property_rules_follow_the_current_'
      'workspace', () async {
    final Random random = seededRandom(72501);
    final AppDependencies dependencies = buildGalleryDependencies();
    expect(
      dependencies.workspaceRepository.currentWorkspace().id,
      GalleryWorkspaceIds.acme,
    );

    for (int i = 0; i < _galleryIterations; i += 1) {
      final Workspace chosen = pickOne(random, galleryWorkspaces);
      await dependencies.workspaceRepository.switchWorkspace(chosen.id);

      expect(_listRuleIds(dependencies), _expectRulesIn(chosen.id));
    }
  });

  test('test_build_gallery_dependencies_property_running_projects_are_'
      'never_deleted', () async {
    for (final WorkspaceId workspaceId in <WorkspaceId>[
      for (final Workspace workspace in galleryWorkspaces) workspace.id,
    ]) {
      final AppDependencies probe = buildGalleryDependencies();
      for (final Project project in probe.projectRepository.listProjects(
        workspaceId,
      )) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final bool isRunning = _hasRunningWork(dependencies, project.id);
        final Future<void> deletion = dependencies.projectRepository
            .deleteProject(project.id);

        if (isRunning) {
          await expectLater(deletion, throwsStateError);
          expect(
            dependencies.projectRepository.findProject(project.id).id,
            project.id,
          );
        } else {
          await deletion;
          expect(
            _listWork(dependencies)
                .where((Task task) => task.projectId == project.id),
            isEmpty,
          );
        }
      }
    }
  });

  test('test_build_gallery_dependencies_property_person_steps_follow_'
      'the_task_runs', () async {
    final AppDependencies dependencies = buildGalleryDependencies();
    int notifications = 0;
    dependencies.personStepRepository.addListener(() => notifications += 1);

    for (final Task task in _listWork(dependencies)) {
      for (final Run run in dependencies.taskRepository.listRuns(task.id)) {
        if (isRunActive(run)) {
          await dependencies.taskRepository.cancelRun(run.id);
        }
      }
    }

    expect(dependencies.personStepRepository.listOpenPersonSteps(), isEmpty);
    expect(notifications, greaterThan(0));
  });

  test('test_build_workspace_repository_property_starts_in_acme_with_'
      'every_gallery_workspace', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    expect(
      dependencies.workspaceRepository.listWorkspaces(),
      galleryWorkspaces,
    );
    expect(
      dependencies.workspaceRepository.currentWorkspace().id,
      GalleryWorkspaceIds.acme,
    );
  });

  test('test_build_workspace_repository_property_deleting_a_workspace_'
      'removes_its_projects_and_work', () async {
    for (final Workspace doomed in galleryWorkspaces) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Project> doomedProjects = dependencies.projectRepository
          .listProjects(doomed.id);
      final bool isRunning = doomedProjects.any(
        (Project project) => _hasRunningWork(dependencies, project.id),
      );
      final Future<void> deletion = dependencies.workspaceRepository
          .deleteWorkspace(doomed.id);

      if (isRunning) {
        await expectLater(deletion, throwsStateError);
        expect(
          dependencies.projectRepository.listProjects(doomed.id),
          doomedProjects,
        );
        continue;
      }
      await deletion;

      expect(dependencies.projectRepository.listProjects(doomed.id), isEmpty);
      for (final Project project in doomedProjects) {
        expect(
          _listWork(dependencies)
              .where((Task task) => task.projectId == project.id),
          isEmpty,
        );
      }
    }
  });

  test('test_build_approval_repository_property_decisions_stay_in_one_'
      'build', () async {
    final AppDependencies first = buildGalleryDependencies();
    final AppDependencies second = buildGalleryDependencies();
    final List<ApprovalRequest> pending = first.approvalRepository
        .listPendingApprovals();

    for (final ApprovalRequest request in pending) {
      await first.approvalRepository.decideApproval(
        request.id,
        ApprovalDecision.values.first,
      );
    }

    expect(first.approvalRepository.listPendingApprovals(), isEmpty);
    expect(second.approvalRepository.listPendingApprovals(), pending);
  });
}
