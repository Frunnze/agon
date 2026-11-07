import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_agent_login_rig.dart';
import '../node_backed/support/simulated_agent_login_node.dart';
import 'support/agent_login_inputs.dart';
import 'support/refusals.dart';

const String _fakePrefix = 'test_fake_agent_login_repository';
const String _nodePrefix = 'test_simulated_agent_login_node';
const String _noLoginProblem = 'no Claude Code login is open';
const String _nodePlaceContainer = 'container';
const String _nodePlaceLocal = 'local_process';
const int _sequenceIterations = 40;

String _randomTypedKeys(Random random) {
  if (random.nextBool()) {
    return '${randomText(random)}$enterKey';
  }
  return randomText(random);
}

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomText(random);
}

String _startCommand(String place) {
  return jsonEncode(<String, Object?>{
    'command': 'start_agent_login',
    'place': place,
  });
}

String _typeCommand(String keys) {
  return jsonEncode(<String, Object?>{
    'command': 'type_agent_login',
    'keys': keys,
  });
}

bool _isFailed(AgentLoginRig rig) {
  return rig.repository.findTerminal()?.state == LoginTerminalState.failed;
}

Object? _readError(String reply) {
  final Object? decoded = jsonDecode(reply);
  if (decoded is! Map<String, Object?>) {
    return null;
  }
  return decoded['error'];
}

void main() {
  test('${_fakePrefix}_type_into_terminal_property_a_failed_login_refuses_'
      'keys', () async {
    final Random random = seededRandom(91201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(
        randomAgentLoginStatus(random),
      );
      await counted.repository.openTerminal(
        pickOne(random, AgentPlace.values),
      );
      counted.repository.endTerminal(problem: randomText(random));
      final LoginTerminal failed = counted.repository.findTerminal()!;
      final int notificationsBefore = counted.notifications.count;

      await expectLater(
        counted.repository.typeIntoTerminal(_randomTypedKeys(random)),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            _noLoginProblem,
          ),
        ),
      );

      expect(counted.repository.findTerminal(), same(failed));
      expect(counted.notifications.count, notificationsBefore);
    }
  });

  test('${_nodePrefix}_type_keys_property_an_ended_login_refuses_keys', () {
    final Random random = seededRandom(91202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SimulatedAgentLoginNode node = SimulatedAgentLoginNode();
      final String place = pickOne(random, <String>[
        _nodePlaceContainer,
        _nodePlaceLocal,
      ]);
      node.answer(_startCommand(place));
      node.finishLogin(problem: _randomProblem(random));
      final Object? endedLogin = node.login;

      final String reply = node.answer(_typeCommand(_randomTypedKeys(random)));

      expect(_readError(reply), _noLoginProblem);
      expect(node.typedKeys, isEmpty);
      expect(node.login, same(endedLogin));
    }
  });

  test('${_fakePrefix}_type_into_terminal_property_agrees_with_the_node_'
      'after_a_failure', () async {
    final Random random = seededRandom(91203);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: quickLoginPolling,
      );
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await fake.openTerminal(place);
      await rig.repository.openTerminal(place);
      final String problem = randomText(random);
      fake.endTerminal(problem: problem);
      rig.node.finishLogin(problem: problem);
      await waitForLogin(() => _isFailed(rig));
      final String keys = _randomTypedKeys(random);

      final bool isFakeRefused = await isRefused(
        () => fake.typeIntoTerminal(keys),
        isRefusal: refusesWithStateError,
      );
      final bool isNodeRefused = await isRefused(
        () => rig.repository.typeIntoTerminal(keys),
        isRefusal: refusesWithStateError,
      );

      expect(isFakeRefused, isTrue);
      expect(isNodeRefused, isTrue);
      expect(rig.node.typedKeys, isEmpty);
      await rig.repository.closeTerminal();
    }
  });
}
