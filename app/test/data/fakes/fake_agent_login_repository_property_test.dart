import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_inputs.dart';
import 'support/agent_login_steps.dart';

const String _typePrefix = 'test_fake_agent_login_repository';

void main() {
  test('${_typePrefix}_constructor_property_keeps_the_given_status', () {
    final Random random = seededRandom(63301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus? status = randomAgentLoginStatus(random);

      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: status,
      );

      expect(identical(repository.findStatus(), status), isTrue);
    }
  });

  test('${_typePrefix}_constructor_property_starts_without_a_terminal', () {
    final Random random = seededRandom(63302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );

      expect(repository.findTerminal(), isNull);
    }
  });

  test(
    '${_typePrefix}_constructor_property_repositories_share_no_state',
    () async {
      final Random random = seededRandom(63303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus? status = randomAgentLoginStatus(random);
        final FakeAgentLoginRepository changed = FakeAgentLoginRepository(
          status: status,
        );
        final FakeAgentLoginRepository untouched = FakeAgentLoginRepository(
          status: status,
        );

        await runRandomLoginSteps(random, changed);

        expect(identical(untouched.findStatus(), status), isTrue);
        expect(untouched.findTerminal(), isNull);
      }
    },
  );

  test(
    '${_typePrefix}_find_status_property_reading_changes_nothing',
    () async {
      final Random random = seededRandom(63304);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        await runRandomLoginSteps(random, counted.repository);
        final int notificationsBefore = counted.notifications.count;
        final AgentLoginStatus? firstRead = counted.repository.findStatus();

        final AgentLoginStatus? secondRead = counted.repository.findStatus();

        expect(identical(secondRead, firstRead), isTrue);
        expect(counted.notifications.count, notificationsBefore);
      }
    },
  );

  test(
    '${_typePrefix}_find_status_property_holds_the_last_credential',
    () async {
      final Random random = seededRandom(63305);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: randomAgentLoginStatus(random),
        );
        await runRandomLoginSteps(random, repository);
        final bool savesKey = random.nextBool();

        if (savesKey) {
          await repository.saveApiKey(randomValidApiKey(random));
        } else {
          await repository.forgetCredential();
        }

        final AgentCredentialKind? expected = savesKey
            ? AgentCredentialKind.apiKey
            : null;
        expect(repository.findStatus()?.containerCredential, expected);
      }
    },
  );

  test('${_typePrefix}_find_status_property_only_a_local_login_changes_'
      'the_claude_login', () async {
    final Random random = seededRandom(63306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: status,
      );
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await repository.openTerminal(place);
      await repository.saveApiKey(randomValidApiKey(random));
      await repository.forgetCredential();

      expect(repository.findStatus()?.claudeLogin, status.claudeLogin);
      repository.endTerminal(problem: null);

      final ClaudeLogin expected = place == AgentPlace.localProcess
          ? ClaudeLogin.loggedIn
          : status.claudeLogin;
      expect(repository.findStatus()?.claudeLogin, expected);
    }
  });
}
