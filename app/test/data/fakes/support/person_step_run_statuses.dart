import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../support/random_inputs.dart';
import '../../../support/workflow_repositories.dart';
import 'person_step_rigs.dart';
import 'task_inputs.dart';

const String _openStepKind = 'open person step';
const List<String> activeRunStatusCodes = <String>[
  'queued',
  'running',
  'waiting_for_approval',
];
const List<String> finishedRunStatusCodes = <String>[
  'done',
  'failed',
  'cancelled',
];

FakePersonStepRepository buildPersonStepsOverRuns(
  List<OpenPersonStep> seeded,
  List<Run> runs,
) {
  final FakeTaskRepository taskRepository = buildTaskRepository(
    tasks: const <Task>[],
    runs: runs,
    workflows: buildGalleryWorkflowRepository(),
  );
  return FakePersonStepRepository(
    openSteps: seeded,
    taskRepository: taskRepository,
  );
}

List<Run> buildRunsWithStatuses(
  Random random,
  List<OpenPersonStep> seeded,
  Map<RunId, String> statuses,
) {
  final List<Run> runs = <Run>[];
  final Set<RunId> builtRunIds = <RunId>{};
  for (final OpenPersonStep openStep in seeded) {
    if (builtRunIds.add(openStep.runId)) {
      final Run run = buildSeededRun(
        random,
        runId: openStep.runId.value,
        taskId: openStep.taskId,
        number: runs.length + 1,
        status: statuses[openStep.runId]!,
      );
      runs.add(run);
    }
  }
  return runs;
}

Map<RunId, String> pickRunStatuses(
  Random random,
  List<OpenPersonStep> seeded,
  List<String> statuses,
) {
  return <RunId, String>{
    for (final RunId runId in listStepRunIds(seeded))
      runId: pickOne(random, statuses),
  };
}

Matcher throwsOpenStepNotFound(OpenPersonStep openStep) {
  return throwsA(
    isA<RecordNotFound>()
        .having((RecordNotFound error) => error.kind, 'kind', _openStepKind)
        .having(
          (RecordNotFound error) => error.identifier,
          'identifier',
          openStep.stepName,
        ),
  );
}
