import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum SkillUsage implements WireNamed {
  automatic('automatic'),
  whenChosen('when_chosen');

  const SkillUsage(this.wireName);

  @override
  final String wireName;

  static SkillUsage decode(Object? json) => decodeWireName(values, json);
}

enum SkillSource implements WireNamed {
  builtIn('built_in'),
  created('created');

  const SkillSource(this.wireName);

  @override
  final String wireName;

  static SkillSource decode(Object? json) => decodeWireName(values, json);
}

final class Skill implements JsonEncodable {
  const Skill({
    required this.id,
    required this.name,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
    required this.source,
  });

  factory Skill.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Skill(
      id: readField(fields, 'id', decodeSkillId),
      name: readField(fields, 'name', decodeText),
      summary: readField(fields, 'summary', decodeText),
      instructions: readField(fields, 'instructions', decodeText),
      scope: readField(fields, 'scope', Scope.fromJson),
      usage: readField(fields, 'usage', SkillUsage.decode),
      source: readField(fields, 'source', SkillSource.decode),
    );
  }

  final SkillId id;
  final String name;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;
  final SkillSource source;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'name': name,
      'summary': summary,
      'instructions': instructions,
      'scope': scope.toJson(),
      'usage': usage.wireName,
      'source': source.wireName,
    };
  }
}

final class Rule implements JsonEncodable {
  const Rule({
    required this.id,
    required this.title,
    required this.details,
    required this.scope,
    required this.enabled,
    required this.addedAt,
  });

  factory Rule.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Rule(
      id: readField(fields, 'id', decodeRuleId),
      title: readField(fields, 'title', decodeText),
      details: readField(fields, 'details', decodeText),
      scope: readField(fields, 'scope', Scope.fromJson),
      enabled: readField(fields, 'enabled', decodeFlag),
      addedAt: readField(fields, 'added_at', decodeMoment),
    );
  }

  final RuleId id;
  final String title;
  final String details;
  final Scope scope;
  final bool enabled;
  final DateTime addedAt;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'title': title,
      'details': details,
      'scope': scope.toJson(),
      'enabled': enabled,
      'added_at': encodeMoment(addedAt),
    };
  }
}

final class AgentsMarkdownView implements JsonEncodable {
  const AgentsMarkdownView({required this.markdown});

  factory AgentsMarkdownView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AgentsMarkdownView(
      markdown: readField(fields, 'markdown', decodeText),
    );
  }

  final String markdown;

  @override
  JsonObject toJson() => <String, Object?>{'markdown': markdown};
}
