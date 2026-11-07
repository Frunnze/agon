import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/agent_login_inputs.dart';
import '../fakes/support/agent_login_steps.dart';
import '../fakes/support/refusals.dart';
import 'support/node_backed_agent_login_rig.dart';

const String _prefix = 'test_node_backed_agent_login_repository';
const String _statusCommand = 'agent_login_status';
const int _sequenceIterations = 40;

void main() {
  test('${_prefix}_save_api_key_property_refuses_like_the_fake', () async {
    final Random random = seededRandom(75409);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: status,
      );
      final String apiKey = random.nextBool()
          ? randomValidApiKey(random)
          : randomRefusedApiKey(random);

      final bool isNodeRefused = await isRefused(
        () => rig.repository.saveApiKey(apiKey),
        isRefusal: refusesWithStateError,
      );
      final bool isFakeRefused = await isRefused(
        () => fake.saveApiKey(apiKey),
        isRefusal: refusesWithStateError,
      );

      expect(isNodeRefused, isFakeRefused, reason: apiKey);
      expectSameLoginStatus(rig.repository.findStatus(), fake.findStatus());
    }
  });

  test('${_prefix}_save_api_key_property_keeps_the_claude_login', () async {
    final Random random = seededRandom(75410);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);

      await rig.repository.saveApiKey(randomValidApiKey(random));

      final AgentLoginStatus? saved = rig.repository.findStatus();
      expect(saved?.claudeLogin, status.claudeLogin);
      expect(saved?.containerCredential, AgentCredentialKind.apiKey);
    }
  });

  test('${_prefix}_save_api_key_property_saves_then_rechecks', () async {
    final Random random = seededRandom(75411);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );

      await rig.repository.saveApiKey(randomValidApiKey(random));

      expect(rig.node.receivedCommands, <String>[
        'save_agent_api_key',
        _statusCommand,
      ]);
      expect(rig.node.containerCredential, 'api_key');
      expect(rig.notifications.count, 1);
    }
  });

  test('${_prefix}_forget_credential_property_agrees_with_fake', () async {
    final Random random = seededRandom(75412);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: status,
      );

      await rig.repository.forgetCredential();
      await fake.forgetCredential();

      expectSameLoginStatus(rig.repository.findStatus(), fake.findStatus());
      expect(rig.repository.findStatus()?.containerCredential, isNull);
    }
  });

  test('${_prefix}_forget_credential_property_is_idempotent', () async {
    final Random random = seededRandom(75413);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);

      await rig.repository.forgetCredential();
      final AgentLoginStatus? once = rig.repository.findStatus();
      await rig.repository.forgetCredential();

      expectSameLoginStatus(rig.repository.findStatus(), once);
      expect(once?.claudeLogin, status.claudeLogin);
    }
  });

  test(
    '${_prefix}_forget_credential_property_forgets_then_rechecks',
    () async {
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final AgentLoginRig rig = buildAgentLoginRig(
          pollInterval: slowLoginPolling,
        );

        await rig.repository.forgetCredential();

        expect(rig.node.receivedCommands, <String>[
          'forget_agent_credential',
          _statusCommand,
        ]);
        expect(rig.notifications.count, 1);
      }
    },
  );
}
