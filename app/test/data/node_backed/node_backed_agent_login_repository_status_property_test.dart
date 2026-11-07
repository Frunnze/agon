import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/agent_login_inputs.dart';
import '../fakes/support/agent_login_steps.dart';
import 'support/node_backed_agent_login_rig.dart';

const String _prefix = 'test_node_backed_agent_login_repository';
const String _statusCommand = 'agent_login_status';
const String _readCommand = 'read_agent_login';
const int _sequenceIterations = 40;
const int _longestSequence = 6;
const Duration _settleTime = Duration(milliseconds: 30);

void main() {
  test('${_prefix}_new_property_starts_unknown_and_sends_nothing', () async {
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await pumpEventQueue();

      expect(rig.repository.findStatus(), isNull);
      expect(rig.repository.findTerminal(), isNull);
      expect(rig.node.receivedCommands, isEmpty);
      expect(rig.notifications.count, 0);
    }
  });

  test('${_prefix}_new_property_poll_interval_paces_following', () async {
    final Random random = seededRandom(75401);
    for (int i = 0; i < 10; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginRig slow = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      final AgentLoginRig quick = buildAgentLoginRig(
        pollInterval: quickLoginPolling,
      );

      await slow.repository.openTerminal(place);
      await quick.repository.openTerminal(place);
      await waitForLogin(
        () => countReceivedCommands(quick.node, _readCommand) >= 3,
      );
      await Future<void>.delayed(_settleTime);

      expect(countReceivedCommands(slow.node, _readCommand), 1);
      await slow.repository.closeTerminal();
      await quick.repository.closeTerminal();
    }
  });

  test('${_prefix}_new_property_repositories_keep_their_own_state', () async {
    final Random random = seededRandom(75402);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig used = await buildCheckedAgentLoginRig(
        randomKnownAgentLoginStatus(random),
      );
      final AgentLoginRig untouched = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );

      await used.repository.saveApiKey(randomValidApiKey(random));
      await used.repository.forgetCredential();

      expect(untouched.repository.findStatus(), isNull);
      expect(untouched.node.receivedCommands, isEmpty);
      expect(untouched.notifications.count, 0);
    }
  });

  test('${_prefix}_find_status_property_mirrors_the_node', () async {
    final Random random = seededRandom(75403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);

      expectSameLoginStatus(rig.repository.findStatus(), status);
    }
  });

  test('${_prefix}_find_status_property_reads_without_the_node', () async {
    final Random random = seededRandom(75404);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(
        randomKnownAgentLoginStatus(random),
      );
      final AgentLoginStatus? first = rig.repository.findStatus();
      final int sentBefore = rig.node.receivedCommands.length;

      final int readCount = 1 + random.nextInt(5);
      for (int read = 0; read < readCount; read += 1) {
        expect(rig.repository.findStatus(), same(first));
      }
      expect(rig.node.receivedCommands.length, sentBefore);
    }
  });

  test('${_prefix}_find_status_property_survives_a_refused_key', () async {
    final Random random = seededRandom(75405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(
        randomKnownAgentLoginStatus(random),
      );
      final AgentLoginStatus? before = rig.repository.findStatus();

      await expectLater(
        rig.repository.saveApiKey(randomRefusedApiKey(random)),
        throwsStateError,
      );

      expect(rig.repository.findStatus(), same(before));
    }
  });

  test('${_prefix}_check_status_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(75406);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: status,
      );

      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextBool()) {
          final String apiKey = randomValidApiKey(random);
          await rig.repository.saveApiKey(apiKey);
          await fake.saveApiKey(apiKey);
        } else {
          await rig.repository.forgetCredential();
          await fake.forgetCredential();
        }
      }
      await rig.repository.checkStatus();
      await fake.checkStatus();

      expectSameLoginStatus(rig.repository.findStatus(), fake.findStatus());
    }
  });

  test('${_prefix}_check_status_property_notifies_once_per_check', () async {
    final Random random = seededRandom(75407);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      final int checkCount = random.nextInt(_longestSequence);

      for (int check = 0; check < checkCount; check += 1) {
        seedNodeLoginStatus(rig.node, randomKnownAgentLoginStatus(random));
        await rig.repository.checkStatus();
      }

      expect(rig.notifications.count, checkCount);
      expect(countReceivedCommands(rig.node, _statusCommand), checkCount);
    }
  });

  test('${_prefix}_check_status_property_late_older_reply_loses', () async {
    final Random random = seededRandom(75408);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginStatus older = randomKnownAgentLoginStatus(random);
      final AgentLoginStatus newer = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      seedNodeLoginStatus(rig.node, older);
      rig.transport.holdNextReply(_statusCommand);

      final Future<void> olderCheck = rig.repository.checkStatus();
      await rig.transport.heldReplyArrival;
      seedNodeLoginStatus(rig.node, newer);
      await rig.repository.checkStatus();
      rig.transport.releaseHeldReply();
      await olderCheck;

      expectSameLoginStatus(rig.repository.findStatus(), newer);
    }
  });
}
