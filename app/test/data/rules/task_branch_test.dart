import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/task_branch.dart';

import '../../support/random_inputs.dart';

final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

void main() {
  test('test_slugify_task_title_property_yields_idempotent_safe_slug', () {
    final Random random = seededRandom(31);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = random.nextBool()
          ? randomText(random)
          : randomWordPhrase(random);
      final String slug = slugifyTaskTitle(title);

      expect(_slugPattern.hasMatch(slug), isTrue, reason: title);
      expect(slugifyTaskTitle(slug), slug);
    }
  });

  test('test_describe_task_branch_property_prefixes_slug', () {
    final Random random = seededRandom(32);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomWordPhrase(random);

      expect(describeTaskBranch(title), 'task/${slugifyTaskTitle(title)}');
    }
  });

  test('test_describe_job_run_branch_property_ends_with_run_number', () {
    final Random random = seededRandom(33);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomWordPhrase(random);
      final int runNumber = 1 + random.nextInt(5000);
      final String branch = describeJobRunBranch(title, runNumber);

      expect(branch, startsWith(describeTaskBranch(title)));
      expect(branch, endsWith('-run-$runNumber'));
    }
  });

  test('describe_task_branch matches the gallery run', () {
    expect(describeTaskBranch('Ship release 2.4'), 'task/ship-release-2-4');
  });
}
