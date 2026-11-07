import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_work_node.dart';
import 'support/job_inputs.dart';

const int _sequenceIterations = 30;
const int _longestSequence = 8;
final DateTime _localSummerNoon = DateTime(2026, 7, 1, 12);

typedef _JobPair = ({TaskId fakeId, TaskId nodeId});

final class _Pair {
  _Pair({required this.fake, required this.nodeBacked});

  final FakeJobRepository fake;
  final NodeBackedJobRepository nodeBacked;
  final List<_JobPair> jobs = <_JobPair>[];
}

Future<_Pair> _buildPair() async {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final NodeBackedJobRepository nodeBacked = NodeBackedJobRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
    clock: FixedClock(_localSummerNoon),
  );
  await nodeBacked.load();
  final FakeJobRepository fake = FakeJobRepository(
    taskRepository: buildJobTestTaskRepository(
      const <Task>[],
      moment: _localSummerNoon,
    ),
    clock: FixedClock(_localSummerNoon),
  );
  return _Pair(fake: fake, nodeBacked: nodeBacked);
}

JobDraft _randomWireJobDraft(Random random) {
  return JobDraft(
    task: randomTaskDraft(random),
    schedule: randomSchedule(random),
  );
}

Future<void> _createOnBoth(Random random, _Pair pair) async {
  final JobDraft draft = _randomWireJobDraft(random);

  final Task fromFake = await pair.fake.createJob(draft);
  final Task fromNode = await pair.nodeBacked.createJob(draft);

  pair.jobs.add((fakeId: fromFake.id, nodeId: fromNode.id));
  expect(describeJobContent(fromFake), describeJobContent(fromNode));
}

Future<void> _updateOnBoth(Random random, _Pair pair) async {
  final _JobPair job = pickOne(random, pair.jobs);
  final JobDraft draft = _randomWireJobDraft(random);

  final Task fromFake = await pair.fake.updateJob(job.fakeId, draft);
  final Task fromNode = await pair.nodeBacked.updateJob(job.nodeId, draft);

  expect(describeJobContent(fromFake), describeJobContent(fromNode));
}

Future<void> _deleteOnBoth(Random random, _Pair pair) async {
  final _JobPair job = pickOne(random, pair.jobs);

  await pair.fake.deleteJob(job.fakeId);
  await pair.nodeBacked.deleteJob(job.nodeId);

  pair.jobs.remove(job);
}

Future<void> _changeBoth(Random random, _Pair pair) async {
  final int choice = pair.jobs.isEmpty ? 0 : random.nextInt(3);
  if (choice == 0) {
    await _createOnBoth(random, pair);
  } else if (choice == 1) {
    await _updateOnBoth(random, pair);
  } else {
    await _deleteOnBoth(random, pair);
  }
}

void _expectSameJobs(_Pair pair) {
  expect(pair.fake.listJobs().length, pair.nodeBacked.listJobs().length);
  for (final _JobPair job in pair.jobs) {
    expect(
      describeJobContent(pair.fake.findJob(job.fakeId)),
      describeJobContent(pair.nodeBacked.findJob(job.nodeId)),
    );
  }
}

Future<_Pair> _buildChangedPair(Random random) async {
  final _Pair pair = await _buildPair();
  final int stepCount = 1 + random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await _changeBoth(random, pair);
  }
  return pair;
}

void main() {
  test('test_create_job_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(65101);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildChangedPair(random);

      await _createOnBoth(random, pair);

      _expectSameJobs(pair);
    }
  });

  test('test_update_job_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(65102);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildChangedPair(random);
      if (pair.jobs.isEmpty) {
        continue;
      }

      await _updateOnBoth(random, pair);

      _expectSameJobs(pair);
    }
  });

  test('test_delete_job_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(65103);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildChangedPair(random);
      if (pair.jobs.isEmpty) {
        continue;
      }

      await _deleteOnBoth(random, pair);

      _expectSameJobs(pair);
    }
  });

  test('test_find_job_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(65104);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildChangedPair(random);
      final TaskId unknown = TaskId('unknown-${randomText(random)}');

      _expectSameJobs(pair);
      expect(() => pair.fake.findJob(unknown), throwsA(isA<RecordNotFound>()));
      expect(
        () => pair.nodeBacked.findJob(unknown),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
