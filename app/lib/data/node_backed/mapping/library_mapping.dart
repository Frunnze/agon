import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/data/models/library.dart';
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

Skill mapSkillFromNode(node.Skill skill) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: mapScopeFromNode(skill.scope),
    usage: mapSkillUsageFromNode(skill.usage),
    source: mapSkillSourceFromNode(skill.source),
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
