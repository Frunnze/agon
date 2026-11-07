import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_inputs.dart';

void main() {
  test(
    'test_keep_container_credential_property_keeps_a_known_claude_login',
    () async {
      final Random random = seededRandom(63407);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: status,
        );
        await repository.openTerminal(AgentPlace.container);
        repository.endTerminal(problem: null);
        await repository.saveApiKey(randomValidApiKey(random));
        await repository.forgetCredential();

        expect(repository.findStatus()?.claudeLogin, status.claudeLogin);
      }
    },
  );

  test(
    'test_keep_container_credential_property_holds_the_newest_credential',
    () async {
      final Random random = seededRandom(63408);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: randomKnownAgentLoginStatus(random),
        );
        AgentCredentialKind? expected = repository
            .findStatus()
            ?.containerCredential;
        final int changes = random.nextInt(6);
        for (int change = 0; change < changes; change += 1) {
          final int choice = random.nextInt(3);
          if (choice == 0) {
            await repository.saveApiKey(randomValidApiKey(random));
            expected = AgentCredentialKind.apiKey;
          } else if (choice == 1) {
            await repository.forgetCredential();
            expected = null;
          } else {
            await repository.openTerminal(AgentPlace.container);
            repository.endTerminal(problem: null);
            expected = AgentCredentialKind.longLivedToken;
          }
        }

        expect(repository.findStatus()?.containerCredential, expected);
      }
    },
  );

  test(
    'test_keep_container_credential_property_notifies_once_per_change',
    () async {
      final Random random = seededRandom(63409);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        await counted.repository.openTerminal(AgentPlace.container);
        final int notificationsBefore = counted.notifications.count;

        counted.repository.endTerminal(problem: null);

        expect(counted.notifications.count, notificationsBefore + 1);
        expect(counted.repository.findTerminal(), isNull);
      }
    },
  );
}
