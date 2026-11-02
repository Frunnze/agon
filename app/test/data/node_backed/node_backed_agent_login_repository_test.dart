import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_agent_login_node.dart';

const Duration _pollInterval = Duration(milliseconds: 1);
const Duration _waitStep = Duration(milliseconds: 1);
const Duration _waitLimit = Duration(seconds: 5);
const int _terminalIterations = 25;
const Map<String, ClaudeLogin> _claudeLogins = <String, ClaudeLogin>{
  'logged_in': ClaudeLogin.loggedIn,
  'not_logged_in': ClaudeLogin.notLoggedIn,
  'not_installed': ClaudeLogin.notInstalled,
};
const Map<String, AgentCredentialKind> _credentialKinds =
    <String, AgentCredentialKind>{
      'long_lived_token': AgentCredentialKind.longLivedToken,
      'api_key': AgentCredentialKind.apiKey,
    };

typedef _Fixture = ({
  SimulatedAgentLoginNode node,
  NodeBackedAgentLoginRepository repository,
});

_Fixture _buildFixture() {
  final SimulatedAgentLoginNode simulated = SimulatedAgentLoginNode();
  final NodeBackedAgentLoginRepository repository =
      NodeBackedAgentLoginRepository(
        channel: buildSimulatedChannel(simulated.answer),
        pollInterval: _pollInterval,
      );
  return (node: simulated, repository: repository);
}

Future<void> _waitUntil(bool Function() isReached) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (!isReached()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('the repository never caught up with the node');
    }
    await Future<void>.delayed(_waitStep);
  }
}

String _placeWireName(AgentPlace place) {
  return switch (place) {
    AgentPlace.container => 'container',
    AgentPlace.localProcess => 'local_process',
  };
}

void main() {
  test('test_check_status_property_mirrors_the_node', () async {
    final Random random = seededRandom(9301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final String claudeLogin = pickOne(random, _claudeLogins.keys.toList());
      final String? credential = random.nextBool()
          ? null
          : pickOne(random, _credentialKinds.keys.toList());
      fixture.node.claudeLogin = claudeLogin;
      fixture.node.containerCredential = credential;

      await fixture.repository.checkStatus();

      final AgentLoginStatus? status = fixture.repository.findStatus();
      expect(status?.claudeLogin, _claudeLogins[claudeLogin]);
      expect(status?.containerCredential, _credentialKinds[credential]);
    }
  });

  test('test_open_terminal_property_shows_the_login_of_the_place', () async {
    final Random random = seededRandom(9302);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await fixture.repository.openTerminal(place);

      final LoginTerminal? terminal = fixture.repository.findTerminal();
      expect(terminal?.place, place);
      expect(terminal?.state, LoginTerminalState.running);
      expect(terminal?.lines, <String>[loginPrompt]);
      expect(fixture.node.login?['place'], _placeWireName(place));
      await fixture.repository.closeTerminal();
    }
  });

  test('test_type_into_terminal_property_sends_the_keys', () async {
    final Random random = seededRandom(9303);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final String keys = randomText(random);
      await fixture.repository.openTerminal(
        pickOne(random, AgentPlace.values),
      );

      await fixture.repository.typeIntoTerminal(keys);

      expect(fixture.node.typedKeys, <String>[keys]);
      await fixture.repository.closeTerminal();
    }
  });

  test('test_open_terminal_property_a_finished_login_closes', () async {
    final Random random = seededRandom(9304);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await fixture.repository.openTerminal(place);

      fixture.node.finishLogin(problem: null);
      await _waitUntil(() => fixture.repository.findTerminal() == null);
      await _waitUntil(() => fixture.repository.findStatus() != null);

      final AgentLoginStatus? status = fixture.repository.findStatus();
      if (place == AgentPlace.container) {
        expect(
          status?.containerCredential,
          AgentCredentialKind.longLivedToken,
        );
      } else {
        expect(status?.claudeLogin, ClaudeLogin.loggedIn);
      }
      expect(fixture.node.login, isNull);
    }
  });

  test('test_open_terminal_property_a_failed_login_stays_shown', () async {
    final Random random = seededRandom(9305);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final String problem = 'stopped ${randomText(random)}';
      await fixture.repository.openTerminal(
        pickOne(random, AgentPlace.values),
      );

      fixture.node.finishLogin(problem: problem);
      await _waitUntil(
        () =>
            fixture.repository.findTerminal()?.state ==
            LoginTerminalState.failed,
      );

      expect(fixture.repository.findTerminal()?.problem, problem);
      await fixture.repository.closeTerminal();
      expect(fixture.repository.findTerminal(), isNull);
      expect(fixture.node.login, isNull);
    }
  });

  test('test_save_api_key_property_connects_containers_with_it', () async {
    final Random random = seededRandom(9306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final String apiKey = 'sk-ant-${randomText(random)}';

      await fixture.repository.saveApiKey(apiKey);

      expect(
        fixture.repository.findStatus()?.containerCredential,
        AgentCredentialKind.apiKey,
      );
      expect(fixture.node.receivedCommands, contains('save_agent_api_key'));
    }
  });

  test('test_forget_credential_property_disconnects_containers', () async {
    final Random random = seededRandom(9307);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      fixture.node.containerCredential = pickOne(
        random,
        _credentialKinds.keys.toList(),
      );

      await fixture.repository.forgetCredential();

      expect(fixture.repository.findStatus()?.containerCredential, isNull);
    }
  });

  test('test_open_terminal_property_a_second_login_is_refused', () async {
    final _Fixture fixture = _buildFixture();
    await fixture.repository.openTerminal(AgentPlace.container);

    await expectLater(
      fixture.repository.openTerminal(AgentPlace.container),
      throwsA(isA<StateError>()),
    );
    await fixture.repository.closeTerminal();
  });
}
