import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart'
    as node;
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

SkillUsage mapSkillUsageFromNode(node.SkillUsage usage) {
  return switch (usage) {
    node.SkillUsage.automatic => SkillUsage.automatic,
    node.SkillUsage.whenChosen => SkillUsage.whenChosen,
  };
}

node.SkillUsage mapSkillUsageToNode(SkillUsage usage) {
  return switch (usage) {
    SkillUsage.automatic => node.SkillUsage.automatic,
    SkillUsage.whenChosen => node.SkillUsage.whenChosen,
  };
}

SkillSource mapSkillSourceFromNode(node.SkillSource source) {
  return switch (source) {
    node.SkillSource.builtIn => SkillSource.builtIn,
    node.SkillSource.created => SkillSource.created,
  };
}

SkillImprovement mapSkillImprovementFromNode(
  node.SkillImprovement improvement,
) {
  return switch (improvement) {
    node.SkillImprovement.never => SkillImprovement.never,
    node.SkillImprovement.askMe => SkillImprovement.askMe,
    node.SkillImprovement.auto => SkillImprovement.auto,
  };
}

node.SkillImprovement mapSkillImprovementToNode(SkillImprovement improvement) {
  return switch (improvement) {
    SkillImprovement.never => node.SkillImprovement.never,
    SkillImprovement.askMe => node.SkillImprovement.askMe,
    SkillImprovement.auto => node.SkillImprovement.auto,
  };
}

SkillChangeOrigin _mapSkillChangeOriginFromNode(
  node.SkillChangeOrigin origin,
) {
  return switch (origin) {
    node.PersonEdit() => const PersonEdit(),
    node.ApprovedAgentRun() => ApprovedAgentRun(origin.runId),
    node.AutomaticAgentRun() => AutomaticAgentRun(origin.runId),
  };
}

SkillChange mapSkillChangeFromNode(node.SkillChange change) {
  return SkillChange(
    origin: _mapSkillChangeOriginFromNode(change.origin),
    savedAt: change.savedAt,
    replacedInstructions: change.replacedInstructions,
  );
}

Skill mapSkillFromNode(node.Skill skill) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: mapScopeFromNode(skill.scope),
    usage: mapSkillUsageFromNode(skill.usage),
    source: mapSkillSourceFromNode(skill.source),
    improvement: mapSkillImprovementFromNode(skill.improvement),
    history: <SkillChange>[
      for (final node.SkillChange change in skill.history)
        mapSkillChangeFromNode(change),
    ],
  );
}

Rule mapRuleFromNode(node.Rule rule) {
  return Rule(
    id: rule.id,
    title: rule.title,
    details: rule.details,
    scope: mapScopeFromNode(rule.scope),
    enabled: rule.enabled,
    addedAt: rule.addedAt,
  );
}
