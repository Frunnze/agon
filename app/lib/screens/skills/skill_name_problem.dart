import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

String? describeSkillNameProblem({
  required String name,
  required List<Skill> existingSkills,
}) {
  final String? namingProblem = describeNameProblem(name);
  if (namingProblem != null) {
    return namingProblem;
  }

  final bool isTaken = existingSkills.any((Skill skill) => skill.name == name);
  if (isTaken) {
    return 'A skill named $name already exists';
  }
  return null;
}
