import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/agent_login_command_shapes.dart';
import '../../../bridge/support/hostile_texts.dart';
import '../../../support/random_inputs.dart';
import '../support/node_enum_mapping_properties.dart';

const List<String> _rustClaudeLogins = <String>[
  'logged_in',
  'not_logged_in',
  'not_installed',
];
const List<String> _rustCredentialKinds = <String>[
  'long_lived_token',
  'api_key',
];
const List<String> _rustLoginStates = <String>[
  'running',
  'finished',
  'failed',
];

node.AgentLoginStatusView _decodeRandomStatus(Random random) {
  return node.AgentLoginStatusView.fromJson(
    randomAgentLoginStatusJson(random),
  );
}

node.AgentLoginView _randomHostileTerminal(Random random) {
  return node.AgentLoginView(
    place: pickOne(random, node.AgentPlace.values),
    command: randomHostileText(random),
    lines: randomHostileTexts(random),
    state: pickOne(random, node.LoginState.values),
    problem: random.nextBool() ? null : randomHostileText(random),
  );
}

node.AgentLoginView _randomNodeTerminal(Random random) {
  if (random.nextBool()) {
    return _randomHostileTerminal(random);
  }
  return node.AgentLoginView.fromJson(randomAgentLoginJson(random));
}

ClaudeLogin _mapClaudeLoginAlone(node.ClaudeLogin login) {
  final node.AgentLoginStatusView status = node.AgentLoginStatusView(
    claudeLogin: login,
    containerCredential: null,
  );
  return mapAgentLoginStatusFromNode(status).claudeLogin;
}

AgentCredentialKind _mapCredentialAlone(node.AgentCredentialKind kind) {
  final node.AgentLoginStatusView status = node.AgentLoginStatusView(
    claudeLogin: node.ClaudeLogin.loggedIn,
    containerCredential: kind,
  );
  final AgentCredentialKind? credential = mapAgentLoginStatusFromNode(status)
      .containerCredential;
  if (credential == null) {
    throw StateError('a given credential came back missing');
  }
  return credential;
}

LoginTerminalState _mapLoginStateAlone(node.LoginState state) {
  final node.AgentLoginView terminal = node.AgentLoginView(
    place: node.AgentPlace.localProcess,
    command: '',
    lines: const <String>[],
    state: state,
    problem: null,
  );
  return mapLoginTerminalFromNode(terminal).state;
}

Map<String, Object?> _writeStatusAsNodeJson(AgentLoginStatus status) {
  final AgentCredentialKind? credential = status.containerCredential;
  final String? credentialWireName = credential == null
      ? null
      : node.AgentCredentialKind.values.byName(credential.name).wireName;
  return <String, Object?>{
    'claude_login': node.ClaudeLogin.values
        .byName(status.claudeLogin.name)
        .wireName,
    'container_credential': credentialWireName,
  };
}

Map<String, Object?> _writeTerminalAsNodeJson(LoginTerminal terminal) {
  return <String, Object?>{
    'place': mapAgentPlaceToNode(terminal.place).wireName,
    'command': terminal.command,
    'lines': terminal.lines,
    'state': node.LoginState.values.byName(terminal.state.name).wireName,
    'problem': terminal.problem,
  };
}

void main() {
  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.ClaudeLogin, ClaudeLogin>(
      functionName: 'map_claude_login',
      seed: 71401,
      rustWireNames: _rustClaudeLogins,
      decodeNode: node.ClaudeLogin.decode,
      modelValues: ClaudeLogin.values,
      mapFromNode: _mapClaudeLoginAlone,
    ),
  );

  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.AgentCredentialKind, AgentCredentialKind>(
      functionName: 'map_credential_kind',
      seed: 71403,
      rustWireNames: _rustCredentialKinds,
      decodeNode: node.AgentCredentialKind.decode,
      modelValues: AgentCredentialKind.values,
      mapFromNode: _mapCredentialAlone,
    ),
  );

  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.LoginState, LoginTerminalState>(
      functionName: 'map_login_state',
      seed: 71405,
      rustWireNames: _rustLoginStates,
      decodeNode: node.LoginState.decode,
      modelValues: LoginTerminalState.values,
      mapFromNode: _mapLoginStateAlone,
    ),
  );

  test('test_map_agent_login_status_from_node_property_'
      'writes_back_the_node_json', () {
    final Random random = seededRandom(71407);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? statusJson = randomAgentLoginStatusJson(random);

      final AgentLoginStatus status = mapAgentLoginStatusFromNode(
        node.AgentLoginStatusView.fromJson(statusJson),
      );

      expect(
        jsonEncode(_writeStatusAsNodeJson(status)),
        jsonEncode(statusJson),
      );
    }
  });

  test('test_map_agent_login_status_from_node_property_'
      'missing_credential_stays_missing', () {
    final Random random = seededRandom(71408);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentLoginStatusView wire = _decodeRandomStatus(random);

      final AgentLoginStatus status = mapAgentLoginStatusFromNode(wire);

      expect(
        status.containerCredential == null,
        wire.containerCredential == null,
      );
    }
  });

  test('test_map_agent_login_status_from_node_property_'
      'login_and_credential_map_independently', () {
    final Random random = seededRandom(71409);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentLoginStatusView wire = _decodeRandomStatus(random);
      final node.AgentLoginStatusView otherLogin = node.AgentLoginStatusView(
        claudeLogin: pickOne(random, node.ClaudeLogin.values),
        containerCredential: wire.containerCredential,
      );

      final AgentLoginStatus status = mapAgentLoginStatusFromNode(wire);
      final AgentLoginStatus otherStatus = mapAgentLoginStatusFromNode(
        otherLogin,
      );

      expect(otherStatus.containerCredential, status.containerCredential);
      expect(
        otherStatus.claudeLogin,
        _mapClaudeLoginAlone(otherLogin.claudeLogin),
      );
    }
  });

  test(
    'test_map_login_terminal_from_node_property_writes_back_the_node_json',
    () {
      final Random random = seededRandom(71410);
      for (int i = 0; i < propertyIterations; i += 1) {
        final node.AgentLoginView wire = _randomNodeTerminal(random);

        final LoginTerminal terminal = mapLoginTerminalFromNode(wire);

        expect(
          jsonEncode(_writeTerminalAsNodeJson(terminal)),
          jsonEncode(wire.toJson()),
        );
      }
    },
  );

  test('test_map_login_terminal_from_node_property_keeps_hostile_texts', () {
    final Random random = seededRandom(71411);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentLoginView wire = _randomHostileTerminal(random);

      final LoginTerminal terminal = mapLoginTerminalFromNode(wire);

      expect(terminal.command, wire.command);
      expect(terminal.lines, orderedEquals(wire.lines));
      expect(terminal.problem, wire.problem);
      expect(terminal.place, mapAgentPlaceFromNode(wire.place));
    }
  });

  test('test_map_login_terminal_from_node_property_lines_stay_fixed', () {
    final Random random = seededRandom(71412);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> wireLines = randomHostileTexts(random);
      final node.AgentLoginView wire = node.AgentLoginView(
        place: pickOne(random, node.AgentPlace.values),
        command: randomText(random),
        lines: wireLines,
        state: pickOne(random, node.LoginState.values),
        problem: null,
      );
      final List<String> linesAtMapping = List<String>.of(wireLines);

      final LoginTerminal terminal = mapLoginTerminalFromNode(wire);
      wireLines.add(randomText(random));

      expect(terminal.lines, orderedEquals(linesAtMapping));
      expect(() => terminal.lines.add(''), throwsUnsupportedError);
    }
  });
}
