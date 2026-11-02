import 'package:agent_orchestration/data/models/library.dart';

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
