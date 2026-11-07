import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../../support/random_inputs.dart';
import 'workflow_inputs.dart';

WorkflowSignature randomWorkflowSignature(Random random) {
  return WorkflowSignature(
    signedBy: DeviceId(randomText(random)),
    signature: const <int>[7, 7],
    signedDocument: randomText(random),
    signedAt: randomUtcMoment(random),
  );
}

Workflow randomMaybeSignedWorkflow(Random random, int index) {
  final WorkflowSignature? signature = random.nextBool()
      ? randomWorkflowSignature(random)
      : null;
  final Workflow workflow = randomValidWorkflow(
    random,
    index: index,
    signature: signature,
  );
  return workflow.withName(randomText(random));
}

Workflow randomSignedWorkflow(Random random, int index) {
  return randomValidWorkflow(
    random,
    index: index,
    signature: randomWorkflowSignature(random),
  );
}

WorkflowChange randomChangeFor(Random random, WorkflowId workflowId) {
  final WorkflowChange sample = buildSampleChange(workflowId);
  return WorkflowChange(
    workflowId: workflowId,
    changedBy: sample.changedBy,
    changedAt: sample.changedAt,
    summary: sample.summary,
    differences: sample.differences,
    signedDocument: randomText(random),
    changedDocument: randomText(random),
  );
}
