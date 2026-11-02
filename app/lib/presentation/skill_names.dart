import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';

List<String> describeSkillNames({
  required List<Skill> skills,
  required List<SkillId> skillIds,
}) {
  return <String>[
    for (final Skill skill in skills)
      if (skillIds.contains(skill.id)) skill.name,
  ];
}

SkillId findSkillIdByName({
  required List<Skill> skills,
  required String skillName,
}) {
  for (final Skill skill in skills) {
    if (skill.name == skillName) {
      return skill.id;
    }
  }
  throw ArgumentError.value(skillName, 'skillName', 'Unknown skill');
}
