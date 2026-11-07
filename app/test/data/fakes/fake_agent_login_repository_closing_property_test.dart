import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_inputs.dart';
import 'support/agent_login_steps.dart';

const String _typePrefix = 'test_fake_agent_login_repository';
const int _longestTyping = 6;

void main() {
  test(
    '${_typePrefix}_close_terminal_property_removes_any_terminal',
    () async {
      final Random random = seededRandom(63508);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus? status = randomAgentLoginStatus(random);
        final FakeAgentLoginRepository repository = random.nextBool()
            ? await buildRepositoryWithFailedLogin(random)
            : FakeAgentLoginRepository(status: status);
        if (random.nextBool()) {
          await repository.closeTerminal();
          await repository.openTerminal(pickOne(random, AgentPlace.values));
        }
        final AgentLoginStatus? statusBefore = repository.findStatus();

        await repository.closeTerminal();

        expect(repository.findTerminal(), isNull);
        expectSameLoginStatus(repository.findStatus(), statusBefore);
      }
    },
  );

  test('${_typePrefix}_close_terminal_property_is_idempotent', () async {
    final Random random = seededRandom(63509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRepository counted = buildCountedRepository(
        randomAgentLoginStatus(random),
      );
      final int closings = 1 + random.nextInt(_longestTyping);

      for (int closing = 0; closing < closings; closing += 1) {
        await counted.repository.closeTerminal();
      }

      expect(counted.repository.findTerminal(), isNull);
      expect(counted.notifications.count, closings);
    }
  });

  test('${_typePrefix}_close_terminal_property_allows_a_new_login', () async {
    final Random random = seededRandom(63510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      await repository.openTerminal(pickOne(random, AgentPlace.values));
      await repository.closeTerminal();
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await repository.openTerminal(place);

      expect(repository.findTerminal()?.place, place);
      expect(repository.findTerminal()?.state, LoginTerminalState.running);
    }
  });

  test(
    '${_typePrefix}_end_terminal_property_success_connects_the_place',
    () async {
      final Random random = seededRandom(63511);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: status,
        );
        final AgentPlace place = pickOne(random, AgentPlace.values);
        await repository.openTerminal(place);

        repository.endTerminal(problem: null);

        final bool isContainer = place == AgentPlace.container;
        final AgentLoginStatus? ended = repository.findStatus();
        expect(repository.findTerminal(), isNull);
        expect(
          ended?.containerCredential,
          isContainer
              ? AgentCredentialKind.longLivedToken
              : status.containerCredential,
        );
        expect(
          ended?.claudeLogin,
          isContainer ? status.claudeLogin : ClaudeLogin.loggedIn,
        );
      }
    },
  );

  test(
    '${_typePrefix}_end_terminal_property_failure_keeps_the_problem',
    () async {
      final Random random = seededRandom(63512);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus? status = randomAgentLoginStatus(random);
        final CountedRepository counted = buildCountedRepository(status);
        await counted.repository.openTerminal(
          pickOne(random, AgentPlace.values),
        );
        await typeRandomLoginLines(random, counted.repository);
        final LoginTerminal running = counted.repository.findTerminal()!;
        final String problem = randomText(random);
        final int notificationsBefore = counted.notifications.count;

        counted.repository.endTerminal(problem: problem);

        final LoginTerminal failed = counted.repository.findTerminal()!;
        expect(failed.state, LoginTerminalState.failed);
        expect(failed.problem, problem);
        expect(failed.place, running.place);
        expect(failed.command, running.command);
        expect(failed.lines, orderedEquals(running.lines));
        expect(identical(counted.repository.findStatus(), status), isTrue);
        expect(counted.notifications.count, notificationsBefore + 1);
      }
    },
  );

  test(
    '${_typePrefix}_end_terminal_property_only_a_running_login_ends',
    () async {
      final Random random = seededRandom(63513);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = random.nextBool()
            ? await buildRepositoryWithFailedLogin(random)
            : FakeAgentLoginRepository(status: randomAgentLoginStatus(random));
        final AgentLoginStatus? statusBefore = repository.findStatus();
        final LoginTerminal? terminalBefore = repository.findTerminal();
        final String? problem = random.nextBool() ? null : randomText(random);

        expect(
          () => repository.endTerminal(problem: problem),
          throwsStateError,
        );

        expect(identical(repository.findStatus(), statusBefore), isTrue);
        expect(identical(repository.findTerminal(), terminalBefore), isTrue);
      }
    },
  );
}
