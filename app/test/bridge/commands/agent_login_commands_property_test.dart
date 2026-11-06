import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/agent_login_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/agent_login_command_shapes.dart';
import '../support/command_shape.dart';
import '../support/node_wire_names.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const int _firstReplySeed = 85700;
const int _seedStep = 10;
const int _typeKeysSeed = 85800;
const int _saveApiKeySeed = 85810;
const int _statusFieldsSeed = 85820;
const int _statusWideningSeed = 85830;
const int _statusNearMissSeed = 85840;
const int _loginFieldsSeed = 85850;

const Set<String> _nothingReplyCommandNames = <String>{
  'start_agent_login',
  'type_agent_login',
  'stop_agent_login',
  'save_agent_api_key',
  'forget_agent_credential',
};

final Set<String> _claudeLoginWireNames = <String>{
  for (final ClaudeLogin login in ClaudeLogin.values) login.wireName,
};

final Set<String> _credentialWireNames = <String>{
  for (final AgentCredentialKind credential in AgentCredentialKind.values)
    credential.wireName,
};

void main() {
  for (int index = 0; index < agentLoginCommandShapes.length; index += 1) {
    final CommandShape shape = agentLoginCommandShapes[index];
    if (!_nothingReplyCommandNames.contains(shape.commandName)) {
      continue;
    }
    testNothingReplyProperties(
      typeName: '${shape.commandName}_command',
      seed: _firstReplySeed + index * _seedStep,
      buildCommand: shape.buildCommand,
    );
  }

  testTextArgumentProperties(
    typeName: 'type_agent_login_command',
    seed: _typeKeysSeed,
    field: 'keys',
    buildCommand: _typeLoginKeys,
  );
  testTextArgumentProperties(
    typeName: 'save_agent_api_key_command',
    seed: _saveApiKeySeed,
    field: 'api_key',
    buildCommand: _saveApiKey,
  );

  test(
    'test_start_agent_login_command_arguments_property_place_reads_back',
    () {
      for (final AgentPlace place in AgentPlace.values) {
        final JsonObject arguments = StartAgentLoginCommand(place: place)
            .arguments;
        final Object? rereadArguments = jsonDecode(jsonEncode(arguments));
        final JsonObject rereadFields = decodeObject(rereadArguments);

        expect(rereadFields.keys, orderedEquals(<String>['place']));
        expect(AgentPlace.decode(rereadFields['place']), place);
      }
    },
  );

  test('test_start_agent_login_command_arguments_property_node_names', () {
    final Set<Object?> sentPlaceNames = <Object?>{};
    for (final AgentPlace place in AgentPlace.values) {
      sentPlaceNames.add(
        StartAgentLoginCommand(place: place).arguments['place'],
      );
    }

    expect(sentPlaceNames, equals(nodeAgentPlaces.toSet()));
  });

  test('test_start_agent_login_command_arguments_property_places_differ', () {
    for (final AgentPlace firstPlace in AgentPlace.values) {
      for (final AgentPlace secondPlace in AgentPlace.values) {
        final String firstWireText = jsonEncode(
          StartAgentLoginCommand(place: firstPlace).arguments,
        );
        final String secondWireText = jsonEncode(
          StartAgentLoginCommand(place: secondPlace).arguments,
        );

        expect(firstWireText == secondWireText, firstPlace == secondPlace);
      }
    }
  });

  test(
    'test_agent_login_status_command_decode_reply_property_reads_fields',
    () {
      final Random random = seededRandom(_statusFieldsSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject statusJson = decodeObject(
          randomAgentLoginStatusJson(random),
        );
        final AgentLoginStatusView status = const AgentLoginStatusCommand()
            .decodeReply(statusJson);

        expect(status.claudeLogin.wireName, statusJson['claude_login']);
        expect(
          status.containerCredential?.wireName,
          statusJson['container_credential'],
        );
      }
    },
  );

  test('test_agent_login_status_command_decode_reply_property_'
      'ignores_unknown_fields_and_absent_credential', () {
    final Random random = seededRandom(_statusWideningSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject statusJson = decodeObject(
        randomAgentLoginStatusJson(random),
      );
      final JsonObject trimmedJson = withoutField(
        statusJson,
        'container_credential',
      );
      final JsonObject widenedJson = withUnknownFields(random, trimmedJson);
      final AgentLoginStatusView status = const AgentLoginStatusCommand()
          .decodeReply(widenedJson);

      expect(status.claudeLogin.wireName, statusJson['claude_login']);
      expect(status.containerCredential, isNull);
    }
  });

  test('test_agent_login_status_command_decode_reply_property_'
      'rejects_near_miss_names', () {
    final Random random = seededRandom(_statusNearMissSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject statusJson = decodeObject(
        randomAgentLoginStatusJson(random),
      );
      final ClaudeLogin login = pickOne(random, ClaudeLogin.values);
      final AgentCredentialKind credential = pickOne(
        random,
        AgentCredentialKind.values,
      );
      final List<Object?> brokenReplies = <Object?>[
        withoutField(statusJson, 'claude_login'),
        null,
        ...nullLookAlikeReplies,
      ];

      for (final String nearMiss in nearMissWireNames(
        random,
        login.wireName,
        login.name,
      )) {
        if (!_claudeLoginWireNames.contains(nearMiss)) {
          brokenReplies.add(
            withFieldValue(statusJson, 'claude_login', nearMiss),
          );
        }
      }

      for (final String nearMiss in nearMissWireNames(
        random,
        credential.wireName,
        credential.name,
      )) {
        if (!_credentialWireNames.contains(nearMiss)) {
          brokenReplies.add(
            withFieldValue(statusJson, 'container_credential', nearMiss),
          );
        }
      }

      for (final Object? brokenReply in brokenReplies) {
        expect(
          () => const AgentLoginStatusCommand().decodeReply(brokenReply),
          throwsFormatException,
          reason: '$brokenReply',
        );
      }
    }
  });

  test('test_read_agent_login_command_decode_reply_property_null_is_none', () {
    expect(const ReadAgentLoginCommand().decodeReply(null), isNull);
  });

  test('test_read_agent_login_command_decode_reply_property_reads_fields', () {
    final Random random = seededRandom(_loginFieldsSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject loginJson = decodeObject(randomAgentLoginJson(random));
      final AgentLoginView? login = const ReadAgentLoginCommand().decodeReply(
        loginJson,
      );

      expect(login, isNotNull);
      expect(login!.place.wireName, loginJson['place']);
      expect(login.command, loginJson['command']);
      expect(login.lines, orderedEquals(loginJson['lines']! as List<Object?>));
      expect(login.state.wireName, loginJson['state']);
      expect(login.problem, loginJson['problem']);
    }
  });

  test(
    'test_read_agent_login_command_decode_reply_property_no_look_alikes',
    () {
      for (final Object? lookAlikeReply in nullLookAlikeReplies) {
        expect(
          () => const ReadAgentLoginCommand().decodeReply(lookAlikeReply),
          throwsFormatException,
          reason: '$lookAlikeReply',
        );
      }
    },
  );
}

NodeCommand<Object?> _typeLoginKeys(String keys) {
  return TypeAgentLoginCommand(keys: keys);
}

NodeCommand<Object?> _saveApiKey(String apiKey) {
  return SaveAgentApiKeyCommand(apiKey: apiKey);
}
