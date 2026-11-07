import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

List<Task> _listTasksAndJobs(AppDependencies dependencies) {
  return <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
}

List<Project> _listProjects(AppDependencies dependencies) {
  return <Project>[
    for (final Workspace workspace
        in dependencies.workspaceRepository.listWorkspaces())
      ...dependencies.projectRepository.listProjects(workspace.id),
  ];
}

bool _isAvailableIn(WorkspaceScope availability, WorkspaceId workspaceId) {
  return switch (availability) {
    AllWorkspaces() => true,
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => workspaces.contains(
      workspaceId,
    ),
  };
}

void _expectScopeResolves(AppDependencies dependencies, Scope scope) {
  final WorkspaceScope workspaces = scope.workspaces;
  if (workspaces is OnlyWorkspaces) {
    final List<WorkspaceId> listedIds = <WorkspaceId>[
      for (final Workspace workspace
          in dependencies.workspaceRepository.listWorkspaces())
        workspace.id,
    ];
    expect(listedIds, containsAll(workspaces.workspaces));
  }
  final ProjectScope projects = scope.projects;
  if (projects is OnlyProjects) {
    for (final ProjectId projectId in projects.projects) {
      dependencies.projectRepository.findProject(projectId);
    }
  }
}

void _expectRunFollowsWorkflow(Run run, Workflow workflow) {
  for (final RunStep step in run.steps) {
    final WorkflowAgentId? agentId = step.agentId;
    if (agentId != null) {
      expect(workflow.findAgentIfPresent(agentId), isNotNull);
    }
  }
}

void main() {
  test('test_build_gallery_dependencies_property_tasks_can_use_doer', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final Task task in _listTasksAndJobs(dependencies)) {
      final Project project = dependencies.projectRepository.findProject(
        task.projectId,
      );
      for (final SkillId skillId in task.skills) {
        dependencies.skillRepository.findSkill(skillId);
      }
      final TaskDoer doer = task.doer;
      if (doer is! WorkflowDoer) {
        continue;
      }
      final Workflow workflow = dependencies.workflowRepository.findWorkflow(
        doer.workflowId,
      );
      expect(
        _isAvailableIn(workflow.availability, project.workspaceId),
        isTrue,
        reason: task.title,
      );
      for (final Run run in dependencies.taskRepository.listRuns(task.id)) {
        _expectRunFollowsWorkflow(run, workflow);
      }
    }
  });

  test('test_build_gallery_dependencies_property_approvals_resolve', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final ApprovalRequest request
        in dependencies.approvalRepository.listApprovals()) {
      dependencies.deviceRepository.findDevice(request.requestedBy);
      final SignedDecision? decision = request.decision;
      if (decision != null) {
        dependencies.deviceRepository.findDevice(decision.decidedBy);
      }
      final ApprovalAction action = request.action;
      if (action is SignWorkflowAction) {
        final WorkflowChange? change = dependencies.workflowRepository
            .findPendingChange(action.workflowId);
        expect(change, isNotNull, reason: action.workflowId.value);
      }
      if (action is ImproveSkillAction) {
        dependencies.skillRepository.findSkill(action.skillId);
      }
      final RunId? runId = request.runId;
      if (runId != null) {
        dependencies.chatRepository.findConversation(runId);
      }
    }
  });

  test('test_build_gallery_dependencies_property_projects_valid', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<Project> projects = _listProjects(dependencies);
    final Set<ProjectId> projectIds = <ProjectId>{
      for (final Project project in projects) project.id,
    };

    expect(projectIds, hasLength(projects.length));
    for (final Project project in projects) {
      expect(describeNameProblem(project.name), isNull, reason: project.name);
      final Set<String> addresses = <String>{
        for (final Repository repository in project.repositories)
          repository.address,
      };
      expect(addresses, hasLength(project.repositories.length));
    }
    for (final Task task in _listTasksAndJobs(dependencies)) {
      expect(projectIds, contains(task.projectId));
    }
  });

  test('test_build_gallery_dependencies_property_library_resolves', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<Skill> skills = dependencies.skillRepository.listSkills();
    final Set<String> skillNames = <String>{
      for (final Skill skill in skills) skill.name,
    };

    expect(skillNames, hasLength(skills.length));
    for (final Skill skill in skills) {
      expect(describeNameProblem(skill.name), isNull, reason: skill.name);
      _expectScopeResolves(dependencies, skill.scope);
    }
    for (final Rule rule in dependencies.ruleRepository.listRules()) {
      expect(rule.title.trim(), isNotEmpty);
      _expectScopeResolves(dependencies, rule.scope);
    }
  });

  test('test_build_gallery_dependencies_property_devices_resolve', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppServerGroup group = dependencies.workspaceRepository
        .findAppServerGroup();

    dependencies.deviceRepository.currentDevice();
    for (final AppServerMember member in group.members) {
      dependencies.deviceRepository.findDevice(member.deviceId);
    }
    for (final Runner runner in dependencies.runnerRepository.listRunners()) {
      dependencies.deviceRepository.findDevice(runner.deviceId);
    }
    for (final AuditEntry entry
        in dependencies.auditRepository.listEntries()) {
      dependencies.deviceRepository.findDevice(entry.deviceId);
    }
    final bool listsThisDevice = group.members.any(
      (AppServerMember member) =>
          member.deviceId == dependencies.deviceRepository.currentDevice().id,
    );
    expect(
      listsThisDevice,
      group.thisDeviceStanding != ThisDeviceStanding.none,
    );
  });
}
