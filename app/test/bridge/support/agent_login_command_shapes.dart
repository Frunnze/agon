import 'dart:math';

import 'package:agent_orchestration/bridge/commands/agent_login_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';

const List<String> _claudeLoginWireNames = <String>[
  'logged_in',
  'not_logged_in',
  'not_installed',
];
const List<String> _credentialWireNames = <String>[
  'long_lived_token',
  'api_key',
];
const List<String> _loginStateWireNames = <String>[
  'running',
  'finished',
  'failed',
];
const List<String> _loginCommandTexts = <String>[
  'claude auth login',
  'claude setup-token',
];

const List<CommandShape> agentLoginCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'agent_login_status',
    argumentFields: <String>{},
    buildCommand: _buildStatus,
    buildReplyJson: randomAgentLoginStatusJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'start_agent_login',
    argumentFields: <String>{'place'},
    buildCommand: _buildStart,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'read_agent_login',
    argumentFields: <String>{},
    buildCommand: _buildRead,
    buildReplyJson: randomOptionalAgentLoginJson,
    encodeReply: _encodeOptionalValueReply,
  ),
  CommandShape(
    commandName: 'type_agent_login',
    argumentFields: <String>{'keys'},
    buildCommand: _buildType,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'stop_agent_login',
    argumentFields: <String>{},
    buildCommand: _buildStop,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'save_agent_api_key',
    argumentFields: <String>{'api_key'},
    buildCommand: _buildSaveApiKey,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'forget_agent_credential',
    argumentFields: <String>{},
    buildCommand: _buildForget,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
];

Object? randomAgentLoginStatusJson(Random random) {
  return <String, Object?>{
    'claude_login': pickOne(random, _claudeLoginWireNames),
    'container_credential': random.nextBool()
        ? null
        : pickOne(random, _credentialWireNames),
  };
}

Object? randomAgentLoginJson(Random random) {
  final String state = pickOne(random, _loginStateWireNames);
  return <String, Object?>{
    'place': pickOne(random, AgentPlace.values).wireName,
    'command': pickOne(random, _loginCommandTexts),
    'lines': randomTexts(random),
    'state': state,
    'problem': state == 'failed' ? randomText(random) : null,
  };
}

Object? randomOptionalAgentLoginJson(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomAgentLoginJson(random);
}

Object? _encodeOptionalValueReply(Object? decodedReply) {
  if (decodedReply == null) {
    return null;
  }
  return encodeValueReply(decodedReply);
}

NodeCommand<Object?> _buildStatus(Random random) {
  return const AgentLoginStatusCommand();
}

NodeCommand<Object?> _buildStart(Random random) {
  return StartAgentLoginCommand(place: pickOne(random, AgentPlace.values));
}

NodeCommand<Object?> _buildRead(Random random) {
  return const ReadAgentLoginCommand();
}

NodeCommand<Object?> _buildType(Random random) {
  return TypeAgentLoginCommand(keys: randomText(random));
}

NodeCommand<Object?> _buildStop(Random random) {
  return const StopAgentLoginCommand();
}

NodeCommand<Object?> _buildSaveApiKey(Random random) {
  return SaveAgentApiKeyCommand(apiKey: randomText(random));
}

NodeCommand<Object?> _buildForget(Random random) {
  return const ForgetAgentCredentialCommand();
}
