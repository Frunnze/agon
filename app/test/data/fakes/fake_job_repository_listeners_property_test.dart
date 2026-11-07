import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';
import 'support/job_inputs.dart';
import 'support/notification_counter.dart';
import 'support/startable_drafts.dart';

const int _largestCreationCount = 5;

void main() {
  test('test_add_listener_property_hears_each_job_change_once', () async {
    final Random random = seededRandom(64904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final int changeCount = random.nextInt(_largestCreationCount);
      for (int change = 0; change < changeCount; change += 1) {
        await changeRandomJobValidly(random, counted);
      }

      expect(counted.notifications.count, changeCount);
    }
  });

  test('test_add_listener_property_hears_runs_of_a_job', () async {
    final Random random = seededRandom(64905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        const <Task>[],
      );
      final Task job = await counted.repository.createJob(
        randomStartableJobDraft(random, buildGalleryWorkflowRepository()),
      );

      await counted.taskRepository.startTask(job.id);

      expect(counted.notifications.count, 2);
      expect(counted.repository.findJob(job.id).status, TaskStatus.running);
    }
  });

  test('test_add_listener_property_every_listener_hears_once', () async {
    final Random random = seededRandom(64906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final NotificationCounter second = NotificationCounter();
      counted.repository.addListener(second.record);

      await counted.repository.createJob(randomJobDraft(random));

      expect(counted.notifications.count, 1);
      expect(second.count, 1);
    }
  });

  test('test_remove_listener_property_a_removed_listener_hears_'
      'nothing', () async {
    final Random random = seededRandom(64907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      counted.repository.removeListener(counted.notifications.record);

      final int changeCount = 1 + random.nextInt(_largestCreationCount);
      for (int change = 0; change < changeCount; change += 1) {
        await changeRandomJobValidly(random, counted);
      }

      expect(counted.notifications.count, 0);
    }
  });

  test('test_remove_listener_property_keeps_other_listeners', () async {
    final Random random = seededRandom(64908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final NotificationCounter kept = NotificationCounter();
      counted.repository.addListener(kept.record);
      counted.repository.removeListener(counted.notifications.record);

      await counted.repository.createJob(randomJobDraft(random));

      expect(counted.notifications.count, 0);
      expect(kept.count, 1);
    }
  });

  test('test_remove_listener_property_an_unknown_listener_is_'
      'harmless', () async {
    final Random random = seededRandom(64909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final NotificationCounter stranger = NotificationCounter();

      counted.repository.removeListener(stranger.record);
      await counted.repository.createJob(randomJobDraft(random));

      expect(counted.notifications.count, 1);
      expect(stranger.count, 0);
    }
  });
}
