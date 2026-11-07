import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_inputs.dart';
import 'support/agent_login_steps.dart';

const String _typePrefix = 'test_fake_agent_login_repository';
const int _longestSequence = 8;

enum _StatusStep { saveKey, forget, finishContainer, finishLocal }

Future<void> _runStatusStep(
  Random random,
  CountedRepository counted,
  _StatusStep step,
) async {
  switch (step) {
    case _StatusStep.saveKey:
      await counted.repository.saveApiKey(randomValidApiKey(random));
    case _StatusStep.forget:
      await counted.repository.forgetCredential();
    case _StatusStep.finishContainer:
      await counted.repository.openTerminal(AgentPlace.container);
      counted.repository.endTerminal(problem: null);
    case _StatusStep.finishLocal:
      await counted.repository.openTerminal(AgentPlace.localProcess);
      counted.repository.endTerminal(problem: null);
  }
}

void main() {
  test('${_typePrefix}_save_api_key_property_unknown_status_stays_'
      'unknown', () async {
    final Random random = seededRandom(66601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(null);

      await counted.repository.saveApiKey(randomValidApiKey(random));

      expect(counted.repository.findStatus(), isNull);
      expect(counted.notifications.count, 1);
    }
  });

  test('${_typePrefix}_forget_credential_property_unknown_status_stays_'
      'unknown', () async {
    final Random random = seededRandom(66602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(null);
      final int forgettings = 1 + random.nextInt(_longestSequence);

      for (int forgetting = 0; forgetting < forgettings; forgetting += 1) {
        await counted.repository.forgetCredential();
      }

      expect(counted.repository.findStatus(), isNull);
      expect(counted.notifications.count, forgettings);
    }
  });

  test('${_typePrefix}_end_terminal_property_unknown_status_stays_'
      'unknown', () async {
    final Random random = seededRandom(66603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(null);
      await counted.repository.openTerminal(
        pickOne(random, AgentPlace.values),
      );
      final int notificationsBefore = counted.notifications.count;

      counted.repository.endTerminal(problem: null);

      expect(counted.repository.findStatus(), isNull);
      expect(counted.repository.findTerminal(), isNull);
      expect(counted.notifications.count, notificationsBefore + 1);
    }
  });

  test('test_keep_container_credential_property_unknown_status_stays_'
      'unknown_after_any_changes', () async {
    final Random random = seededRandom(66604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(null);
      final int stepCount = random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _runStatusStep(
          random,
          counted,
          pickOne(random, _StatusStep.values),
        );
        expect(counted.repository.findStatus(), isNull);
      }
    }
  });

  test('test_mark_claude_logged_in_property_logs_a_known_status_in', () async {
    final Random random = seededRandom(66605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final CountedRepository counted = buildCountedRepository(status);
      await counted.repository.openTerminal(AgentPlace.localProcess);
      final int notificationsBefore = counted.notifications.count;

      counted.repository.endTerminal(problem: null);

      final AgentLoginStatus? ended = counted.repository.findStatus();
      expect(ended?.claudeLogin, ClaudeLogin.loggedIn);
      expect(ended?.containerCredential, status.containerCredential);
      expect(counted.notifications.count, notificationsBefore + 1);
    }
  });

  test('test_mark_claude_logged_in_property_is_idempotent', () async {
    final Random random = seededRandom(66606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus? status = randomAgentLoginStatus(random);
      final CountedRepository counted = buildCountedRepository(status);
      await _runStatusStep(random, counted, _StatusStep.finishLocal);
      final AgentLoginStatus? onceLoggedIn = counted.repository.findStatus();

      await _runStatusStep(random, counted, _StatusStep.finishLocal);

      final AgentLoginStatus? twiceLoggedIn = counted.repository.findStatus();
      expectSameLoginStatus(twiceLoggedIn, onceLoggedIn);
    }
  });

  test('test_mark_claude_logged_in_property_keeps_unknown_status_'
      'unknown', () async {
    final Random random = seededRandom(66607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(null);
      final int loginCount = 1 + random.nextInt(_longestSequence);

      for (int login = 0; login < loginCount; login += 1) {
        await _runStatusStep(random, counted, _StatusStep.finishLocal);
      }

      expect(counted.repository.findStatus(), isNull);
      expect(counted.repository.findTerminal(), isNull);
    }
  });
}
