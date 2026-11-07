import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'rule_inputs.dart';
import 'workspace_world_inputs.dart';

typedef LibraryEntry = ({String identifier, String scope});

WorkspaceScope _forgetLikeServer(WorkspaceScope scope, WorkspaceId deleted) {
  if (scope is! OnlyWorkspaces) {
    return scope;
  }
  final List<WorkspaceId> kept = <WorkspaceId>[];
  for (final WorkspaceId listed in scope.workspaces) {
    if (listed != deleted) {
      kept.add(listed);
    }
  }
  return OnlyWorkspaces(kept);
}

bool _isSeenLikeServer(WorkspaceScope scope, Set<WorkspaceId> remaining) {
  if (scope is! OnlyWorkspaces) {
    return true;
  }
  for (final WorkspaceId listed in scope.workspaces) {
    if (remaining.contains(listed)) {
      return true;
    }
  }
  return false;
}

Scope? _keepScopeLikeServer(
  Scope scope,
  WorkspaceId deleted,
  Set<WorkspaceId> remaining,
) {
  final WorkspaceScope workspaces = _forgetLikeServer(
    scope.workspaces,
    deleted,
  );
  if (!_isSeenLikeServer(workspaces, remaining)) {
    return null;
  }
  return Scope(workspaces: workspaces, projects: scope.projects);
}

List<LibraryEntry> expectRulesAfterDeleting(
  WorkspaceWorld world,
  WorkspaceId deleted,
  Set<WorkspaceId> remaining,
) {
  final List<LibraryEntry> entries = <LibraryEntry>[];
  for (final Rule rule in world.rules) {
    final Scope? kept = _keepScopeLikeServer(rule.scope, deleted, remaining);
    if (kept != null) {
      entries.add((identifier: rule.id.value, scope: describeScope(kept)));
    }
  }
  return entries;
}

List<LibraryEntry> describeSkillEntries(List<Skill> skills) {
  return <LibraryEntry>[
    for (final Skill skill in skills)
      (identifier: skill.id.value, scope: describeScope(skill.scope)),
  ];
}

List<LibraryEntry> describeRuleEntries(List<Rule> rules) {
  return <LibraryEntry>[
    for (final Rule rule in rules)
      (identifier: rule.id.value, scope: describeScope(rule.scope)),
  ];
}

List<String> expectVisibleRuleIds(
  WorkspaceWorld world,
  WorkspaceId deleted,
  Set<WorkspaceId> remaining,
  WorkspaceId current,
) {
  final List<String> visible = <String>[];
  for (final Rule rule in world.rules) {
    final Scope? kept = _keepScopeLikeServer(rule.scope, deleted, remaining);
    if (kept != null &&
        _isSeenLikeServer(kept.workspaces, <WorkspaceId>{current})) {
      visible.add(rule.id.value);
    }
  }
  return visible;
}

List<TaskId> expectWorkAfterDeleting(
  WorkspaceWorld world,
  Set<ProjectId> removedProjects,
) {
  return <TaskId>[
    for (final Task task in world.work.tasks)
      if (!removedProjects.contains(task.projectId)) task.id,
  ];
}

List<ProjectId> expectProjectsAfterDeleting(
  WorkspaceWorld world,
  WorkspaceId deleted,
) {
  return <ProjectId>[
    for (final Project project in world.projects)
      if (project.workspaceId != deleted) project.id,
  ];
}

List<WorkflowId> expectWorkflowsAfterDeleting(
  WorkspaceWorld world,
  Set<ProjectId> removedProjects,
  Set<WorkspaceId> remaining,
) {
  final Set<WorkflowDoer> usedDoers = <WorkflowDoer>{};
  for (final Task task in world.work.tasks) {
    final TaskDoer doer = task.doer;
    if (doer is WorkflowDoer && !removedProjects.contains(task.projectId)) {
      usedDoers.add(doer);
    }
  }
  return <WorkflowId>[
    for (final Workflow workflow in world.workflows)
      if (_isSeenLikeServer(workflow.availability, remaining) ||
          usedDoers.contains(WorkflowDoer(workflow.id)))
        workflow.id,
  ];
}
