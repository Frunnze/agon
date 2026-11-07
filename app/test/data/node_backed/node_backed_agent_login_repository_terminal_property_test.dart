import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/agent_login_inputs.dart';
import '../fakes/support/refusals.dart';
import 'support/node_backed_agent_login_rig.dart';
import 'support/simulated_agent_login_node.dart';

const String _prefix = 'test_node_backed_agent_login_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 8;

enum _TerminalStep { open, type, close }

void _expectSameTerminal(LoginTerminal? actual, LoginTerminal? expected) {
  expect(actual?.place, expected?.place);
  expect(actual?.command, expected?.command);
  expect(actual?.state, expected?.state);
  expect(actual?.problem, expected?.problem);
}

Future<bool> _isStepRefused(
  Random random,
  _TerminalStep step,
  AgentLoginRepository repository,
) {
  return switch (step) {
    _TerminalStep.open => isRefused(
      () => repository.openTerminal(pickOne(random, AgentPlace.values)),
      isRefusal: refusesWithStateError,
    ),
    _TerminalStep.type => isRefused(
      () => repository.typeIntoTerminal('${randomText(random)}$enterKey'),
      isRefusal: refusesWithStateError,
    ),
    _TerminalStep.close => isRefused(
      repository.closeTerminal,
      isRefusal: refusesWithStateError,
    ),
  };
}

void main() {
  test('${_prefix}_find_terminal_property_none_unless_open', () async {
    final Random random = seededRandom(75501);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      expect(rig.repository.findTerminal(), isNull);

      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      expect(rig.repository.findTerminal(), isNotNull);
      await rig.repository.closeTerminal();

      expect(rig.repository.findTerminal(), isNull);
    }
  });

  test('${_prefix}_find_terminal_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(75502);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );

      await rig.repository.openTerminal(place);
      await fake.openTerminal(place);

      _expectSameTerminal(rig.repository.findTerminal(), fake.findTerminal());
      expect(rig.repository.findTerminal()?.lines, fake.findTerminal()?.lines);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_find_terminal_property_is_a_frozen_snapshot', () async {
    final Random random = seededRandom(75503);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      final LoginTerminal? terminal = rig.repository.findTerminal();
      final int sentBefore = rig.node.receivedCommands.length;

      expect(rig.repository.findTerminal(), same(terminal));
      expect(() => terminal?.lines.add(loginPrompt), throwsUnsupportedError);
      expect(rig.node.receivedCommands.length, sentBefore);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_open_terminal_property_refusals_agree_with_fake', () async {
    final Random random = seededRandom(75504);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      final FakeAgentLoginRepository fake = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      final int stepCount = random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final _TerminalStep chosen = pickOne(random, _TerminalStep.values);
        final int stepSeed = random.nextInt(1 << 30);
        final bool isNodeRefused = await _isStepRefused(
          Random(stepSeed),
          chosen,
          rig.repository,
        );
        final bool isFakeRefused = await _isStepRefused(
          Random(stepSeed),
          chosen,
          fake,
        );

        expect(isNodeRefused, isFakeRefused, reason: chosen.name);
        _expectSameTerminal(
          rig.repository.findTerminal(),
          fake.findTerminal(),
        );
      }
      await rig.repository.closeTerminal();
    }
  });

  test(
    '${_prefix}_open_terminal_property_second_open_keeps_the_first',
    () async {
      final Random random = seededRandom(75505);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final AgentPlace firstPlace = pickOne(random, AgentPlace.values);
        final AgentLoginRig rig = buildAgentLoginRig(
          pollInterval: slowLoginPolling,
        );
        await rig.repository.openTerminal(firstPlace);
        final LoginTerminal? first = rig.repository.findTerminal();

        await expectLater(
          rig.repository.openTerminal(pickOne(random, AgentPlace.values)),
          throwsStateError,
        );

        expect(rig.repository.findTerminal(), same(first));
        expect(first?.place, firstPlace);
        await rig.repository.closeTerminal();
      }
    },
  );

  test('${_prefix}_open_terminal_property_reopens_after_a_failure', () async {
    final Random random = seededRandom(75506);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: quickLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      rig.node.finishLogin(problem: 'failed ${randomText(random)}');
      await waitForLogin(
        () =>
            rig.repository.findTerminal()?.state == LoginTerminalState.failed,
      );
      final AgentPlace secondPlace = pickOne(random, AgentPlace.values);

      await rig.repository.openTerminal(secondPlace);

      final LoginTerminal? reopened = rig.repository.findTerminal();
      expect(reopened?.place, secondPlace);
      expect(reopened?.state, LoginTerminalState.running);
      expect(reopened?.problem, isNull);
      expect(reopened?.command, nodeLoginCommands[secondPlace]);
      await rig.repository.closeTerminal();
    }
  });
}
