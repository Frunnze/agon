import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_agent_login_node.dart';
import 'support/agent_login_inputs.dart';
import 'support/agent_login_steps.dart';

const String _typePrefix = 'test_fake_agent_login_repository';
const String _commandProgram = 'claude ';

void main() {
  test('${_typePrefix}_open_terminal_property_shows_a_running_login_'
      'of_the_place', () async {
    final Random random = seededRandom(63501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus? status = randomAgentLoginStatus(random);
      final CountedRepository counted = buildCountedRepository(status);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await counted.repository.openTerminal(place);

      final LoginTerminal? terminal = counted.repository.findTerminal();
      expect(terminal?.place, place);
      expect(terminal?.command, nodeLoginCommands[place]);
      expect(terminal?.lines, orderedEquals(<String>[loginPrompt]));
      expect(terminal?.state, LoginTerminalState.running);
      expect(terminal?.problem, isNull);
      expect(identical(counted.repository.findStatus(), status), isTrue);
      expect(counted.notifications.count, 1);
    }
  });

  test(
    '${_typePrefix}_open_terminal_property_refuses_a_second_login',
    () async {
      final Random random = seededRandom(63502);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        await counted.repository.openTerminal(
          pickOne(random, AgentPlace.values),
        );
        await typeRandomLoginLines(random, counted.repository);
        final LoginTerminal? running = counted.repository.findTerminal();
        final int notificationsBefore = counted.notifications.count;

        await expectLater(
          counted.repository.openTerminal(pickOne(random, AgentPlace.values)),
          throwsStateError,
        );

        expect(identical(counted.repository.findTerminal(), running), isTrue);
        expect(counted.notifications.count, notificationsBefore);
      }
    },
  );

  test(
    '${_typePrefix}_open_terminal_property_replaces_an_ended_login',
    () async {
      final Random random = seededRandom(63503);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository =
            await buildRepositoryWithFailedLogin(random);
        final AgentPlace place = pickOne(random, AgentPlace.values);

        await repository.openTerminal(place);

        final LoginTerminal? terminal = repository.findTerminal();
        expect(terminal?.place, place);
        expect(terminal?.state, LoginTerminalState.running);
        expect(terminal?.problem, isNull);
        expect(terminal?.lines, orderedEquals(<String>[loginPrompt]));
      }
    },
  );

  test(
    'test_describe_login_command_property_matches_the_node_command',
    () async {
      for (final AgentPlace place in AgentPlace.values) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: null,
        );

        await repository.openTerminal(place);

        expect(repository.findTerminal()?.command, nodeLoginCommands[place]);
      }
    },
  );

  test('test_describe_login_command_property_every_place_differs', () async {
    final Set<String> commands = <String>{};

    for (final AgentPlace place in AgentPlace.values) {
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: null,
      );
      await repository.openTerminal(place);
      commands.add(repository.findTerminal()!.command);
    }

    expect(commands, hasLength(AgentPlace.values.length));
  });

  test(
    'test_describe_login_command_property_runs_claude_on_one_line',
    () async {
      final Random random = seededRandom(63504);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository =
            await buildRepositoryWithFailedLogin(random);
        await repository.openTerminal(pickOne(random, AgentPlace.values));
        final String command = repository.findTerminal()!.command;

        expect(command, startsWith(_commandProgram));
        expect(command.trim(), command);
        expect(command.contains('\n'), isFalse);
      }
    },
  );
}
