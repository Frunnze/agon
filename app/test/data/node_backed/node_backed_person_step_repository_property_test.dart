import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/person_step.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/person_step_inputs.dart';
import 'support/node_backed_person_step_rig.dart';
import 'support/simulated_node_replies.dart';
import 'support/simulated_work_node.dart';

const String _typePrefix = 'test_node_backed_person_step_repository';
const int _iterations = 60;
const int _largestLoads = 4;

DateTime? _readAskedAt(WireRecord openStep) {
  final Object? askedAt = openStep['asked_at'];
  if (askedAt == null) {
    return null;
  }
  return DateTime.parse(askedAt as String);
}

void _expectSameFields(OpenPersonStep listed, WireRecord openStep) {
  expect(listed.runId.value, openStep['run_id']);
  expect(listed.taskId.value, openStep['task_id']);
  expect(listed.workspaceId.value, openStep['workspace_id']);
  expect(listed.stepName, openStep['step_name']);
  expect(listed.question, openStep['question']);
  expect(listed.choices, orderedEquals(openStep['choices']! as List<Object?>));
  expect(listed.askedAt, _readAskedAt(openStep));
}

void main() {
  test('${_typePrefix}_constructor_property_starts_empty_and_'
      'quiet', () async {
    final Random random = seededRandom(78801);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      rig.askRandomSteps(random);

      await pumpEventQueue();

      expect(rig.repository.listOpenPersonSteps(), isEmpty);
      expect(rig.commandNames, isEmpty);
      expect(rig.notifications.count, 0);
    }
  });

  test('${_typePrefix}_constructor_property_the_first_listing_is_'
      'read_only', () {
    final Random random = seededRandom(78802);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      final List<OpenPersonStep> listed = rig.repository.listOpenPersonSteps();

      expect(
        () => listed.add(randomOpenStep(random, 0)),
        throwsUnsupportedError,
      );
      expect(rig.repository.listOpenPersonSteps(), isEmpty);
    }
  });

  test('${_typePrefix}_constructor_property_repositories_never_share_'
      'steps', () async {
    final Random random = seededRandom(78803);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig first = NodeBackedPersonStepRig();
      final NodeBackedPersonStepRig second = NodeBackedPersonStepRig();
      first.askRandomSteps(random);

      await first.repository.load();

      expect(first.describeListedSteps(), first.describeNodeSteps());
      expect(second.repository.listOpenPersonSteps(), isEmpty);
      expect(second.notifications.count, 0);
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_mirrors_every_'
      'field_in_order', () async {
    final Random random = seededRandom(78804);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      rig.askRandomSteps(random);

      await rig.repository.load();

      final List<OpenPersonStep> listed = rig.repository.listOpenPersonSteps();
      expect(listed, hasLength(rig.simulated.openSteps.length));
      for (int index = 0; index < listed.length; index += 1) {
        _expectSameFields(listed[index], rig.simulated.openSteps[index]);
      }
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_callers_cannot_'
      'change_it', () async {
    final Random random = seededRandom(78805);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      rig.askRandomSteps(random);
      await rig.repository.load();
      final List<OpenPersonStep> listed = rig.repository.listOpenPersonSteps();

      expect(listed.clear, throwsUnsupportedError);
      expect(
        () => listed.add(randomOpenStep(random, 0)),
        throwsUnsupportedError,
      );
      expect(rig.describeListedSteps(), rig.describeNodeSteps());
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_reading_sends_'
      'nothing', () async {
    final Random random = seededRandom(78806);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      rig.askRandomSteps(random);
      await rig.repository.load();
      final int commandsBefore = rig.commandNames.length;
      final List<OpenPersonStep> first = rig.repository.listOpenPersonSteps();
      rig.askRandomSteps(random);

      final List<OpenPersonStep> again = rig.repository.listOpenPersonSteps();

      expect(identical(again, first), isTrue);
      expect(rig.commandNames.length, commandsBefore);
    }
  });

  test('${_typePrefix}_load_property_a_late_older_reply_keeps_the_newer_'
      'listing', () async {
    final Random random = seededRandom(78807);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      rig.askRandomSteps(random);
      rig.transport.holdNextReply(listPersonStepsCommand);
      final Future<void> olderLoad = rig.repository.load();
      await rig.transport.heldReplyArrival;
      rig.askRandomSteps(random);

      await rig.repository.load();
      rig.transport.releaseHeldReply();
      await olderLoad;

      expect(rig.describeListedSteps(), rig.describeNodeSteps());
    }
  });

  test('${_typePrefix}_load_property_a_failure_keeps_the_listing', () async {
    final Random random = seededRandom(78808);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      rig.askRandomSteps(random);
      await rig.repository.load();
      final List<OpenPersonStep> before = rig.repository.listOpenPersonSteps();
      final int notificationsBefore = rig.notifications.count;
      rig.askRandomSteps(random);
      rig.failingCommands.add(listPersonStepsCommand);

      await expectLater(
        rig.repository.load(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            simulatedOutageMessage,
          ),
        ),
      );

      expect(identical(rig.repository.listOpenPersonSteps(), before), isTrue);
      expect(rig.notifications.count, notificationsBefore);
    }
  });

  test('${_typePrefix}_load_property_notifies_once_per_load', () async {
    final Random random = seededRandom(78809);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
      final int loads = 1 + random.nextInt(_largestLoads);

      for (int load = 0; load < loads; load += 1) {
        if (random.nextBool()) {
          rig.askRandomSteps(random);
        }
        await rig.repository.load();
      }

      expect(rig.notifications.count, loads);
      expect(rig.commandNames, everyElement(listPersonStepsCommand));
      expect(rig.describeListedSteps(), rig.describeNodeSteps());
    }
  });
}
