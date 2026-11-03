import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';

enum SkillUsage {
  automatic('Automatic'),
  whenChosen('When chosen');

  const SkillUsage(this.label);

  final String label;
}

enum SkillSource { builtIn, created }

enum SkillImprovement {
  never('Never', 'Agents never change this skill.'),
  askMe(
    'Ask me',
    'An agent that used it may propose a better version for you to approve.',
  ),
  auto('Auto', "An agent's better version is saved at once. You can undo it.");

  const SkillImprovement(this.label, this.explanation);

  final String label;
  final String explanation;
}

final class Skill {
  Skill({
    required this.id,
    required this.name,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
    required this.source,
    required this.improvement,
    required List<SkillChange> history,
  }) : history = List<SkillChange>.unmodifiable(history);

  final SkillId id;
  final String name;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;
  final SkillSource source;
  final SkillImprovement improvement;
  final List<SkillChange> history;
}

final class SkillDraft {
  const SkillDraft({
    required this.name,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
    required this.improvement,
  });

  final String name;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;
  final SkillImprovement improvement;
}

final class Rule {
  const Rule({
    required this.id,
    required this.title,
    required this.details,
    required this.scope,
    required this.enabled,
    required this.addedAt,
  });

  final RuleId id;
  final String title;
  final String details;
  final Scope scope;
  final bool enabled;
  final DateTime addedAt;

  Rule asEnabled() {
    return Rule(
      id: id,
      title: title,
      details: details,
      scope: scope,
      enabled: true,
      addedAt: addedAt,
    );
  }

  Rule asDisabled() {
    return Rule(
      id: id,
      title: title,
      details: details,
      scope: scope,
      enabled: false,
      addedAt: addedAt,
    );
  }
}

final class RuleDraft {
  const RuleDraft({
    required this.title,
    required this.details,
    required this.scope,
  });

  final String title;
  final String details;
  final Scope scope;
}
