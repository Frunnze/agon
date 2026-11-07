import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/place_offers.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/sample_records.dart';
import '../support/sample_runners.dart';
import 'task_form_screen_test.dart' show fillGalleryTask, openNewTaskForm;

const DeviceId _thisDeviceId = GalleryDeviceIds.airLaptop;

Run _withSteps(Run base, RunStatus status, List<RunStep> steps) {
  return Run(
    id: base.id,
    taskId: base.taskId,
    number: base.number,
    status: status,
    steps: steps,
    log: base.log,
    chat: base.chat,
    failure: null,
    link: base.link,
    linkLostAt: base.linkLostAt,
    agentSession: base.agentSession,
    worktreeBranch: base.worktreeBranch,
    startedBy: base.startedBy,
    startedAt: base.startedAt,
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: const <RunNote>[],
  );
}

Run _waitingRun(Run base) {
  return _withSteps(base, RunStatus.queued, <RunStep>[
    for (final RunStep step in base.steps)
      RunStep(
        name: step.name,
        agentId: step.agentId,
        runner: null,
        status: StepStatus.waiting,
        startedAt: null,
        finishedAt: null,
        result: null,
        outcome: null,
        loopSource: null,
        earlierRounds: const <EarlierRound>[],
      ),
  ]);
}

Run _randomRun(Random random) {
  final Run base = pickOne(random, galleryRuns);
  if (random.nextBool()) {
    return _waitingRun(base);
  }
  return base;
}

Runner _randomOfferingRunner(Random random) {
  final Runner base = randomRunner(random);
  return Runner(
    deviceId: base.deviceId,
    labels: base.labels,
    slotsTotal: base.slotsTotal,
    slotsBusy: base.slotsBusy,
    link: base.link,
    online: base.online,
    acceptingNewRuns: base.acceptingNewRuns,
    offers: <AgentPlace>[
      for (final AgentPlace place in AgentPlace.values)
        if (random.nextBool()) place,
    ],
    allowedHosts: base.allowedHosts,
  );
}

bool _expectsWaitingForPlace(Run run, AgentPlace place, List<Runner> runners) {
  final bool hasUnclaimedStep = run.steps.any(
    (RunStep step) => step.status == StepStatus.waiting && step.runner == null,
  );
  final bool hasWorkingStep = run.steps.any(
    (RunStep step) =>
        step.status == StepStatus.running ||
        step.status == StepStatus.waitingForApproval,
  );
  final bool isOffered = runners.any(
    (Runner runner) => runner.online && runner.offers.contains(place),
  );
  return isRunActive(run) && hasUnclaimedStep && !hasWorkingStep && !isOffered;
}

Task _placedTask(Task task, AgentPlace place) {
  final TaskDraft draft = task.toDraft();
  return Task.fromDraft(
    id: task.id,
    draft: TaskDraft(
      title: draft.title,
      details: draft.details,
      projectId: draft.projectId,
      doer: draft.doer,
      runsOn: draft.runsOn,
      agentPlace: place,
      skills: draft.skills,
      usesAutomaticSkills: draft.usesAutomaticSkills,
      approvalPolicy: draft.approvalPolicy,
    ),
    schedule: task.schedule,
    status: task.status,
    createdAt: task.createdAt,
  );
}

Future<void> _openRun(
  WidgetTester tester, {
  required Run run,
  required AgentPlace place,
  required List<Runner> runners,
}) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final List<Task> tasks = <Task>[
    for (final Task task in <Task>[...galleryTasks, ...galleryJobs])
      if (task.id == run.taskId) _placedTask(task, place) else task,
  ];
  final List<Run> runs = <Run>[
    for (final Run galleryRun in galleryRuns)
      if (galleryRun.id == run.id) run else galleryRun,
  ];
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: TaskRunRoute(run.id),
    dependencies: replaceRepositories(
      dependencies,
      taskRepository: FakeTaskRepository(
        tasks: tasks,
        runs: runs,
        clock: dependencies.clock,
        currentDeviceId: _thisDeviceId,
        workflowRepository:
            dependencies.workflowRepository as FakeWorkflowRepository,
      ),
      runnerRepository: FakeRunnerRepository(
        runners: runners,
        thisDeviceOffers: null,
        thisRunnerProblem: null,
      ),
    ),
  );
}

void main() {
  test(
    'test_is_waiting_for_place_property_only_unclaimed_runs_nobody_offers',
    () {
      final Random random = seededRandom(20301);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = _randomRun(random);
        final AgentPlace place = pickOne(random, AgentPlace.values);
        final List<Runner> runners = <Runner>[
          for (int index = 0; index < random.nextInt(4); index += 1)
            _randomOfferingRunner(random),
        ];

        final bool isWaiting = isWaitingForPlace(
          run: run,
          place: place,
          runners: runners,
        );

        expect(isWaiting, _expectsWaitingForPlace(run, place, runners));
      }
    },
  );

  test(
    'test_is_place_offered_property_needs_an_online_runner_offering_it',
    () {
      final Random random = seededRandom(20302);
      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentPlace place = pickOne(random, AgentPlace.values);
        final List<Runner> runners = <Runner>[
          for (int index = 0; index < random.nextInt(4); index += 1)
            _randomOfferingRunner(random),
        ];

        final bool isOffered = isPlaceOffered(place: place, runners: runners);

        final bool expected = runners.any(
          (Runner runner) => runner.online && runner.offers.contains(place),
        );
        expect(isOffered, expected);
      }
    },
  );

  test('test_task_form_values_property_new_tasks_run_on_the_computer', () {
    final Random random = seededRandom(20303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);

      final TaskFormValues blank = TaskFormValues.blank(
        projectId: draft.projectId,
        doer: draft.doer,
        repeat: pickOne(random, RepeatChoice.values),
      );
      final TaskFormValues placed = blank.copyWith(
        agentPlace: draft.agentPlace,
      );

      expect(blank.agentPlace, defaultAgentPlace);
      expect(blank.toTaskDraft().agentPlace, AgentPlace.localProcess);
      expect(placed.toTaskDraft().agentPlace, draft.agentPlace);
    }
  });

  test('test_task_form_values_property_an_edited_task_keeps_its_place', () {
    final Random random = seededRandom(20304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _placedTask(
        pickOne(random, galleryTasks),
        pickOne(random, AgentPlace.values),
      );

      final TaskFormValues values = TaskFormValues.fromTask(task);

      expect(values.toTaskDraft().agentPlace, task.agentPlace);
    }
  });

  testWidgets('test_task_run_screen_property_says_when_nobody_offers_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(20305);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Run run = _randomRun(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final List<Runner> runners = <Runner>[
        for (int index = 0; index < random.nextInt(3); index += 1)
          _randomOfferingRunner(random),
      ];

      await _openRun(tester, run: run, place: place, runners: runners);

      final bool isWaiting = _expectsWaitingForPlace(run, place, runners);
      final Matcher shown = isWaiting ? findsOneWidget : findsNothing;
      expect(find.text(describeMissingPlaceTitle(place)), shown);
      expect(find.text(describeMissingPlaceDetail(place)), shown);
    }
  });

  testWidgets('test_task_form_property_the_chosen_place_is_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(20306);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AppDependencies dependencies = buildGalleryDependencies();
      await tester.pumpWidget(const SizedBox.shrink());
      await openNewTaskForm(tester, desktopSize, dependencies);
      await fillGalleryTask(tester);
      expect(find.text(agentPlaceTitle), findsOneWidget);
      expect(find.text(taskPlaceHint), findsOneWidget);
      expect(find.text(describeTaskPlace(defaultAgentPlace)), findsOneWidget);

      final Finder placeField = find.byType(SelectField<AgentPlace>);
      tester.widget<SelectField<AgentPlace>>(placeField).onChanged(place);
      await pumpFrames(tester);
      await tester.ensureVisible(find.text('Save for later'));
      await tester.tap(find.text('Save for later'));
      await pumpFrames(tester);

      final Task created = dependencies.taskRepository.listTasks().first;
      expect(created.agentPlace, place);
    }
  });
}
