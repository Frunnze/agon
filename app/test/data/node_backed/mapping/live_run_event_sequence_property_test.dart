import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';
import 'support/live_run_event_sequences.dart';
import 'support/live_run_views.dart';
import 'support/shared_live_run_cases.dart';

const Duration _pause = Duration(seconds: 1);

List<node.RunEvent> _randomSequence(Random random, Run run) {
  final int length = 1 + random.nextInt(largestSequenceLength);
  return <node.RunEvent>[
    for (int position = 0; position < length; position += 1)
      randomServerEvent(random, run, position),
  ];
}

void _expectConsistentProgress(Run run) {
  expect(run.status, deriveRunStatus(run.steps));
  expect(run.finishedAt != null, isRunFinished(run.status));
  for (final RunStep step in run.steps) {
    expect(step.finishedAt != null, isStepFinished(step.status));
    if (run.status == RunStatus.failed) {
      expect(isStepFinished(step.status), isTrue);
    }
  }
}

void main() {
  test('test_apply_live_run_view_property_sequences_keep_progress_whole', () {
    final Random random = seededRandom(88501);

    for (int i = 0; i < propertyIterations; i += 1) {
      Run run = freshHeldRun(random);
      DateTime at = randomPreciseMoment(random);

      for (final node.RunEvent event in _randomSequence(random, run)) {
        at = at.add(_pause);
        run = applyLiveRunView(
          run: run,
          view: buildLiveView(<node.RunEvent>[event]),
          at: at,
        );

        _expectConsistentProgress(run);
      }
    }
  });

  test('test_apply_live_run_view_property_one_view_equals_event_by_event', () {
    final Random random = seededRandom(88502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run fresh = freshHeldRun(random);
      final List<node.RunEvent> events = _randomSequence(random, fresh);
      final DateTime at = randomPreciseMoment(random);
      Run eventByEvent = fresh;
      for (final node.RunEvent event in events) {
        eventByEvent = applyLiveRunView(
          run: eventByEvent,
          view: buildLiveView(<node.RunEvent>[event]),
          at: at,
        );
      }

      final Run oneView = applyLiveRunView(
        run: fresh,
        view: buildLiveView(events),
        at: at,
      );

      expect(describeWholeRun(oneView), describeWholeRun(eventByEvent));
    }
  });

  test('test_apply_live_run_view_property_new_records_land_once_in_order', () {
    final Random random = seededRandom(88503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run fresh = freshHeldRun(random);
      final List<node.RunEvent> events = _randomSequence(random, fresh);

      final Run applied = applyLiveRunView(
        run: fresh,
        view: buildLiveView(events),
        at: randomPreciseMoment(random),
      );

      final List<String> expectedLines = <String>[
        for (final LogLine line in fresh.log) line.text,
        for (final node.RunEvent event in events)
          if (event is node.LogAppended) event.line.text,
      ];
      final List<String> expectedMessages = <String>[
        for (final ChatMessage message in fresh.chat) message.text,
        for (final node.RunEvent event in events)
          if (event is node.ChatAppended) event.message.text,
      ];
      expect(applied.log.map((LogLine line) => line.text), expectedLines);
      expect(
        applied.chat.map((ChatMessage message) => message.text),
        expectedMessages,
      );
    }
  });

  test('test_wakes_run_for_follow_up_property_your_message_reopens_live', () {
    final Random random = seededRandom(88504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run fresh = freshHeldRun(random);
      final RunStep failing = pickOne(random, fresh.steps);
      final DateTime at = randomPreciseMoment(random);

      final Run woken = applyLiveRunView(
        run: fresh,
        view: buildLiveView(<node.RunEvent>[
          buildFailureEvent(random, failing.name),
          buildNewChatEvent(random, 0, node.ChatAuthor.you),
        ]),
        at: at,
      );

      final RunStep requeued = woken.steps.firstWhere(
        (RunStep step) => step.name == failing.name,
      );
      expect(woken.failure, isNull);
      expect(woken.finishedAt, isNull);
      expect(isRunFinished(woken.status), isFalse);
      expect(requeued.status, StepStatus.waiting);
      expect(requeued.runner, isNull);
      _expectConsistentProgress(woken);
    }
  });

  test('test_is_same_log_line_property_error_flag_tells_lines_apart', () {
    final Random random = seededRandom(88505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final LogLine existing = pickOne(random, run.log);
      final LogLine flipped = LogLine(
        at: existing.at,
        stepName: existing.stepName,
        text: existing.text,
        isError: !existing.isError,
      );

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[buildLogEvent(flipped)]),
        at: randomPreciseMoment(random),
      );

      expect(
        describeLog(applied.log),
        describeLog(<LogLine>[...run.log, flipped]),
      );
    }
  });

  test('test_is_same_chat_message_property_flags_tell_messages_apart', () {
    final Random random = seededRandom(88506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final ChatMessage existing = pickOne(random, run.chat);
      final bool flipsError = random.nextBool();
      final ChatMessage flipped = ChatMessage(
        at: existing.at,
        author: existing.author,
        text: existing.text,
        isError: flipsError ? !existing.isError : existing.isError,
        waitingToSend: flipsError
            ? existing.waitingToSend
            : !existing.waitingToSend,
      );

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[buildChatEvent(flipped)]),
        at: randomPreciseMoment(random),
      );

      expect(
        describeChat(applied.chat),
        describeChat(<ChatMessage>[...run.chat, flipped]),
      );
    }
  });
}
