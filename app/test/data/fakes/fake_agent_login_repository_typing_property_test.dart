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
  test(
    '${_typePrefix}_type_into_terminal_property_echoes_the_typed_line',
    () async {
      final Random random = seededRandom(63505);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        await counted.repository.openTerminal(
          pickOne(random, AgentPlace.values),
        );
        await typeRandomLoginLines(random, counted.repository);
        final LoginTerminal before = counted.repository.findTerminal()!;
        final String line = randomText(random).replaceAll(enterKey, '');
        final int notificationsBefore = counted.notifications.count;

        await counted.repository.typeIntoTerminal('$line$enterKey');

        final LoginTerminal after = counted.repository.findTerminal()!;
        expect(after.lines, orderedEquals(<String>[...before.lines, line]));
        expect(after.place, before.place);
        expect(after.command, before.command);
        expect(after.state, before.state);
        expect(counted.notifications.count, notificationsBefore + 1);
      }
    },
  );

  test(
    '${_typePrefix}_type_into_terminal_property_needs_a_terminal',
    () async {
      final Random random = seededRandom(63506);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedRepository counted = buildCountedRepository(
          randomAgentLoginStatus(random),
        );
        if (random.nextBool()) {
          await counted.repository.openTerminal(
            pickOne(random, AgentPlace.values),
          );
          await counted.repository.closeTerminal();
        }
        final int notificationsBefore = counted.notifications.count;

        await expectLater(
          counted.repository.typeIntoTerminal(randomText(random)),
          throwsStateError,
        );

        expect(counted.repository.findTerminal(), isNull);
        expect(counted.notifications.count, notificationsBefore);
      }
    },
  );

  test(
    '${_typePrefix}_type_into_terminal_property_keeps_the_status',
    () async {
      final Random random = seededRandom(63507);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus? status = randomAgentLoginStatus(random);
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: status,
        );
        await repository.openTerminal(pickOne(random, AgentPlace.values));

        await typeRandomLoginLines(random, repository);
        await repository.typeIntoTerminal(randomText(random));

        expect(identical(repository.findStatus(), status), isTrue);
      }
    },
  );
}
