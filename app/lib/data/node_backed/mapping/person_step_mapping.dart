import 'package:agent_orchestration/bridge/codecs/person_step_values.dart'
    as node;
import 'package:agent_orchestration/data/models/person_step.dart';

OpenPersonStep mapOpenPersonStepFromNode(node.OpenPersonStep openStep) {
  return OpenPersonStep(
    runId: openStep.runId,
    taskId: openStep.taskId,
    workspaceId: openStep.workspaceId,
    stepName: openStep.stepName,
    question: openStep.question,
    choices: openStep.choices,
    askedAt: openStep.askedAt,
  );
}
