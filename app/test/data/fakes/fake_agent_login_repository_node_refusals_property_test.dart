import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_agent_login_node.dart';
import 'support/agent_login_inputs.dart';
import 'support/agent_login_steps.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_agent_login_repository';
const Duration _pollInterval = Duration(milliseconds: 1);
const Duration _waitStep = Duration(milliseconds: 1);
const Duration _waitLimit = Duration(seconds: 5);
const int _sequenceIterations = 60;
const int _longestSequence = 6;
const Map<ClaudeLogin, String> _nodeClaudeLogins = <ClaudeLogin, String>{
  ClaudeLogin.loggedIn: 'logged_in',
  ClaudeLogin.notLoggedIn: 'not_logged_in',
  ClaudeLogin.notInstalled: 'not_installed',
};
const Map<AgentCredentialKind, String> _nodeCredentials =
    <AgentCredentialKind, String>{
      AgentCredentialKind.longLivedToken: 'long_lived_token',
      AgentCredentialKind.apiKey: 'api_key',
    };

typedef _Pair = ({
  FakeAgentLoginRepository fake,
  NodeBackedAgentLoginRepository nodeBacked,
  SimulatedAgentLoginNode node,
});

Future<_Pair> _buildPair(Random random) async {
  final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
  final SimulatedAgentLoginNode simulated = SimulatedAgentLoginNode();
  simulated.claudeLogin = _nodeClaudeLogins[status.claudeLogin]!;
  simulated.containerCredential = _nodeCredentials[status.containerCredential];
  final NodeBackedAgentLoginRepository nodeBacked =
      NodeBackedAgentLoginRepository(
        channel: buildSimulatedChannel(simulated.answer),
        pollInterval: _pollInterval,
      );
  await nodeBacked.checkStatus();
  return (
    fake: FakeAgentLoginRepository(status: nodeBacked.findStatus()),
    nodeBacked: nodeBacked,
    node: simulated,
  );
}

String _randomCandidateKey(Random random) {
  if (random.nextBool()) {
    return randomValidApiKey(random);
  }
  return randomHostileText(random);
}

Future<bool> _isKeyRefused(AgentLoginRepository repository, String apiKey) {
  return isRefused(
    () => repository.saveApiKey(apiKey),
    isRefusal: refusesWithStateError,
  );
}

Future<void> _waitUntilFailed(
  NodeBackedAgentLoginRepository repository,
) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (repository.findTerminal()?.state != LoginTerminalState.failed) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the node-backed login never showed the failure');
    }
    await Future<void>.delayed(_waitStep);
  }
}

void main() {
  test('${_typePrefix}_save_api_key_property_refuses_the_keys_the_node_'
      'refuses', () async {
    final Random random = seededRandom(66801);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final String apiKey = _randomCandidateKey(random);

        final bool isFakeRefused = await _isKeyRefused(pair.fake, apiKey);
        final bool isNodeRefused = await _isKeyRefused(
          pair.nodeBacked,
          apiKey,
        );

        expect(isFakeRefused, isNodeRefused, reason: apiKey.runes.toString());
      }
    }
  });

  test('${_typePrefix}_save_api_key_property_statuses_agree_after_any_'
      'keys', () async {
    final Random random = seededRandom(66802);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final String apiKey = _randomCandidateKey(random);
        await _isKeyRefused(pair.fake, apiKey);
        await _isKeyRefused(pair.nodeBacked, apiKey);

        expectSameLoginStatus(
          pair.fake.findStatus(),
          pair.nodeBacked.findStatus(),
        );
      }
    }
  });

  test('${_typePrefix}_end_terminal_property_a_failed_login_cannot_finish_'
      'on_either', () async {
    final Random random = seededRandom(66803);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await pair.fake.openTerminal(place);
      await pair.nodeBacked.openTerminal(place);
      final String problem = randomText(random);
      pair.fake.endTerminal(problem: problem);
      pair.node.finishLogin(problem: problem);
      await _waitUntilFailed(pair.nodeBacked);
      final String? secondProblem = random.nextBool()
          ? null
          : randomText(random);

      expect(
        () => pair.fake.endTerminal(problem: secondProblem),
        throwsStateError,
      );
      expect(
        () => pair.node.finishLogin(problem: secondProblem),
        throwsStateError,
      );

      expect(pair.fake.findTerminal()?.problem, problem);
      expect(pair.node.login?['problem'], problem);
      expectSameLoginStatus(
        pair.fake.findStatus(),
        pair.nodeBacked.findStatus(),
      );
      await pair.fake.closeTerminal();
      await pair.nodeBacked.closeTerminal();
    }
  });
}
