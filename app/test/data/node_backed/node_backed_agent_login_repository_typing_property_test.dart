import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/agent_login_inputs.dart';
import 'support/node_backed_agent_login_rig.dart';

const String _prefix = 'test_node_backed_agent_login_repository';
const String _readCommand = 'read_agent_login';
const int _sequenceIterations = 40;
const int _longestSequence = 8;

void main() {
  test('${_prefix}_type_into_terminal_property_sends_keys_in_order', () async {
    final Random random = seededRandom(75507);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      final int typingCount = random.nextInt(_longestSequence);
      final List<String> typed = <String>[
        for (int typing = 0; typing < typingCount; typing += 1)
          pickOne(random, <String>[randomText(random), enterKey, '']),
      ];

      for (final String keys in typed) {
        await rig.repository.typeIntoTerminal(keys);
      }

      expect(rig.node.typedKeys, typed);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_type_into_terminal_property_refused_when_closed', () async {
    final Random random = seededRandom(75508);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      if (random.nextBool()) {
        await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
        await rig.repository.closeTerminal();
      }
      final String keys = randomText(random);

      await expectLater(
        rig.repository.typeIntoTerminal(keys),
        throwsStateError,
      );
      await expectLater(fake.typeIntoTerminal(keys), throwsStateError);
      expect(rig.repository.findTerminal(), isNull);
      expect(rig.node.typedKeys, isEmpty);
    }
  });

  test('${_prefix}_type_into_terminal_property_rereads_once', () async {
    final Random random = seededRandom(75509);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      final int typingCount = random.nextInt(_longestSequence);

      for (int typing = 0; typing < typingCount; typing += 1) {
        final int notifiedBefore = rig.notifications.count;
        await rig.repository.typeIntoTerminal(randomText(random));

        expect(rig.notifications.count, notifiedBefore + 1);
        expect(rig.node.receivedCommands.last, _readCommand);
      }
      expect(countReceivedCommands(rig.node, _readCommand), 1 + typingCount);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_close_terminal_property_is_idempotent', () async {
    final Random random = seededRandom(75510);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      if (random.nextBool()) {
        await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      }
      final int closeCount = 1 + random.nextInt(3);

      for (int close = 0; close < closeCount; close += 1) {
        await rig.repository.closeTerminal();

        expect(rig.repository.findTerminal(), isNull);
        expect(rig.node.login, isNull);
      }
    }
  });

  test('${_prefix}_close_terminal_property_notifies_once_per_close', () async {
    final Random random = seededRandom(75511);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      final int notifiedBefore = rig.notifications.count;
      final int closeCount = 1 + random.nextInt(3);

      for (int close = 0; close < closeCount; close += 1) {
        await rig.repository.closeTerminal();
      }

      expect(rig.notifications.count, notifiedBefore + closeCount);
    }
  });

  test('${_prefix}_close_terminal_property_late_read_stays_closed', () async {
    final Random random = seededRandom(75512);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      rig.transport.holdNextReply(_readCommand);

      final Future<void> typing = rig.repository.typeIntoTerminal(
        randomText(random),
      );
      await rig.transport.heldReplyArrival;
      await rig.repository.closeTerminal();
      rig.transport.releaseHeldReply();
      await typing;

      expect(rig.repository.findTerminal(), isNull);
      expect(rig.node.login, isNull);
    }
  });
}
