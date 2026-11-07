import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

void requireValidSkillName(String name) {
  final String? nameProblem = describeNameProblem(name);
  if (nameProblem != null) {
    throw ArgumentError.value(name, 'name', nameProblem);
  }
}

void requireFreeSkillName({
  required String name,
  required List<Skill> otherSkills,
}) {
  for (final Skill skill in otherSkills) {
    if (skill.name == name) {
      throw StateError('A skill named $name already exists');
    }
  }
}
