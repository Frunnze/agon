import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

Task removeSkillsFromTask(Task task, Set<SkillId> removedSkillIds) {
  final List<SkillId> keptSkills = <SkillId>[
    for (final SkillId skillId in task.skills)
      if (!removedSkillIds.contains(skillId)) skillId,
  ];
  if (keptSkills.length == task.skills.length) {
    return task;
  }

  final TaskDraft draft = TaskDraft(
    title: task.title,
    details: task.details,
    projectId: task.projectId,
    doer: task.doer,
    runsOn: task.runsOn,
    agentPlace: task.agentPlace,
    skills: keptSkills,
    usesAutomaticSkills: task.usesAutomaticSkills,
    approvalPolicy: task.approvalPolicy,
  );
  return Task.fromDraft(
    id: task.id,
    draft: draft,
    schedule: task.schedule,
    status: task.status,
    createdAt: task.createdAt,
  );
}
