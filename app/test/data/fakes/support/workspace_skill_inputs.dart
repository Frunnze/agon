import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import 'rule_inputs.dart';
import 'skill_inputs.dart';
import 'workspace_scope_inputs.dart';

Skill withSkillScope(Skill skill, Scope scope) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: scope,
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: skill.history,
  );
}

List<Skill> randomSkillsScopedOver(
  Random random,
  List<WorkspaceId> workspaceIds,
) {
  return <Skill>[
    for (final Skill skill in randomSeededSkills(random))
      withSkillScope(skill, randomScopeOver(random, workspaceIds)),
  ];
}

List<String> describeSkillsInScope(List<Skill> skills) {
  return <String>[
    for (final Skill skill in skills)
      '${describeSkill(skill)} ${describeScope(skill.scope)}',
  ];
}

List<String> predictSkillsListedIn(
  List<Skill> skills,
  WorkspaceId workspaceId,
) {
  return describeSkillsInScope(<Skill>[
    for (final Skill skill in skills)
      if (isModelUsableInWorkspace(skill.scope.workspaces, workspaceId)) skill,
  ]);
}
