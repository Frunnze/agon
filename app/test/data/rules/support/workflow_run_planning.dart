import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import '../../fakes/support/startable_drafts.dart';

const int _largestRunNumber = 500;

Run planWorkflowRun(Random random, Workflow workflow) {
  final TaskDraft draft = replaceDraftDoer(
    randomTaskDraft(random),
    WorkflowDoer(workflow.id),
  );
  final Task task = Task.fromDraft(
    id: TaskId('task-${randomText(random)}'),
    draft: draft,
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
  return createRun(
    runId: RunId('run-${randomText(random)}'),
    task: task,
    workflow: workflow,
    number: 1 + random.nextInt(_largestRunNumber),
    startedBy: GalleryDeviceIds.airLaptop,
    at: randomUtcMoment(random),
  );
}

List<String> listRunStepNames(Run run) {
  final List<String> names = <String>[];
  for (final RunStep step in run.steps) {
    names.add(step.name);
  }
  return names;
}

Workflow shuffleStorageOrder(Random random, Workflow workflow) {
  final List<WorkflowAgent> shuffled = List<WorkflowAgent>.of(workflow.agents);
  shuffled.shuffle(random);
  return workflow.withGraph(
    agents: shuffled,
    connections: workflow.connections,
  );
}
