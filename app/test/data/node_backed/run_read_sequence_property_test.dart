import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed/run_read_sequence.dart';

import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';

const int _largestRunCount = 4;
const int _longestSequence = 30;

Run _buildRun(Random random, {required String runId, required String taskId}) {
  final Map<String, Object?> wire = randomRunJson(random);
  wire['id'] = runId;
  wire['task_id'] = taskId;
  return mapRunFromNode(node.Run.fromJson(wire));
}

List<Run> _randomRuns(Random random) {
  final int count = 1 + random.nextInt(_largestRunCount);
  final List<String> taskIds = <String>['task-a', 'task-b'];
  return <Run>[
    for (int index = 0; index < count; index += 1)
      _buildRun(
        random,
        runId: 'run-$index-${randomText(random)}',
        taskId: pickOne(random, taskIds),
      ),
  ];
}

void main() {
  test('test_run_read_sequence_start_read_property_reads_strictly_grow', () {
    final Random random = seededRandom(51301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      int previousRead = 0;
      final int count = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < count; step += 1) {
        if (random.nextBool()) {
          reads.recordTaskRemoval(TaskId(randomText(random)));
        }
        final int read = reads.startRead();
        expect(read, greaterThan(previousRead));
        previousRead = read;
      }
    }
  });

  test('test_run_read_sequence_start_read_property_fresh_read_is_accepted_'
      'for_every_run', () {
    final Random random = seededRandom(51302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final List<Run> runs = _randomRuns(random);
      final int count = random.nextInt(_longestSequence);
      for (int step = 0; step < count; step += 1) {
        reads.acceptIfNewest(pickOne(random, runs), reads.startRead());
      }

      final int freshRead = reads.startRead();
      for (final Run run in runs) {
        expect(reads.acceptIfNewest(run, freshRead), isTrue);
      }
    }
  });

  test('test_run_read_sequence_start_read_property_numbers_never_repeat', () {
    final Random random = seededRandom(51303);
    final RunReadSequence reads = RunReadSequence();
    final Set<int> seen = <int>{};
    for (int i = 0; i < propertyIterations * 10; i += 1) {
      expect(seen.add(reads.startRead()), isTrue);
      if (random.nextInt(3) == 0) {
        reads.recordTaskRemoval(TaskId(randomText(random)));
      }
    }
  });

  test('test_run_read_sequence_accept_if_newest_property_matches_a_newest_'
      'started_wins_model', () {
    final Random random = seededRandom(51304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final List<Run> runs = _randomRuns(random);
      final Map<RunId, int> newestModel = <RunId, int>{};
      final List<int> startedReads = <int>[];
      final int count = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < count; step += 1) {
        if (startedReads.isEmpty || random.nextBool()) {
          startedReads.add(reads.startRead());
          continue;
        }
        final Run run = pickOne(random, runs);
        final int read = pickOne(random, startedReads);
        final bool isNewest = read > (newestModel[run.id] ?? 0);
        if (isNewest) {
          newestModel[run.id] = read;
        }
        expect(reads.acceptIfNewest(run, read), isNewest);
      }
    }
  });

  test('test_run_read_sequence_accept_if_newest_property_runs_are_'
      'independent', () {
    final Random random = seededRandom(51305);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final int olderRead = reads.startRead();
      final int newerRead = reads.startRead();
      final String taskId = randomText(random);
      final Run first = _buildRun(random, runId: 'first', taskId: taskId);
      final Run second = _buildRun(random, runId: 'second', taskId: taskId);

      expect(reads.acceptIfNewest(first, newerRead), isTrue);
      expect(reads.acceptIfNewest(second, olderRead), isTrue);
      expect(reads.acceptIfNewest(first, olderRead), isFalse);
    }
  });

  test('test_run_read_sequence_accept_if_newest_property_same_read_is_'
      'accepted_once', () {
    final Random random = seededRandom(51306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final Run run = pickOne(random, _randomRuns(random));
      final int read = reads.startRead();
      final int repeats = 1 + random.nextInt(5);

      expect(reads.acceptIfNewest(run, read), isTrue);
      for (int repeat = 0; repeat < repeats; repeat += 1) {
        expect(reads.acceptIfNewest(run, read), isFalse);
      }
    }
  });

  test('test_run_read_sequence_record_task_removal_property_rejects_reads_'
      'started_before_even_for_unseen_runs', () {
    final Random random = seededRandom(51307);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final List<Run> runs = _randomRuns(random);
      final int count = 1 + random.nextInt(_largestRunCount);
      final List<int> earlierReads = <int>[
        for (int step = 0; step < count; step += 1) reads.startRead(),
      ];

      reads.recordTaskRemoval(runs.first.taskId);

      for (final Run run in runs) {
        for (final int read in earlierReads) {
          final bool isOfRemovedTask = run.taskId == runs.first.taskId;
          expect(reads.acceptIfNewest(run, read), isNot(isOfRemovedTask));
        }
      }
    }
  });

  test('test_run_read_sequence_record_task_removal_property_later_reads_are_'
      'accepted', () {
    final Random random = seededRandom(51308);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final Run run = pickOne(random, _randomRuns(random));
      reads.recordTaskRemoval(run.taskId);

      expect(reads.acceptIfNewest(run, reads.startRead()), isTrue);
    }
  });

  test('test_run_read_sequence_record_task_removal_property_leaves_other_'
      'tasks_alone', () {
    final Random random = seededRandom(51309);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunReadSequence reads = RunReadSequence();
      final int read = reads.startRead();
      final Run kept = _buildRun(random, runId: 'kept', taskId: 'kept-task');

      reads.recordTaskRemoval(TaskId('removed-${randomText(random)}'));

      expect(reads.acceptIfNewest(kept, read), isTrue);
    }
  });
}
