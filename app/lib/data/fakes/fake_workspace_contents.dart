import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/fakes/workspace_membership.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

final class FakeWorkspaceContents {
  const FakeWorkspaceContents({
    required FakeProjectRepository projectRepository,
    required FakeTaskWork taskWork,
    required FakeSkillRepository skillRepository,
    required FakeRuleRepository ruleRepository,
    required FakeWorkflowRepository workflowRepository,
    required FakeDeviceRepository deviceRepository,
  }) : _projectRepository = projectRepository,
       _taskWork = taskWork,
       _skillRepository = skillRepository,
       _ruleRepository = ruleRepository,
       _workflowRepository = workflowRepository,
       _deviceRepository = deviceRepository;

  final FakeProjectRepository _projectRepository;
  final FakeTaskWork _taskWork;
  final FakeSkillRepository _skillRepository;
  final FakeRuleRepository _ruleRepository;
  final FakeWorkflowRepository _workflowRepository;
  final FakeDeviceRepository _deviceRepository;

  void grantCreatedWorkspace(WorkspaceId createdWorkspaceId) {
    _deviceRepository.grantWorkspaceToCurrentDevice(createdWorkspaceId);
  }

  void refuseOutsiderDevice(WorkspaceId workspaceId) {
    refuseDeviceOutsideWorkspace(_deviceRepository, workspaceId);
  }

  void refuseRunningWork(Workspace workspace) {
    final Set<ProjectId> projectIds = _listProjectIds(workspace.id);
    if (_taskWork.hasActiveRunInProjects(projectIds)) {
      throw StateError(
        'a task in workspace ${workspace.name} is running; cancel its run '
        'first',
      );
    }
  }

  Future<void> removeContents({
    required WorkspaceId deletedWorkspaceId,
    required Set<WorkspaceId> remainingWorkspaceIds,
  }) async {
    for (final ProjectId projectId in _listProjectIds(deletedWorkspaceId)) {
      await _projectRepository.deleteProject(projectId);
    }
    _skillRepository.forgetWorkspace(
      deletedWorkspaceId: deletedWorkspaceId,
      remainingWorkspaceIds: remainingWorkspaceIds,
    );
    _ruleRepository.forgetWorkspace(
      deletedWorkspaceId: deletedWorkspaceId,
      remainingWorkspaceIds: remainingWorkspaceIds,
    );
    _deviceRepository.withdrawWorkspace(deletedWorkspaceId);
    _workflowRepository.forgetUnseenWorkflows(remainingWorkspaceIds);
  }

  Set<ProjectId> _listProjectIds(WorkspaceId workspaceId) {
    final List<Project> projects = _projectRepository.listProjects(
      workspaceId,
    );
    final Set<ProjectId> projectIds = <ProjectId>{};
    for (final Project project in projects) {
      projectIds.add(project.id);
    }
    return projectIds;
  }
}
