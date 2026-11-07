import 'simulated_deletions.dart';
import 'simulated_node_replies.dart';

const String _personEditKind = 'person_edit';
const List<String> _skillFields = <String>[
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
  'improvement',
];
const List<String> _ruleFields = <String>['title', 'details', 'scope'];

final class SimulatedLibraryEdits {
  SimulatedLibraryEdits({
    required this.skills,
    required this.rules,
    required this.tasks,
  });

  final List<Map<String, Object?>> skills;
  final List<Map<String, Object?>> rules;
  final Map<String, Map<String, Object?>> tasks;

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
    forgetSimulatedSkillsInTasks(tasks, <Object?>{skill['id']});
    return null;
  }

  Object? undoSkillChange(SimulatedCommand command) {
    final Map<String, Object?> skill = findSimulatedRecord(
      skills,
      kind: 'skill',
      identifier: command['skill_id'],
    );
    final List<Object?> history = skill['history']! as List<Object?>;
    if (history.isEmpty) {
      throw const SimulatedNodeFailure('the skill has no agent change');
    }

    final Map<String, Object?> latest = history.last! as Map<String, Object?>;
    final Map<String, Object?> origin =
        latest['origin']! as Map<String, Object?>;
    if (origin['kind'] == _personEditKind) {
      throw const SimulatedNodeFailure('the latest change was not an agent');
    }

    skill['instructions'] = latest['replaced_instructions'];
    skill['history'] = history.sublist(0, history.length - 1);
    return skill;
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
  return record;
}
