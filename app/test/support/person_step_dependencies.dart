import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import 'app_harness.dart';

const String questionStepName = 'train';
const String questionText = 'Ship the 2.4 build?';
const String buildResultText = 'Built 2.4 (1180) and uploaded it.';
const List<String> questionChoices = <String>['approved', 'changes'];

final OpenPersonStep galleryOpenQuestion = OpenPersonStep(
  runId: GalleryRunIds.release42,
  taskId: GalleryTaskIds.shipRelease24,
  workspaceId: GalleryWorkspaceIds.acme,
  stepName: questionStepName,
  question: questionText,
  choices: questionChoices,
  askedAt: galleryToday(14, 4),
);

RunStep _withProgress(
  RunStep step, {
  required StepStatus status,
  required String? result,
  required List<EarlierRound> earlierRounds,
}) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: status,
    startedAt: galleryToday(14, 4),
    finishedAt: null,
    result: result,
    outcome: null,
    loopSource: null,
    earlierRounds: earlierRounds,
  );
}

Run buildRunWaitingForYou({required List<RunNote> notes}) {
  final Run base = galleryRunningRun;
  final List<RunStep> steps = <RunStep>[
    base.steps[0],
    _withProgress(
      base.steps[1],
      status: StepStatus.done,
      result: buildResultText,
      earlierRounds: <EarlierRound>[
        EarlierRound(
          status: StepStatus.done,
          startedAt: galleryToday(13, 40),
          finishedAt: galleryToday(13, 46),
          result: 'Built 2.4 (1179) but the icons were wrong.',
          outcome: null,
        ),
      ],
    ),
    _withProgress(
      base.steps[2],
      status: StepStatus.waitingForPerson,
      result: null,
      earlierRounds: const <EarlierRound>[],
    ),
  ];
  return Run(
    id: base.id,
    taskId: base.taskId,
    number: base.number,
    status: RunStatus.running,
    steps: steps,
    log: base.log,
    chat: base.chat,
    failure: null,
    link: base.link,
    linkLostAt: null,
    agentSession: base.agentSession,
    worktreeBranch: base.worktreeBranch,
    startedBy: base.startedBy,
    startedAt: base.startedAt,
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: notes,
  );
}

AppDependencies buildDependenciesWithQuestion({required List<RunNote> notes}) {
  final AppDependencies base = buildGalleryDependencies();
  final List<Run> runs = <Run>[
    buildRunWaitingForYou(notes: notes),
    for (final Run run in galleryRuns)
      if (run.id != GalleryRunIds.release42) run,
  ];

  return replaceRepositories(
    base,
    taskRepository: FakeTaskRepository(
      tasks: <Task>[...galleryTasks, ...galleryJobs],
      runs: runs,
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      workflowRepository: base.workflowRepository,
    ),
    personStepRepository: FakePersonStepRepository(
      openSteps: <OpenPersonStep>[galleryOpenQuestion],
    ),
  );
}
