import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_inputs.dart';
import 'support/agent_login_steps.dart';

const int _longestLineCount = 5;

typedef _TypedKeys = ({String keys, List<String> lines});

_TypedKeys _randomTypedKeys(Random random) {
  final List<String> lines = <String>[];
  final int lineCount = 1 + random.nextInt(_longestLineCount);
  for (int i = 0; i < lineCount; i += 1) {
    lines.add(randomText(random));
  }
  final String enteredKeys = '${lines.join(enterKey)}$enterKey';
  if (random.nextBool()) {
    return (keys: enteredKeys, lines: lines);
  }
  final String unfinishedLine = '${randomText(random)}x';
  return (
    keys: '$enteredKeys$unfinishedLine',
    lines: <String>[...lines, unfinishedLine],
  );
}

Future<FakeAgentLoginRepository> _openRandomTerminal(Random random) async {
  final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
    status: randomAgentLoginStatus(random),
  );
  await repository.openTerminal(pickOne(random, AgentPlace.values));
  await typeRandomLoginLines(random, repository);
  return repository;
}

List<String> _readAddedLines(
  FakeAgentLoginRepository repository,
  int linesBefore,
) {
  return repository.findTerminal()!.lines.sublist(linesBefore);
}

void main() {
  test('test_split_typed_lines_property_each_enter_ends_a_line', () async {
    final Random random = seededRandom(66701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = await _openRandomTerminal(
        random,
      );
      final int linesBefore = repository.findTerminal()!.lines.length;
      final _TypedKeys typed = _randomTypedKeys(random);

      await repository.typeIntoTerminal(typed.keys);

      expect(
        _readAddedLines(repository, linesBefore),
        orderedEquals(typed.lines),
        reason: typed.keys,
      );
    }
  });

  test('test_split_typed_lines_property_lines_rejoin_to_the_typed_'
      'keys', () async {
    final Random random = seededRandom(66702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = await _openRandomTerminal(
        random,
      );
      final int linesBefore = repository.findTerminal()!.lines.length;
      final String keys = _randomTypedKeys(random).keys;

      await repository.typeIntoTerminal(keys);

      final List<String> added = _readAddedLines(repository, linesBefore);
      final String rejoined = added.join(enterKey);
      final String expectedKeys = keys.endsWith(enterKey)
          ? '$rejoined$enterKey'
          : rejoined;
      expect(expectedKeys, keys);
      for (final String line in added) {
        expect(line.contains(enterKey), isFalse);
      }
    }
  });

  test('test_split_typed_lines_property_typing_in_parts_adds_every_'
      'line', () async {
    final Random random = seededRandom(66703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = await _openRandomTerminal(
        random,
      );
      final int linesBefore = repository.findTerminal()!.lines.length;
      final _TypedKeys first = _randomTypedKeys(random);
      final _TypedKeys second = _randomTypedKeys(random);

      await repository.typeIntoTerminal(first.keys);
      await repository.typeIntoTerminal(second.keys);

      expect(
        _readAddedLines(repository, linesBefore),
        orderedEquals(<String>[...first.lines, ...second.lines]),
      );
    }
  });

  test('test_fake_agent_login_repository_type_into_terminal_property_'
      'line_count_is_the_enter_count', () async {
    final Random random = seededRandom(66704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = await _openRandomTerminal(
        random,
      );
      final int linesBefore = repository.findTerminal()!.lines.length;
      final int enterCount = 1 + random.nextInt(_longestLineCount);
      final StringBuffer keys = StringBuffer();
      for (int enter = 0; enter < enterCount; enter += 1) {
        keys.write('${randomText(random)}$enterKey');
      }

      await repository.typeIntoTerminal(keys.toString());

      expect(_readAddedLines(repository, linesBefore), hasLength(enterCount));
    }
  });
}
