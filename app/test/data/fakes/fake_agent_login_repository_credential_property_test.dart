import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_inputs.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_agent_login_repository';
const int _longestHostileKey = 12;
const List<int> _nodeWhitespace = <int>[
  0x09,
  0x0A,
  0x0B,
  0x0C,
  0x0D,
  0x20,
  0x85,
  0xA0,
  0x1680,
  0x2000,
  0x2005,
  0x200A,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
];
const List<int> _nodeControls = <int>[
  0x00,
  0x07,
  0x1B,
  0x1F,
  0x7F,
  0x80,
  0x9F,
];
const List<int> _plainKeyCharacters = <int>[
  0x61,
  0x5A,
  0x30,
  0x2D,
  0xE9,
  0x200B,
  0xFEFF,
  0x1F511,
];

bool _isNodeBreakingCharacter(int character) {
  return _nodeWhitespace.contains(character) ||
      _nodeControls.contains(character);
}

String _randomHostileKey(Random random) {
  final List<int> characters = <int>[];
  final int length = random.nextInt(_longestHostileKey);
  final List<List<int>> families = <List<int>>[
    _nodeWhitespace,
    _nodeControls,
    _plainKeyCharacters,
    _plainKeyCharacters,
  ];
  for (int i = 0; i < length; i += 1) {
    characters.add(pickOne(random, pickOne(random, families)));
  }
  return String.fromCharCodes(characters);
}

bool _isRefusedByTheNode(String apiKey) {
  final List<int> characters = apiKey.runes.toList();
  int start = 0;
  int end = characters.length;
  while (start < end && _nodeWhitespace.contains(characters[start])) {
    start += 1;
  }
  while (end > start && _nodeWhitespace.contains(characters[end - 1])) {
    end -= 1;
  }
  if (start == end) {
    return true;
  }
  for (int index = start; index < end; index += 1) {
    if (_isNodeBreakingCharacter(characters[index])) {
      return true;
    }
  }
  return false;
}

void main() {
  test('${_typePrefix}_save_api_key_property_connects_containers_'
      'with_an_api_key', () async {
    final Random random = seededRandom(63401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus? status = randomAgentLoginStatus(random);
      final CountedRepository counted = buildCountedRepository(status);

      await counted.repository.saveApiKey(randomValidApiKey(random));

      final AgentLoginStatus? saved = counted.repository.findStatus();
      expect(saved?.containerCredential, AgentCredentialKind.apiKey);
      expect(
        saved?.claudeLogin,
        status?.claudeLogin ?? ClaudeLogin.notLoggedIn,
      );
      expect(counted.notifications.count, 1);
    }
  });

  test(
    '${_typePrefix}_save_api_key_property_refuses_what_the_node_refuses',
    () async {
      final Random random = seededRandom(63402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus? status = randomAgentLoginStatus(random);
        final CountedRepository counted = buildCountedRepository(status);
        final String apiKey = _randomHostileKey(random);

        final bool isKeyRefused = await isRefused(
          () => counted.repository.saveApiKey(apiKey),
          isRefusal: refusesWithStateError,
        );

        expect(
          isKeyRefused,
          _isRefusedByTheNode(apiKey),
          reason: apiKey.runes.toString(),
        );
        if (isKeyRefused) {
          expect(identical(counted.repository.findStatus(), status), isTrue);
          expect(counted.notifications.count, 0);
        }
      }
    },
  );

  test(
    '${_typePrefix}_save_api_key_property_saving_again_changes_nothing',
    () async {
      final Random random = seededRandom(63403);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: randomAgentLoginStatus(random),
        );
        await repository.saveApiKey(randomValidApiKey(random));
        final AgentLoginStatus? onceSaved = repository.findStatus();

        await repository.saveApiKey(randomValidApiKey(random));

        final AgentLoginStatus? twiceSaved = repository.findStatus();
        expect(twiceSaved?.claudeLogin, onceSaved?.claudeLogin);
        expect(
          twiceSaved?.containerCredential,
          onceSaved?.containerCredential,
        );
      }
    },
  );

  test(
    '${_typePrefix}_forget_credential_property_disconnects_containers',
    () async {
      final Random random = seededRandom(63404);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
        final CountedRepository counted = buildCountedRepository(status);

        await counted.repository.forgetCredential();

        final AgentLoginStatus? forgotten = counted.repository.findStatus();
        expect(forgotten?.containerCredential, isNull);
        expect(forgotten?.claudeLogin, status.claudeLogin);
        expect(counted.notifications.count, 1);
      }
    },
  );

  test('${_typePrefix}_forget_credential_property_is_idempotent', () async {
    final Random random = seededRandom(63405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
        status: randomAgentLoginStatus(random),
      );
      await repository.forgetCredential();
      final AgentLoginStatus? onceForgotten = repository.findStatus();

      await repository.forgetCredential();

      final AgentLoginStatus? twiceForgotten = repository.findStatus();
      expect(twiceForgotten?.claudeLogin, onceForgotten?.claudeLogin);
      expect(twiceForgotten?.containerCredential, isNull);
    }
  });

  test(
    '${_typePrefix}_forget_credential_property_leaves_the_terminal',
    () async {
      final Random random = seededRandom(63406);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
          status: randomAgentLoginStatus(random),
        );
        if (random.nextBool()) {
          await repository.openTerminal(pickOne(random, AgentPlace.values));
        }
        final LoginTerminal? terminalBefore = repository.findTerminal();

        await repository.forgetCredential();

        expect(identical(repository.findTerminal(), terminalBefore), isTrue);
      }
    },
  );
}
