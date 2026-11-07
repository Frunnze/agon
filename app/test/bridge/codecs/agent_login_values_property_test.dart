import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/agent_login_command_shapes.dart';
import '../support/list_copy_properties.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_properties.dart';

const List<WireCodec> _agentLoginCodecs = <WireCodec>[
  WireCodec(
    typeName: 'agent_login_status_view',
    seed: 49200,
    buildJson: _buildAgentLoginStatusJson,
    decode: AgentLoginStatusView.fromJson,
    requiredFields: <String>{'claude_login'},
    optionalFields: <String>{'container_credential'},
  ),
  WireCodec(
    typeName: 'agent_login_view',
    seed: 49210,
    buildJson: _buildAgentLoginJson,
    decode: AgentLoginView.fromJson,
    requiredFields: <String>{'place', 'command', 'lines', 'state'},
    optionalFields: <String>{'problem'},
  ),
];

void main() {
  testWireNameDecodeProperties(
    const WireNameCodec<ClaudeLogin>(
      typeName: 'claude_login',
      seed: 49220,
      choices: ClaudeLogin.values,
      decode: ClaudeLogin.decode,
      nodeNames: <String>[
        'logged_in',
        'not_logged_in',
        'not_installed',
        'unknown',
      ],
    ),
  );
  testWireNameDecodeProperties(
    const WireNameCodec<AgentCredentialKind>(
      typeName: 'agent_credential_kind',
      seed: 49230,
      choices: AgentCredentialKind.values,
      decode: AgentCredentialKind.decode,
      nodeNames: <String>['long_lived_token', 'api_key'],
    ),
  );
  testWireNameDecodeProperties(
    const WireNameCodec<LoginState>(
      typeName: 'login_state',
      seed: 49240,
      choices: LoginState.values,
      decode: LoginState.decode,
      nodeNames: <String>['running', 'finished', 'failed'],
    ),
  );

  for (final WireCodec codec in _agentLoginCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<AgentLoginView, String>(
      testNamePrefix: 'test_agent_login_view_constructor_property_lines',
      seed: 49250,
      buildElement: randomText,
      construct: _buildAgentLoginView,
      readList: _readLines,
    ),
  );

  test('test_decode_optional_agent_login_property_null_means_no_login', () {
    expect(decodeOptionalAgentLogin(null), isNull);
  });

  test('test_decode_optional_agent_login_property_objects_read_in_full', () {
    final Random random = seededRandom(49260);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _buildAgentLoginJson(random);

      final AgentLoginView? login = decodeOptionalAgentLogin(wireJson);

      expect(login, isNotNull);
      expect(reencodeAsJsonText(login!), equals(wireJson));
    }
  });

  test('test_decode_optional_agent_login_property_'
      'rejects_falsy_non_objects', () {
    final Random random = seededRandom(49270);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> nonObjects = <Object?>[
        false,
        0,
        '',
        'null',
        <Object?>[],
        <Object?>[null],
        randomText(random),
      ];
      final Object? nonObjectJson = pickOne(random, nonObjects);

      expect(
        () => decodeOptionalAgentLogin(nonObjectJson),
        throwsFormatException,
      );
    }
  });
}

JsonObject _buildAgentLoginStatusJson(Random random) {
  return decodeObject(randomAgentLoginStatusJson(random));
}

JsonObject _buildAgentLoginJson(Random random) {
  return decodeObject(randomAgentLoginJson(random));
}

AgentLoginView _buildAgentLoginView(Random random, List<String> lines) {
  return AgentLoginView(
    place: pickOne(random, AgentPlace.values),
    command: randomText(random),
    lines: lines,
    state: pickOne(random, LoginState.values),
    problem: null,
  );
}

List<String> _readLines(AgentLoginView login) => login.lines;
