import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_follow_ups.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../models/support/random_run_records.dart';
import '../../support/random_inputs.dart';
import 'support/random_progress_runs.dart';

const List<RunStatus> _finishedRunStatuses = <RunStatus>[
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
];

String? _expectedFollowUpStepName(List<RunStep> steps) {
  for (final RunStep step in steps) {
    if (step.status == StepStatus.failed) {
      return step.name;
    }
  }

  RunStep? latest;
  for (final RunStep step in steps) {
    final DateTime? startedAt = step.startedAt;
    if (startedAt == null) {
      continue;
    }
    final DateTime? latestStart = latest?.startedAt;
    if (latestStart == null || !startedAt.isBefore(latestStart)) {
      latest = step;
    }
  }
  return latest?.name;
}

Run _randomFinishedRun(Random random) {
  return buildProgressRun(
    random,
    status: pickOne(random, _finishedRunStatuses),
    steps: randomProgressSteps(random),
  );
}

ChatMessage _messageBy(Random random, ChatAuthor author) {
  final ChatMessage message = randomChatMessage(random);
  return ChatMessage(
    at: message.at,
    author: author,
    text: message.text,
    isError: message.isError,
    waitingToSend: message.waitingToSend,
  );
}

void main() {
  test('test_wakes_run_for_follow_up_property_only_your_messages_wake', () {
    final Random random = seededRandom(88441);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomFinishedRun(random);
      final ChatAuthor author = pickOne(random, <ChatAuthor>[
        ChatAuthor.agent,
        ChatAuthor.tool,
      ]);

      expect(wakesRunForFollowUp(run, _messageBy(random, author)), isFalse);
    }
  });

  test('test_wakes_run_for_follow_up_property_open_runs_never_wake', () {
    final Random random = seededRandom(88442);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomActiveRun(random);
      final ChatAuthor author = pickOne(random, ChatAuthor.values);

      expect(wakesRunForFollowUp(run, _messageBy(random, author)), isFalse);
    }
  });

  test('test_wakes_run_for_follow_up_property_needs_a_step_to_follow', () {
    final Random random = seededRandom(88443);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomFinishedRun(random);
      final ChatMessage message = _messageBy(random, ChatAuthor.you);
      final bool hasStepToFollow =
          _expectedFollowUpStepName(run.steps) != null;

      expect(wakesRunForFollowUp(run, message), hasStepToFollow);
    }
  });

  test(
    'test_reopen_run_for_follow_up_property_requeues_the_followed_step',
    () {
      final Random random = seededRandom(88444);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = _randomFinishedRun(random);
        final String? followedName = _expectedFollowUpStepName(run.steps);
        if (followedName == null) {
          continue;
        }

        final Run reopened = reopenRunForFollowUp(run);

        for (int index = 0; index < run.steps.length; index += 1) {
          final RunStep before = run.steps[index];
          final RunStep after = reopened.steps[index];
          if (before.name != followedName) {
            expect(describeStep(after), describeStep(before));
            continue;
          }
          expect(after.status, StepStatus.waiting);
          expect(after.runner, isNull);
          expect(after.startedAt, isNull);
          expect(after.finishedAt, isNull);
          expect(
            describeStep(after).sublist(6),
            describeStep(before).sublist(6),
          );
        }
      }
    },
  );

  test('test_reopen_run_for_follow_up_property_clears_the_ending', () {
    final Random random = seededRandom(88445);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomFinishedRun(random);
      if (!wakesRunForFollowUp(run, _messageBy(random, ChatAuthor.you))) {
        continue;
      }

      final Run reopened = reopenRunForFollowUp(run);

      expect(reopened.status, deriveRunStatus(reopened.steps));
      expect(reopened.finishedAt, isNull);
      expect(reopened.failure, isNull);
      expect(reopened.chat, run.chat);
      expect(reopened.log, run.log);
      expect(reopened.id, run.id);
    }
  });

  test('test_reopen_run_for_follow_up_property_without_a_step_throws', () {
    final Random random = seededRandom(88446);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomFinishedRun(random);
      if (_expectedFollowUpStepName(run.steps) != null) {
        continue;
      }

      expect(() => reopenRunForFollowUp(run), throwsStateError);
    }
  });
}
