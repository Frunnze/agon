import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';

const int _runIdChoiceCount = 4;
const int _longestSequence = 20;

RunId _pickRunId(Random random) {
  return RunId('watched-run-${random.nextInt(_runIdChoiceCount)}');
}

Map<RunId, int> _applyRandomWatchStep(
  Random random,
  FakeTaskRepository repository,
  Map<RunId, int> model,
) {
  final RunId runId = _pickRunId(random);
  final int watchers = model[runId] ?? 0;
  final Map<RunId, int> next = Map<RunId, int>.of(model);

  if (random.nextBool()) {
    repository.watchRun(runId);
    next[runId] = watchers + 1;
    return next;
  }

  repository.stopWatchingRun(runId);
  if (watchers <= 1) {
    next.remove(runId);
    return next;
  }
  next[runId] = watchers - 1;
  return next;
}

void main() {
  test('test_watch_run_property_each_watch_needs_its_own_stop', () {
    final Random random = seededRandom(67201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final RunId runId = _pickRunId(random);
      final int watchCount = 1 + random.nextInt(5);

      for (int watch = 0; watch < watchCount; watch += 1) {
        repository.watchRun(runId);
      }
      for (int stop = 0; stop < watchCount - 1; stop += 1) {
        repository.stopWatchingRun(runId);
        expect(repository.isWatchingRun(runId), isTrue);
      }
      repository.stopWatchingRun(runId);

      expect(repository.isWatchingRun(runId), isFalse);
    }
  });

  test('test_watch_run_property_works_for_runs_not_yet_listed', () {
    final Random random = seededRandom(67202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final RunId unknown = RunId('unknown-${randomText(random)}');

      repository.watchRun(unknown);

      expect(repository.isWatchingRun(unknown), isTrue);
    }
  });

  test('test_watch_run_property_changes_no_record_and_notifies_none', () {
    final Random random = seededRandom(67203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<String> before = describeTasks(repository.listTasksAndJobs());
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);
      Map<RunId, int> model = <RunId, int>{};

      for (int step = 0; step < _longestSequence; step += 1) {
        model = _applyRandomWatchStep(random, repository, model);
      }

      expect(describeTasks(repository.listTasksAndJobs()), before);
      expect(counter.count, 0);
    }
  });

  test('test_stop_watching_run_property_unwatched_runs_stay_unwatched', () {
    final Random random = seededRandom(67204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final RunId runId = _pickRunId(random);
      final int extraStops = random.nextInt(4);

      for (int stop = 0; stop < extraStops; stop += 1) {
        repository.stopWatchingRun(runId);
      }
      repository.watchRun(runId);

      expect(repository.isWatchingRun(runId), isTrue);
    }
  });

  test('test_stop_watching_run_property_only_touches_that_run', () {
    final Random random = seededRandom(67205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final RunId kept = RunId('kept-run-$i');
      final RunId stopped = _pickRunId(random);
      repository.watchRun(kept);
      repository.watchRun(stopped);

      repository.stopWatchingRun(stopped);

      expect(repository.isWatchingRun(kept), isTrue);
      expect(repository.isWatchingRun(stopped), isFalse);
    }
  });

  test('test_stop_watching_run_property_matches_a_counting_model', () {
    final Random random = seededRandom(67206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      Map<RunId, int> model = <RunId, int>{};

      for (int step = 0; step < _longestSequence; step += 1) {
        model = _applyRandomWatchStep(random, repository, model);
      }

      for (int index = 0; index < _runIdChoiceCount; index += 1) {
        final RunId runId = RunId('watched-run-$index');
        expect(repository.isWatchingRun(runId), model.containsKey(runId));
      }
    }
  });

  test('test_is_watching_run_property_false_before_any_watch', () {
    final Random random = seededRandom(67207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      for (final Run run in seed.runs) {
        expect(repository.isWatchingRun(run.id), isFalse);
      }
      expect(repository.isWatchingRun(_pickRunId(random)), isFalse);
    }
  });

  test('test_is_watching_run_property_survives_run_changes', () async {
    final Random random = seededRandom(67208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.runs.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final RunId watched = pickOne(random, seed.runs).id;
      repository.watchRun(watched);

      await repository.createTask(randomSeededTask(random, 0).toDraft());

      expect(repository.isWatchingRun(watched), isTrue);
    }
  });

  test('test_is_watching_run_property_is_idempotent_to_read', () {
    final Random random = seededRandom(67209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      Map<RunId, int> model = <RunId, int>{};
      for (int step = 0; step < _longestSequence; step += 1) {
        model = _applyRandomWatchStep(random, repository, model);
      }
      final RunId runId = _pickRunId(random);

      final bool first = repository.isWatchingRun(runId);
      final bool second = repository.isWatchingRun(runId);

      expect(second, first);
    }
  });
}
