import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum DraftKind implements WireNamed {
  task('task'),
  job('job'),
  skill('skill'),
  rule('rule');

  const DraftKind(this.wireName);

  @override
  final String wireName;

  static DraftKind decode(Object? json) => decodeWireName(values, json);
}

const String _kindField = 'kind';

sealed class ItemDraft implements JsonEncodable {
  const ItemDraft();

  factory ItemDraft.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final DraftKind kind = readField(fields, _kindField, DraftKind.decode);
    return switch (kind) {
      DraftKind.task ||
      DraftKind.job => WorkItemDraft.fromFields(kind, fields),
      DraftKind.skill => SkillItemDraft.fromFields(fields),
      DraftKind.rule => RuleItemDraft.fromFields(fields),
    };
  }
}

final class WorkItemDraft extends ItemDraft {
  WorkItemDraft({
    required this.kind,
    required this.title,
    required this.details,
    required this.projectId,
    required this.doer,
    required this.runsOn,
    required this.agentPlace,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
    required this.schedule,
  }) : skills = List<SkillId>.unmodifiable(skills);

  factory WorkItemDraft.fromFields(DraftKind kind, JsonObject fields) {
    return WorkItemDraft(
      kind: kind,
      title: readField(fields, 'title', decodeText),
      details: readField(fields, 'details', decodeText),
      projectId: readOptionalField(fields, 'project_id', decodeProjectId),
      doer: readField(fields, 'doer', TaskDoer.fromJson),
      runsOn: readField(fields, 'runs_on', RunnerTarget.fromJson),
      agentPlace: readField(fields, 'agent_place', AgentPlace.decode),
      skills: readListField(fields, 'skills', decodeSkillId),
      usesAutomaticSkills: readField(
        fields,
        'uses_automatic_skills',
        decodeFlag,
      ),
      approvalPolicy: readOptionalField(
        fields,
        'approval_policy',
        ApprovalPolicy.decode,
      ),
      schedule: readOptionalField(fields, 'schedule', Schedule.fromJson),
    );
  }

  final DraftKind kind;
  final String title;
  final String details;
  final ProjectId? projectId;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final AgentPlace agentPlace;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy? approvalPolicy;
  final Schedule? schedule;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: kind.wireName,
      'title': title,
      'details': details,
      'project_id': projectId?.value,
      'doer': doer.toJson(),
      'runs_on': runsOn.toJson(),
      'agent_place': agentPlace.wireName,
      'skills': <String>[for (final SkillId skill in skills) skill.value],
      'uses_automatic_skills': usesAutomaticSkills,
      'approval_policy': approvalPolicy?.wireName,
      'schedule': schedule?.toJson(),
    };
  }
}

final class SkillItemDraft extends ItemDraft {
  const SkillItemDraft({
    required this.name,
    required this.summary,
    required this.instructions,
    required this.scope,
    required this.usage,
    required this.improvement,
  });

  factory SkillItemDraft.fromFields(JsonObject fields) {
    return SkillItemDraft(
      name: readField(fields, 'name', decodeText),
      summary: readField(fields, 'summary', decodeText),
      instructions: readField(fields, 'instructions', decodeText),
      scope: readField(fields, 'scope', Scope.fromJson),
      usage: readField(fields, 'usage', SkillUsage.decode),
      improvement: readField(fields, 'improvement', SkillImprovement.decode),
    );
  }

  final String name;
  final String summary;
  final String instructions;
  final Scope scope;
  final SkillUsage usage;
  final SkillImprovement improvement;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: DraftKind.skill.wireName,
      'name': name,
      'summary': summary,
      'instructions': instructions,
      'scope': scope.toJson(),
      'usage': usage.wireName,
      'improvement': improvement.wireName,
    };
  }
}

final class RuleItemDraft extends ItemDraft {
  const RuleItemDraft({
    required this.title,
    required this.details,
    required this.scope,
  });

  factory RuleItemDraft.fromFields(JsonObject fields) {
    return RuleItemDraft(
      title: readField(fields, 'title', decodeText),
      details: readField(fields, 'details', decodeText),
      scope: readField(fields, 'scope', Scope.fromJson),
    );
  }

  final String title;
  final String details;
  final Scope scope;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: DraftKind.rule.wireName,
      'title': title,
      'details': details,
      'scope': scope.toJson(),
    };
  }
}

sealed class ItemDraftStatus implements JsonEncodable {
  const ItemDraftStatus();

  factory ItemDraftStatus.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String state = readField(fields, 'state', decodeText);
    return switch (state) {
      ItemDraftWorking.state => const ItemDraftWorking(),
      ItemDraftDone.state => ItemDraftDone(
        draft: readField(fields, 'draft', ItemDraft.fromJson),
        problems: readListField(fields, 'problems', decodeText),
      ),
      _ => throw FormatException('unknown item draft state $state'),
    };
  }
}

final class ItemDraftWorking extends ItemDraftStatus {
  const ItemDraftWorking();

  static const String state = 'working';

  @override
  JsonObject toJson() => <String, Object?>{'state': state};
}

final class ItemDraftDone extends ItemDraftStatus {
  ItemDraftDone({required this.draft, required List<String> problems})
    : problems = List<String>.unmodifiable(problems);

  static const String state = 'done';

  final ItemDraft draft;
  final List<String> problems;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'state': state,
      'draft': draft.toJson(),
      'problems': problems,
    };
  }
}
