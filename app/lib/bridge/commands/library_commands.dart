import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListSkillsCommand implements NodeCommand<List<Skill>> {
  const ListSkillsCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_skills';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  List<Skill> decodeReply(Object? okValue) {
    return decodeList(okValue, Skill.fromJson);
  }
}

final class CreateSkillCommand implements NodeCommand<Skill> {
  const CreateSkillCommand({
    required this.workspaceId,
    required this.skillName,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
  });

  final WorkspaceId workspaceId;
  final String skillName;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;

  @override
  String get name => 'create_skill';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'name': skillName,
      'summary': summary,
      'instructions': instructions,
      'scope': scope.toJson(),
      'usage': usage.wireName,
    };
  }

  @override
  Skill decodeReply(Object? okValue) => Skill.fromJson(okValue);
}

final class UpdateSkillCommand implements NodeCommand<Skill> {
  const UpdateSkillCommand({
    required this.workspaceId,
    required this.skillId,
    required this.skillName,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
  });

  final WorkspaceId workspaceId;
  final SkillId skillId;
  final String skillName;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;

  @override
  String get name => 'update_skill';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'skill_id': skillId.value,
      'name': skillName,
      'summary': summary,
      'instructions': instructions,
      'scope': scope.toJson(),
      'usage': usage.wireName,
    };
  }

  @override
  Skill decodeReply(Object? okValue) => Skill.fromJson(okValue);
}

final class DeleteSkillCommand implements NodeCommand<void> {
  const DeleteSkillCommand({required this.skillId});

  final SkillId skillId;

  @override
  String get name => 'delete_skill';

  @override
  JsonObject get arguments => <String, Object?>{'skill_id': skillId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ListRulesCommand implements NodeCommand<List<Rule>> {
  const ListRulesCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_rules';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  List<Rule> decodeReply(Object? okValue) {
    return decodeList(okValue, Rule.fromJson);
  }
}

final class CreateRuleCommand implements NodeCommand<Rule> {
  const CreateRuleCommand({
    required this.workspaceId,
    required this.title,
    required this.details,
    required this.scope,
  });

  final WorkspaceId workspaceId;
  final String title;
  final String details;
  final Scope scope;

  @override
  String get name => 'create_rule';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'title': title,
      'details': details,
      'scope': scope.toJson(),
    };
  }

  @override
  Rule decodeReply(Object? okValue) => Rule.fromJson(okValue);
}

final class UpdateRuleCommand implements NodeCommand<Rule> {
  const UpdateRuleCommand({
    required this.workspaceId,
    required this.ruleId,
    required this.title,
    required this.details,
    required this.scope,
  });

  final WorkspaceId workspaceId;
  final RuleId ruleId;
  final String title;
  final String details;
  final Scope scope;

  @override
  String get name => 'update_rule';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'rule_id': ruleId.value,
      'title': title,
      'details': details,
      'scope': scope.toJson(),
    };
  }

  @override
  Rule decodeReply(Object? okValue) => Rule.fromJson(okValue);
}

final class DeleteRuleCommand implements NodeCommand<void> {
  const DeleteRuleCommand({required this.ruleId});

  final RuleId ruleId;

  @override
  String get name => 'delete_rule';

  @override
  JsonObject get arguments => <String, Object?>{'rule_id': ruleId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class SetRuleEnabledCommand implements NodeCommand<void> {
  const SetRuleEnabledCommand({required this.ruleId, required this.enabled});

  final RuleId ruleId;
  final bool enabled;

  @override
  String get name => 'set_rule_enabled';

  @override
  JsonObject get arguments {
    return <String, Object?>{'rule_id': ruleId.value, 'enabled': enabled};
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ShowAgentsMarkdownCommand
    implements NodeCommand<AgentsMarkdownView> {
  const ShowAgentsMarkdownCommand({
    required this.workspaceId,
    required this.projectId,
  });

  final WorkspaceId workspaceId;
  final ProjectId projectId;

  @override
  String get name => 'show_agents_markdown';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'project_id': projectId.value,
    };
  }

  @override
  AgentsMarkdownView decodeReply(Object? okValue) {
    return AgentsMarkdownView.fromJson(okValue);
  }
}
