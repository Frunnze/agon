import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';

enum SkillUsage {
  automatic('Automatic'),
  whenChosen('When chosen');

  const SkillUsage(this.label);

  final String label;
}

enum SkillSource { builtIn, created }

final class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
    required this.source,
  });

  final SkillId id;
  final String name;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;
  final SkillSource source;
}

final class SkillDraft {
  const SkillDraft({
    required this.name,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
  });

  final String name;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;
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
