import 'simulated_node_replies.dart';

const String _workspaceField = 'workspace';
const List<String> _skillFields = <String>[
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
];
const List<String> _ruleFields = <String>['title', 'details', 'scope'];

final class SimulatedLibraryEdits {
  SimulatedLibraryEdits({required this.skills, required this.rules});

  final List<Map<String, Object?>> skills;
  final List<Map<String, Object?>> rules;

  Object? updateSkill(SimulatedCommand command) {
    final Map<String, Object?> skill = findSimulatedRecord(
      skills,
      kind: 'skill',
      identifier: command['skill_id'],
    );
    return _copyFields(command, record: skill, fields: _skillFields);
  }

  Object? deleteSkill(SimulatedCommand command) {
    final Map<String, Object?> skill = findSimulatedRecord(
      skills,
      kind: 'skill',
      identifier: command['skill_id'],
    );
    skills.remove(skill);
    return null;
  }

  Object? updateRule(SimulatedCommand command) {
    final Map<String, Object?> rule = findSimulatedRecord(
      rules,
      kind: 'rule',
      identifier: command['rule_id'],
    );
    return _copyFields(command, record: rule, fields: _ruleFields);
  }

  Object? deleteRule(SimulatedCommand command) {
    final Map<String, Object?> rule = findSimulatedRecord(
      rules,
      kind: 'rule',
      identifier: command['rule_id'],
    );
    rules.remove(rule);
    return null;
  }
}

Map<String, Object?> _copyFields(
  SimulatedCommand command, {
  required Map<String, Object?> record,
  required List<String> fields,
}) {
  for (final String field in fields) {
    record[field] = command[field];
  }

  final Map<String, Object?> reply = Map<String, Object?>.of(record);
  reply.remove(_workspaceField);
  return reply;
}
