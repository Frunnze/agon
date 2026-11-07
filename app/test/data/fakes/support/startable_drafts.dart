import 'dart:math';

import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import '../../../support/sample_records.dart';
import 'task_inputs.dart';

TaskDraft replaceDraftDoer(TaskDraft draft, TaskDoer doer) {
  return TaskDraft(
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
  );
}

TaskDraft randomStartableTaskDraft(
  Random random,
  WorkflowRepository workflows,
) {
  while (true) {
    final TaskDraft draft = randomTaskDraft(random);
    if (canStartDoer(workflows, draft.doer)) {
      return draft;
    }
  }
}

JobDraft randomStartableJobDraft(Random random, WorkflowRepository workflows) {
  return JobDraft(
    task: randomStartableTaskDraft(random, workflows),
    schedule: randomJobSchedule(random),
  );
}
