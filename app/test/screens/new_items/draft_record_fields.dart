import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';

List<Object?> describeScheduleFields(Schedule? schedule) {
  switch (schedule) {
    case null:
      return const <Object?>[];
    case HourlySchedule(:final int minute):
      return <Object?>['hourly', minute];
    case DailySchedule(:final ScheduleTime at):
      return <Object?>['daily', at.hour, at.minute];
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      return <Object?>['weekly', on, at.hour, at.minute];
  }
}

List<Object?> describeScopeFields(Scope scope) {
  final List<Object?> workspaceFields = switch (scope.workspaces) {
    AllWorkspaces() => const <Object?>['all workspaces'],
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => <Object?>[
      'only workspaces',
      ...workspaces,
    ],
  };
  final List<Object?> projectFields = switch (scope.projects) {
    AllProjects() => const <Object?>['all projects'],
    OnlyProjects(:final List<ProjectId> projects) => <Object?>[
      'only projects',
      ...projects,
    ],
  };

  return <Object?>[...workspaceFields, ...projectFields];
}

List<Object?> describeDraftedWorkFields(DraftedWork work) {
  return <Object?>[
    work.title,
    work.details,
    work.projectId,
    work.doer,
    work.runsOn,
    work.agentPlace,
    ...work.skills,
    work.usesAutomaticSkills,
    work.approvalPolicy,
    ...describeScheduleFields(work.schedule),
  ];
}

List<Object?> describeSavedWorkFields(Task task) {
  return <Object?>[
    task.title,
    task.details,
    task.projectId,
    task.doer,
    task.runsOn,
    task.agentPlace,
    ...task.skills,
    task.usesAutomaticSkills,
    task.approvalPolicy,
    ...describeScheduleFields(task.schedule),
  ];
}

List<Object?> describeSkillFields({
  required String name,
  required String summary,
  required String instructions,
  required Scope scope,
  required SkillUsage usage,
  required SkillImprovement improvement,
}) {
  return <Object?>[
    name,
    summary,
    instructions,
    ...describeScopeFields(scope),
    usage,
    improvement,
  ];
}

List<Object?> describeRuleFields({
  required String title,
  required String details,
  required Scope scope,
}) {
  return <Object?>[title, details, ...describeScopeFields(scope)];
}
