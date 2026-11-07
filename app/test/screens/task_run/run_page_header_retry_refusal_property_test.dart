import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import 'support/retry_refusing_task_repository.dart';
import 'support/run_page_retry_harness.dart';

const RunId _shownRunId = GalleryRunIds.release41;
const String _shownRunLabel = 'release #41';
const String _recordKind = 'run';
const int _largestRetryRounds = 3;
const SectionRoute _tasksRoute = SectionRoute(AppSection.tasks);

typedef _Refusal = ({Object problem, String explanation});

_Refusal _randomRefusal(Random random) {
  final String reason = randomRefusalReason(random);
  final RandomRefusal serverRefusal = randomRefusalWithReason(random, reason);
  final List<_Refusal> refusals = <_Refusal>[
    (problem: StateError(reason), explanation: reason),
    (
      problem: AppServerRefusal(status: serverRefusal.status, reason: reason),
      explanation: reason,
    ),
    (
      problem: RecordNotFound(kind: _recordKind, identifier: reason),
      explanation: 'No $_recordKind with id $reason',
    ),
  ];
  return pickOne(random, refusals);
}

AppDependencies _buildRefusingDependencies({
  required Object refusal,
  required Future<void> refusalArrival,
}) {
  final AppDependencies gallery = buildGalleryDependencies();
  final RetryRefusingTaskRepository refusing = RetryRefusingTaskRepository(
    stored: gallery.taskRepository,
    refusal: refusal,
    refusalArrival: refusalArrival,
  );
  return replaceRepositories(gallery, taskRepository: refusing);
}

void _expectRefusalShown(String explanation) {
  expect(find.text(_shownRunLabel), findsWidgets);
  expect(find.text(retryRefusalTitle), findsOneWidget);
  expect(find.text(explanation), findsOneWidget);
  expect(findAppButton(closeButtonLabel), findsOneWidget);
}

void main() {
  testWidgets('test_retry_run_property_a_refusal_shows_its_reason_until_'
      'closed', (WidgetTester tester) async {
    final Random random = seededRandom(78201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _Refusal refusal = _randomRefusal(random);
      final AppDependencies dependencies = _buildRefusingDependencies(
        refusal: refusal.problem,
        refusalArrival: Future<void>.value(),
      );
      final TaskRepository tasks = dependencies.taskRepository;
      final AppNavigation navigation = await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: _shownRunId,
      );

      await tapAppButton(tester, retryButtonLabel);

      expect(tester.takeException(), isNull);
      _expectRefusalShown(refusal.explanation);
      await tapAppButton(tester, closeButtonLabel);
      expect(find.text(retryRefusalTitle), findsNothing);
      expect(navigation.routes, const <AppRoute>[TaskRunRoute(_shownRunId)]);
      expect(tasks.findRun(_shownRunId).status, RunStatus.failed);
      expect(isRetryOffered(tester), isTrue);
    }
  });

  testWidgets('test_retry_run_property_each_refused_retry_shows_one_'
      'dialog', (WidgetTester tester) async {
    final Random random = seededRandom(78202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _Refusal refusal = _randomRefusal(random);
      final AppDependencies dependencies = _buildRefusingDependencies(
        refusal: refusal.problem,
        refusalArrival: Future<void>.value(),
      );
      final RetryRefusingTaskRepository tasks =
          dependencies.taskRepository as RetryRefusingTaskRepository;
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: _shownRunId,
      );
      final int rounds = 1 + random.nextInt(_largestRetryRounds);

      for (int round = 0; round < rounds; round += 1) {
        await tapAppButton(tester, retryButtonLabel);
        expect(find.text(retryRefusalTitle), findsOneWidget);
        await tapAppButton(tester, closeButtonLabel);
      }

      expect(tester.takeException(), isNull);
      expect(tasks.retryAttempts, rounds);
      expect(find.text(retryRefusalTitle), findsNothing);
    }
  });

  testWidgets('test_retry_run_property_a_start_racing_the_tap_is_'
      'explained', (WidgetTester tester) async {
    final Random random = seededRandom(78203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final Task task = tasks.findTask(tasks.findRun(_shownRunId).taskId);
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: _shownRunId,
      );

      final Run racingRun = await tasks.startTask(task.id);
      await tester.tap(findAppButton(retryButtonLabel));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      _expectRefusalShown('the task is already running');
      await tapAppButton(tester, closeButtonLabel);
      expect(tasks.findRun(_shownRunId).status, RunStatus.failed);
      expect(tasks.findRun(racingRun.id).status, racingRun.status);
      expect(isRetryOffered(tester), isFalse);
    }
  });

  testWidgets('test_retry_run_property_a_late_refusal_is_never_lost', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(78204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _Refusal refusal = _randomRefusal(random);
      final Completer<void> arrival = Completer<void>();
      final AppDependencies dependencies = _buildRefusingDependencies(
        refusal: refusal.problem,
        refusalArrival: arrival.future,
      );
      final AppNavigation navigation = await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: _shownRunId,
      );
      await tapAppButton(tester, retryButtonLabel);
      final bool leavesFirst = random.nextBool();
      if (leavesFirst) {
        navigation.returnTo(_tasksRoute);
        await pumpFrames(tester);
      }

      arrival.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      _expectRefusalShown(refusal.explanation);
      await tapAppButton(tester, closeButtonLabel);
      expect(find.text(retryRefusalTitle), findsNothing);
    }
  });

  testWidgets('test_retry_run_property_unexplained_problems_are_not_'
      'hidden', (WidgetTester tester) async {
    final Random random = seededRandom(78205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = _buildRefusingDependencies(
        refusal: FormatException(randomRefusalReason(random)),
        refusalArrival: Future<void>.value(),
      );
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: _shownRunId,
      );

      final List<Object> escapedProblems = <Object>[];
      await runZonedGuarded(
        () => tapAppButton(tester, retryButtonLabel),
        (Object problem, StackTrace _) => escapedProblems.add(problem),
      );

      expect(escapedProblems, <Matcher>[isA<FormatException>()]);
      expect(find.text(retryRefusalTitle), findsNothing);
    }
  });
}
