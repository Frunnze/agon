import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';

import '../support/memory_start_at_login_choice_store.dart';
import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';
import 'support/logged_computer.dart';

typedef _PlannedChange = ({PresenceChange change, DeviceRole role});

const int _firstSeed = 9490050;
const int _largestChangeCount = 6;
const String _plannedFailureMessage = 'planned login item failure';

final class _GatedLoginItem implements LoginItem {
  final List<Completer<void>> gates = <Completer<void>>[];

  @override
  Future<void> register() => _waitForGate();

  @override
  Future<void> unregister() => _waitForGate();

  Future<void> _waitForGate() {
    final Completer<void> gate = Completer<void>();
    gates.add(gate);
    return gate.future;
  }
}

final class _ScriptedLoginItem implements LoginItem {
  _ScriptedLoginItem({required this.failingCallNumbers});

  final Set<int> failingCallNumbers;
  int callCount = 0;

  @override
  Future<void> register() => _answerNextCall();

  @override
  Future<void> unregister() => _answerNextCall();

  Future<void> _answerNextCall() async {
    final int callNumber = callCount;
    callCount += 1;
    if (failingCallNumbers.contains(callNumber)) {
      throw StateError(_plannedFailureMessage);
    }
  }
}

RunnerPresence _buildPresence(LoginItem loginItem, Random random) {
  return RunnerPresence(
    loginItem: loginItem,
    trayPresence: RecordingTrayPresence(),
    startAtLoginChoiceStore: MemoryStartAtLoginChoiceStore(
      isStartAtLoginChosen: random.nextBool(),
    ),
  );
}

Future<void> _startRandomLoginChange(Random random, RunnerPresence presence) {
  if (random.nextBool()) {
    return presence.startAtLogin();
  }
  return presence.stopStartingAtLogin();
}

List<_PlannedChange> _planRandomChanges(Random random) {
  final List<_PlannedChange> plannedChanges = <_PlannedChange>[];
  final int changeCount = 1 + random.nextInt(_largestChangeCount);
  for (int i = 0; i < changeCount; i += 1) {
    plannedChanges.add((
      change: pickOne(random, PresenceChange.values),
      role: pickOne(random, DeviceRole.values),
    ));
  }
  return plannedChanges;
}

Future<void> _letQueuedWorkRun() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'test_run_after_previous_change_property_changes_run_one_at_a_time',
    () async {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _GatedLoginItem loginItem = _GatedLoginItem();
        final RunnerPresence presence = _buildPresence(loginItem, random);
        final int changeCount = 2 + random.nextInt(_largestChangeCount);
        final List<Future<void>> changes = <Future<void>>[];
        for (int change = 0; change < changeCount; change += 1) {
          changes.add(_startRandomLoginChange(random, presence));
        }

        for (int change = 0; change < changeCount; change += 1) {
          await _letQueuedWorkRun();
          expect(loginItem.gates.length, change + 1);
          loginItem.gates[change].complete();
        }
        await Future.wait(changes);
      }
    },
  );

  test(
    'test_run_after_previous_change_property_failures_stay_with_their_call',
    () async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < propertyIterations; i += 1) {
        final int changeCount = 1 + random.nextInt(_largestChangeCount);
        final Set<int> failingCallNumbers = <int>{};
        for (int change = 0; change < changeCount; change += 1) {
          if (random.nextBool()) {
            failingCallNumbers.add(change);
          }
        }
        final _ScriptedLoginItem loginItem = _ScriptedLoginItem(
          failingCallNumbers: failingCallNumbers,
        );
        final RunnerPresence presence = _buildPresence(loginItem, random);
        final List<Future<void>> changes = <Future<void>>[];
        for (int change = 0; change < changeCount; change += 1) {
          changes.add(_startRandomLoginChange(random, presence));
        }

        for (int change = 0; change < changeCount; change += 1) {
          if (failingCallNumbers.contains(change)) {
            await expectLater(changes[change], throwsStateError);
          } else {
            await expectLater(changes[change], completes);
          }
        }
        expect(loginItem.callCount, changeCount);
      }
    },
  );

  test(
    'test_run_after_previous_change_property_unawaited_calls_match_awaited',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < propertyIterations; i += 1) {
        final bool isStartAtLoginChosen = random.nextBool();
        final LoggedComputer queuedComputer = LoggedComputer(
          isStartAtLoginChosen: isStartAtLoginChosen,
        );
        final LoggedComputer awaitedComputer = LoggedComputer(
          isStartAtLoginChosen: isStartAtLoginChosen,
        );
        final RunnerPresence queuedPresence = queuedComputer.presence;
        final RunnerPresence awaitedPresence = awaitedComputer.presence;
        final List<_PlannedChange> plannedChanges = _planRandomChanges(random);
        final List<Future<void>> queuedChanges = <Future<void>>[];

        for (final _PlannedChange plannedChange in plannedChanges) {
          queuedChanges.add(
            applyPresenceChange(
              change: plannedChange.change,
              role: plannedChange.role,
              presence: queuedPresence,
            ),
          );
        }
        for (final _PlannedChange plannedChange in plannedChanges) {
          await applyPresenceChange(
            change: plannedChange.change,
            role: plannedChange.role,
            presence: awaitedPresence,
          );
        }
        await Future.wait(queuedChanges);

        expect(queuedComputer.events, equals(awaitedComputer.events));
        expect(queuedComputer.state, awaitedComputer.state);
      }
    },
  );

  test(
    'test_runner_presence_constructor_property_keeps_every_collaborator',
    () {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < propertyIterations; i += 1) {
        final LoggedComputer computer = LoggedComputer(
          isStartAtLoginChosen: random.nextBool(),
        );
        final RecordingLoginItem loginItem = RecordingLoginItem();
        final RunnerPresence presence = RunnerPresence(
          loginItem: loginItem,
          trayPresence: computer,
          startAtLoginChoiceStore: computer,
        );

        expect(identical(presence.loginItem, loginItem), isTrue);
        expect(identical(presence.trayPresence, computer), isTrue);
        expect(identical(presence.startAtLoginChoiceStore, computer), isTrue);
      }
    },
  );

  test('test_runner_presence_constructor_property_touches_nothing', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoggedComputer computer = LoggedComputer(
        isStartAtLoginChosen: random.nextBool(),
      );
      final PresenceState stateBefore = computer.state;
      final int presenceCount = 1 + random.nextInt(_largestChangeCount);
      for (int presence = 0; presence < presenceCount; presence += 1) {
        expect(computer.presence, isA<RunnerPresence>());
      }

      expect(computer.events, isEmpty);
      expect(computer.state, stateBefore);
    }
  });

  test(
    'test_runner_presence_constructor_property_each_has_its_own_queue',
    () async {
      final Random random = seededRandom(_firstSeed + 5);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _GatedLoginItem loginItem = _GatedLoginItem();
        final int presenceCount = 1 + random.nextInt(_largestChangeCount);
        final List<Future<void>> firstChanges = <Future<void>>[];
        for (int presence = 0; presence < presenceCount; presence += 1) {
          final RunnerPresence newPresence = _buildPresence(loginItem, random);
          firstChanges.add(_startRandomLoginChange(random, newPresence));
          await _letQueuedWorkRun();
          expect(loginItem.gates.length, presence + 1);
        }

        for (final Completer<void> gate in loginItem.gates) {
          gate.complete();
        }
        await Future.wait(firstChanges);
      }
    },
  );
}
