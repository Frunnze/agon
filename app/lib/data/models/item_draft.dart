import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

enum DraftKind { task, job, skill, rule }

sealed class DraftedItem {
  const DraftedItem();
}

final class DraftedWork extends DraftedItem {
  DraftedWork({
    required this.title,
    required this.details,
    required this.projectId,
    required this.doer,
    required this.runsOn,
    required this.agentPlace,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
    required this.schedule,
  }) : skills = List<SkillId>.unmodifiable(skills);

  final String title;
  final String details;
  final ProjectId? projectId;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final AgentPlace agentPlace;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy? approvalPolicy;
  final Schedule? schedule;

  TaskDraft toTaskDraft() {
    final ProjectId? chosenProjectId = projectId;
    if (chosenProjectId == null) {
      throw StateError('The draft of $title has no project');
    }

    return TaskDraft(
      title: title,
      details: details,
      projectId: chosenProjectId,
      doer: doer,
      runsOn: runsOn,
      agentPlace: agentPlace,
      skills: skills,
      usesAutomaticSkills: usesAutomaticSkills,
      approvalPolicy: approvalPolicy,
    );
  }
}

final class DraftedProject {
  DraftedProject({
    required this.name,
    required List<RepositoryDraft> repositories,
    required this.agentAccess,
    required this.approvalPolicy,
  }) : repositories = List<RepositoryDraft>.unmodifiable(repositories);

  final String name;
  final List<RepositoryDraft> repositories;
  final AgentAccess agentAccess;
  final ApprovalPolicy? approvalPolicy;

  ProjectDraft toProjectDraft(WorkspaceId workspaceId) {
    return ProjectDraft(
      workspaceId: workspaceId,
      name: name,
      repositories: <Repository>[
        for (final RepositoryDraft repository in repositories)
          Repository(
            address: repository.address,
            defaultBranch: repository.defaultBranch,
            agentAccess: agentAccess,
          ),
      ],
      approvalPolicy: approvalPolicy,
    );
  }
}

final class DraftedSkill extends DraftedItem {
  const DraftedSkill(this.skill);

  final SkillDraft skill;
}

final class DraftedRule extends DraftedItem {
  const DraftedRule(this.rule);

  final RuleDraft rule;
}

final class ItemDraft {
  ItemDraft({required this.item, required List<String> problems})
    : problems = List<String>.unmodifiable(problems);

  final DraftedItem item;
  final List<String> problems;

  bool get canBeApproved => problems.isEmpty;
}

final class ItemDraftChange {
  const ItemDraftChange({required this.draft, required this.note});

  final DraftedItem draft;
  final String note;
}

final class ItemDraftRequest {
  ItemDraftRequest({
    required this.kind,
    required this.wish,
    required this.startedFrom,
    required this.change,
  });

  final DraftKind kind;
  final String wish;
  final String? startedFrom;
  final ItemDraftChange? change;
}

sealed class ItemDraftProgress {
  const ItemDraftProgress();
}

final class DraftRunning extends ItemDraftProgress {
  const DraftRunning({
    required this.drafterKind,
    required this.drafterDeviceId,
  });

  final AgentKind drafterKind;
  final DeviceId drafterDeviceId;
}

final class DraftFinished extends ItemDraftProgress {
  const DraftFinished(this.draft);

  final ItemDraft draft;
}
