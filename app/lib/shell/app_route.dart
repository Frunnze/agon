import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/draft_kind_sections.dart';

sealed class AppRoute {
  const AppRoute(this.section);

  final AppSection section;

  @override
  bool operator ==(Object other) {
    return other is AppRoute &&
        other.runtimeType == runtimeType &&
        other.identity == identity;
  }

  @override
  int get hashCode => Object.hash(runtimeType, identity);

  String get identity => section.name;
}

final class SectionRoute extends AppRoute {
  const SectionRoute(super.section);
}

final class NewTaskRoute extends AppRoute {
  const NewTaskRoute() : super(AppSection.tasks);
}

final class EditTaskRoute extends AppRoute {
  const EditTaskRoute(this.taskId) : super(AppSection.tasks);

  final TaskId taskId;

  @override
  String get identity => taskId.value;
}

final class TaskRunRoute extends AppRoute {
  const TaskRunRoute(this.runId) : super(AppSection.tasks);

  final RunId runId;

  @override
  String get identity => runId.value;
}

final class ChatRoute extends AppRoute {
  const ChatRoute(this.runId) : super(AppSection.tasks);

  final RunId runId;

  @override
  String get identity => runId.value;
}

final class NewJobRoute extends AppRoute {
  const NewJobRoute() : super(AppSection.jobs);
}

final class EditJobRoute extends AppRoute {
  const EditJobRoute(this.jobId) : super(AppSection.jobs);

  final TaskId jobId;

  @override
  String get identity => jobId.value;
}

final class WorkflowChangeRoute extends AppRoute {
  const WorkflowChangeRoute(this.workflowId) : super(AppSection.workflows);

  final WorkflowId workflowId;

  @override
  String get identity => workflowId.value;
}

final class WorkspaceSwitcherRoute extends AppRoute {
  const WorkspaceSwitcherRoute() : super(AppSection.projects);
}

final class NewProjectRoute extends AppRoute {
  const NewProjectRoute() : super(AppSection.projects);
}

final class ProjectRoute extends AppRoute {
  const ProjectRoute(this.projectId) : super(AppSection.projects);

  final ProjectId projectId;

  @override
  String get identity => projectId.value;
}

final class ProjectFilesRoute extends AppRoute {
  const ProjectFilesRoute({
    required this.projectId,
    required this.repositoryAddress,
    this.branch,
  }) : super(AppSection.projects);

  final ProjectId projectId;
  final String repositoryAddress;
  final String? branch;

  @override
  String get identity {
    return '${projectId.value} $repositoryAddress ${branch ?? ''}';
  }
}

final class RepositoryFileRoute extends AppRoute {
  const RepositoryFileRoute({
    required this.filesRoute,
    required this.source,
    required this.branch,
    required this.path,
  }) : super(AppSection.projects);

  final ProjectFilesRoute filesRoute;
  final FilesFromRunner source;
  final String branch;
  final String path;

  RepositoryBranchLocation get location {
    return RepositoryBranchLocation(
      projectId: filesRoute.projectId,
      repositoryAddress: filesRoute.repositoryAddress,
      runnerId: source.runnerId,
      branch: branch,
    );
  }

  @override
  String get identity => '${filesRoute.identity} $branch $path';
}

final class NewWorkflowRoute extends AppRoute {
  const NewWorkflowRoute() : super(AppSection.workflows);
}

final class WorkflowDraftingRoute extends AppRoute {
  const WorkflowDraftingRoute(this.draft) : super(AppSection.workflows);

  final WorkflowDraft draft;

  @override
  String get identity => draft.description;
}

final class WorkflowDetailRoute extends AppRoute {
  const WorkflowDetailRoute(this.workflowId) : super(AppSection.workflows);

  final WorkflowId workflowId;

  @override
  String get identity => workflowId.value;
}

enum BuilderOpening { afterDrafting, forEditing }

final class WorkflowBuilderRoute extends AppRoute {
  const WorkflowBuilderRoute(this.workflowId, {required this.opening})
    : super(AppSection.workflows);

  final WorkflowId workflowId;
  final BuilderOpening opening;

  @override
  String get identity => '${workflowId.value} ${opening.name}';
}

final class NewWorkflowTaskRoute extends AppRoute {
  const NewWorkflowTaskRoute(this.workflowId) : super(AppSection.tasks);

  final WorkflowId workflowId;

  @override
  String get identity => workflowId.value;
}

final class NewSkillRoute extends AppRoute {
  const NewSkillRoute() : super(AppSection.skills);
}

final class SkillDetailRoute extends AppRoute {
  const SkillDetailRoute(this.skillId) : super(AppSection.skills);

  final SkillId skillId;

  @override
  String get identity => skillId.value;
}

final class EditSkillRoute extends AppRoute {
  const EditSkillRoute(this.skillId) : super(AppSection.skills);

  final SkillId skillId;

  @override
  String get identity => skillId.value;
}

final class RuleDetailRoute extends AppRoute {
  const RuleDetailRoute(this.ruleId) : super(AppSection.rules);

  final RuleId ruleId;

  @override
  String get identity => ruleId.value;
}

final class EditRuleRoute extends AppRoute {
  const EditRuleRoute(this.ruleId) : super(AppSection.rules);

  final RuleId ruleId;

  @override
  String get identity => ruleId.value;
}

final class NewRuleRoute extends AppRoute {
  const NewRuleRoute({required this.presetProjectId})
    : super(AppSection.rules);

  final ProjectId? presetProjectId;

  @override
  String get identity => presetProjectId?.value ?? section.name;
}

final class NewItemFormRoute extends AppRoute {
  NewItemFormRoute(this.kind, {this.presetProjectId, this.presetWorkflowId})
    : super(findDraftKindSection(kind));

  final DraftKind kind;
  final ProjectId? presetProjectId;
  final WorkflowId? presetWorkflowId;

  @override
  String get identity {
    return '${kind.name} ${presetProjectId?.value} ${presetWorkflowId?.value}';
  }
}

final class RunnersSettingsRoute extends AppRoute {
  const RunnersSettingsRoute() : super(AppSection.settings);
}

final class RunnerDetailRoute extends AppRoute {
  const RunnerDetailRoute(this.deviceId) : super(AppSection.settings);

  final DeviceId deviceId;

  @override
  String get identity => deviceId.value;
}

final class PairingCodeRoute extends AppRoute {
  const PairingCodeRoute() : super(AppSection.devices);
}

final class PairingApprovalRoute extends AppRoute {
  const PairingApprovalRoute() : super(AppSection.devices);
}

sealed class SetupRoute extends AppRoute {
  const SetupRoute() : super(AppSection.devices);
}

final class SetupRoleRoute extends SetupRoute {
  const SetupRoleRoute();
}

final class PairingCodeEntryRoute extends SetupRoute {
  const PairingCodeEntryRoute(this.role);

  final DeviceRole role;

  @override
  String get identity => role.name;
}

final class PairingDoneRoute extends SetupRoute {
  const PairingDoneRoute(this.outcome);

  final PairingOutcome outcome;

  @override
  String get identity => outcome.deviceName;
}
