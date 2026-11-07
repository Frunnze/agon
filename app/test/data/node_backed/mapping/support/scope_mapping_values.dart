import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../../../bridge/support/hostile_texts.dart';
import '../../../../support/sample_scopes.dart';

const String _allKind = 'all';
const String _onlyKind = 'only';

List<WorkspaceId> randomWorkspaceIdsWithRepeats(Random random) {
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final String text in randomHostileTexts(random)) WorkspaceId(text),
  ];
  return <WorkspaceId>[...workspaceIds, ...workspaceIds.reversed];
}

List<ProjectId> randomProjectIdsWithRepeats(Random random) {
  final List<ProjectId> projectIds = <ProjectId>[
    for (final String text in randomHostileTexts(random)) ProjectId(text),
  ];
  return <ProjectId>[...projectIds, ...projectIds.reversed];
}

node.WorkspaceScope randomNodeWorkspaceScope(Random random) {
  if (random.nextBool()) {
    return const node.AllWorkspaces();
  }
  return node.OnlyWorkspaces(
    workspaces: randomWorkspaceIdsWithRepeats(random),
  );
}

node.ProjectScope randomNodeProjectScope(Random random) {
  if (random.nextBool()) {
    return const node.AllProjects();
  }
  return node.OnlyProjects(projects: randomProjectIdsWithRepeats(random));
}

WorkspaceScope randomHostileWorkspaceScope(Random random) {
  if (random.nextBool()) {
    return randomWorkspaceScope(random);
  }
  return OnlyWorkspaces(randomWorkspaceIdsWithRepeats(random));
}

ProjectScope randomHostileProjectScope(Random random) {
  if (random.nextBool()) {
    return randomProjectScope(random);
  }
  return OnlyProjects(randomProjectIdsWithRepeats(random));
}

List<Object?> describeWorkspaceScope(WorkspaceScope scope) {
  return switch (scope) {
    AllWorkspaces() => <Object?>[_allKind],
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => <Object?>[
      _onlyKind,
      workspaces,
    ],
  };
}

List<Object?> describeNodeWorkspaceScope(node.WorkspaceScope scope) {
  return switch (scope) {
    node.AllWorkspaces() => <Object?>[_allKind],
    node.OnlyWorkspaces(:final List<WorkspaceId> workspaces) => <Object?>[
      _onlyKind,
      workspaces,
    ],
  };
}

List<Object?> describeProjectScope(ProjectScope scope) {
  return switch (scope) {
    AllProjects() => <Object?>[_allKind],
    OnlyProjects(:final List<ProjectId> projects) => <Object?>[
      _onlyKind,
      projects,
    ],
  };
}

List<Object?> describeNodeProjectScope(node.ProjectScope scope) {
  return switch (scope) {
    node.AllProjects() => <Object?>[_allKind],
    node.OnlyProjects(:final List<ProjectId> projects) => <Object?>[
      _onlyKind,
      projects,
    ],
  };
}
