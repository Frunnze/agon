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
const int _longestSequence = 8;

void main() {
  test(
    '${_typePrefix}_find_terminal_property_reading_changes_nothing',
    () async {
      final Random random = seededRandom(63307);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        await runRandomLoginSteps(random, counted.repository);
        final int notificationsBefore = counted.notifications.count;
        final LoginTerminal? firstRead = counted.repository.findTerminal();

        final LoginTerminal? secondRead = counted.repository.findTerminal();

        expect(identical(secondRead, firstRead), isTrue);
        expect(counted.notifications.count, notificationsBefore);
      }
    },
  );

  test('${_typePrefix}_find_terminal_property_shows_what_was_typed', () async {
    final Random random = seededRandom(63308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      await repository.openTerminal(pickOne(random, AgentPlace.values));
      final List<String> typedLines = <String>[];
      final int typingCount = random.nextInt(_longestSequence);
      for (int typing = 0; typing < typingCount; typing += 1) {
        final String line = randomText(random).replaceAll(enterKey, '');
        typedLines.add(line);
        await repository.typeIntoTerminal('$line$enterKey');
      }

      final LoginTerminal? terminal = repository.findTerminal();

      expect(
        terminal?.lines,
        orderedEquals(<String>[loginPrompt, ...typedLines]),
      );
    }
  });

  test(
    '${_typePrefix}_find_terminal_property_lines_cannot_be_changed',
    () async {
      final Random random = seededRandom(63309);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: randomAgentLoginStatus(random),
        );
        await repository.openTerminal(pickOne(random, AgentPlace.values));
        await runRandomLoginSteps(random, repository);
        final LoginTerminal? terminal = repository.findTerminal();
        if (terminal == null) {
          continue;
        }

        expect(
          () => terminal.lines.add(randomText(random)),
          throwsUnsupportedError,
        );
        expect(terminal.lines.clear, throwsUnsupportedError);
      }
    },
  );

  test(
    '${_typePrefix}_check_status_property_keeps_status_and_terminal',
    () async {
      final Random random = seededRandom(63310);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: randomAgentLoginStatus(random),
        );
        await runRandomLoginSteps(random, repository);
        final AgentLoginStatus? statusBefore = repository.findStatus();
        final LoginTerminal? terminalBefore = repository.findTerminal();

        await repository.checkStatus();

        expectSameLoginStatus(repository.findStatus(), statusBefore);
        expect(identical(repository.findTerminal(), terminalBefore), isTrue);
      }
    },
  );

  test(
    '${_typePrefix}_check_status_property_notifies_once_per_check',
    () async {
      final Random random = seededRandom(63311);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        await runRandomLoginSteps(random, counted.repository);
        final int notificationsBefore = counted.notifications.count;
        final int checks = 1 + random.nextInt(_longestSequence);

        for (int check = 0; check < checks; check += 1) {
          await counted.repository.checkStatus();
        }

        expect(counted.notifications.count, notificationsBefore + checks);
      }
    },
  );

  test('${_typePrefix}_check_status_property_is_idempotent', () async {
    final Random random = seededRandom(63312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      await runRandomLoginSteps(random, repository);
      await repository.checkStatus();
      final AgentLoginStatus? onceChecked = repository.findStatus();

      await repository.checkStatus();

      expectSameLoginStatus(repository.findStatus(), onceChecked);
    }
  });
}
