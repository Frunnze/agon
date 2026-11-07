import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_agent_login_node.dart';
import 'support/agent_login_inputs.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_agent_login_repository';
const Duration _pollInterval = Duration(milliseconds: 1);
const Duration _waitStep = Duration(milliseconds: 1);
const Duration _waitLimit = Duration(seconds: 5);
const int _sequenceIterations = 40;
const int _longestSequence = 8;
const int _longestTypedLineCount = 3;
const Map<ClaudeLogin, String> _nodeClaudeLogins = <ClaudeLogin, String>{
  ClaudeLogin.loggedIn: 'logged_in',
  ClaudeLogin.notLoggedIn: 'not_logged_in',
  ClaudeLogin.notInstalled: 'not_installed',
  ClaudeLogin.unknown: 'unknown',
};
const Map<AgentCredentialKind, String> _nodeCredentials =
    <AgentCredentialKind, String>{
      AgentCredentialKind.longLivedToken: 'long_lived_token',
      AgentCredentialKind.apiKey: 'api_key',
    };

enum _SharedStep { open, type, close, saveKey, forget, check }

final class _Pair {
  _Pair({required this.fake, required this.nodeBacked, required this.node});

  final FakeAgentLoginRepository fake;
  final NodeBackedAgentLoginRepository nodeBacked;
  final SimulatedAgentLoginNode node;
  int typedKeysAtOpen = 0;
}

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
  return _Pair(
    fake: FakeAgentLoginRepository(status: status),
    nodeBacked: nodeBacked,
    node: simulated,
  );
}

String _randomTypedKeys(Random random) {
  final StringBuffer keys = StringBuffer();
  final int lineCount = 1 + random.nextInt(_longestTypedLineCount);
  for (int line = 0; line < lineCount; line += 1) {
    keys.write('${randomText(random)}$enterKey');
  }
  return keys.toString();
}

Future<void> _runOnBoth(
  _Pair pair,
  Future<void> Function(AgentLoginRepository repository) step,
) async {
  final bool isFakeRefused = await isRefused(
    () => step(pair.fake),
    isRefusal: refusesWithStateError,
  );
  final bool isNodeRefused = await isRefused(
    () => step(pair.nodeBacked),
    isRefusal: refusesWithStateError,
  );

  expect(isFakeRefused, isNodeRefused);
}

Future<void> _runSharedStep(Random random, _Pair pair) async {
  final _SharedStep step = pickOne(random, _SharedStep.values);
  switch (step) {
    case _SharedStep.open:
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final bool isRunning =
          pair.fake.findTerminal()?.state == LoginTerminalState.running;
      if (!isRunning) {
        pair.typedKeysAtOpen = pair.node.typedKeys.length;
      }
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.openTerminal(place),
      );
    case _SharedStep.type:
      final String keys = _randomTypedKeys(random);
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.typeIntoTerminal(keys),
      );
    case _SharedStep.close:
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.closeTerminal(),
      );
    case _SharedStep.saveKey:
      final String apiKey = randomValidApiKey(random);
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.saveApiKey(apiKey),
      );
    case _SharedStep.forget:
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.forgetCredential(),
      );
    case _SharedStep.check:
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.checkStatus(),
      );
  }
}

List<String> _expectedFakeLines(_Pair pair) {
  final List<String> lines = <String>[loginPrompt];
  final List<String> typedKeys = pair.node.typedKeys;
  for (int i = pair.typedKeysAtOpen; i < typedKeys.length; i += 1) {
    final String keys = typedKeys[i];
    final List<String> typedLines = keys.split(enterKey);
    if (keys.endsWith(enterKey)) {
      typedLines.removeLast();
    }
    lines.addAll(typedLines);
  }
  return lines;
}

bool _agree(_Pair pair) {
  final AgentLoginStatus? fakeStatus = pair.fake.findStatus();
  final AgentLoginStatus? nodeStatus = pair.nodeBacked.findStatus();
  final LoginTerminal? fakeTerminal = pair.fake.findTerminal();
  final LoginTerminal? nodeTerminal = pair.nodeBacked.findTerminal();
  final bool isSameStatus =
      fakeStatus?.claudeLogin == nodeStatus?.claudeLogin &&
      fakeStatus?.containerCredential == nodeStatus?.containerCredential;
  final bool isSameTerminal =
      fakeTerminal?.place == nodeTerminal?.place &&
      fakeTerminal?.command == nodeTerminal?.command &&
      fakeTerminal?.state == nodeTerminal?.state &&
      fakeTerminal?.problem == nodeTerminal?.problem;
  return isSameStatus && isSameTerminal;
}

Future<void> _waitUntilAgreeing(_Pair pair) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (!_agree(pair)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the fake and the node-backed login never agreed');
    }
    await Future<void>.delayed(_waitStep);
  }
}

Future<void> _closeBoth(_Pair pair) async {
  await pair.fake.closeTerminal();
  await pair.nodeBacked.closeTerminal();
}

void main() {
  test('${_typePrefix}_open_terminal_property_agrees_with_the_node_'
      'backed_repository', () async {
    final Random random = seededRandom(63601);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _runSharedStep(random, pair);

        expect(_agree(pair), isTrue);
      }

      await _closeBoth(pair);
    }
  });

  test('${_typePrefix}_type_into_terminal_property_shows_the_keys_the_'
      'node_received', () async {
    final Random random = seededRandom(63602);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _runSharedStep(random, pair);
        final LoginTerminal? terminal = pair.fake.findTerminal();
        if (terminal == null) {
          continue;
        }

        expect(terminal.lines, orderedEquals(_expectedFakeLines(pair)));
      }

      await _closeBoth(pair);
    }
  });

  test('${_typePrefix}_end_terminal_property_agrees_with_the_node_when_'
      'the_login_ends', () async {
    final Random random = seededRandom(63603);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await _runOnBoth(
        pair,
        (AgentLoginRepository repository) => repository.openTerminal(place),
      );
      final String? problem = random.nextBool() ? null : randomText(random);

      pair.fake.endTerminal(problem: problem);
      pair.node.finishLogin(problem: problem);
      await _waitUntilAgreeing(pair);

      expect(_agree(pair), isTrue);
      await _closeBoth(pair);
    }
  });
}
