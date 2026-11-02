import 'dart:convert';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../../bridge/support/scripted_node_transport.dart';

const String openLoginProblem = 'a Claude Code login is already open';
const String loginPrompt = 'Paste code here if prompted >';
const String _containerPlace = 'container';
const String _runningState = 'running';

final class SimulatedAgentLoginNode {
  String claudeLogin = 'not_logged_in';
  String? containerCredential;
  JsonObject? login;
  final List<String> receivedCommands = <String>[];
  final List<String> typedKeys = <String>[];

  String answer(String inputJson) {
    final JsonObject command = decodeObject(jsonDecode(inputJson));
    final String name = decodeText(command['command']);
    receivedCommands.add(name);
    return switch (name) {
      'agent_login_status' => encodeSuccessReply(<String, Object?>{
        'claude_login': claudeLogin,
        'container_credential': containerCredential,
      }),
      'start_agent_login' => _startLogin(decodeText(command['place'])),
      'read_agent_login' => encodeSuccessReply(login),
      'type_agent_login' => _typeKeys(decodeText(command['keys'])),
      'stop_agent_login' => _stopLogin(),
      'save_agent_api_key' => _keepCredential('api_key'),
      'forget_agent_credential' => _keepCredential(null),
      _ => encodeErrorReply('unknown command: $name'),
    };
  }

  void finishLogin({required String? problem}) {
    final JsonObject? running = login;
    if (running == null) {
      throw StateError('no login is open');
    }
    final bool isConnected = problem == null;
    login = <String, Object?>{
      ...running,
      'state': isConnected ? 'finished' : 'failed',
      'problem': problem,
    };
    if (!isConnected) {
      return;
    }
    if (running['place'] == _containerPlace) {
      containerCredential = 'long_lived_token';
    } else {
      claudeLogin = 'logged_in';
    }
  }

  String _startLogin(String place) {
    if (login?['state'] == _runningState) {
      return encodeErrorReply(openLoginProblem);
    }
    login = <String, Object?>{
      'place': place,
      'command': place == _containerPlace
          ? 'claude setup-token'
          : 'claude auth login',
      'lines': <Object?>[loginPrompt],
      'state': _runningState,
      'problem': null,
    };
    return encodeSuccessReply(null);
  }

  String _typeKeys(String keys) {
    if (login == null) {
      return encodeErrorReply('no Claude Code login is open');
    }
    typedKeys.add(keys);
    return encodeSuccessReply(null);
  }

  String _stopLogin() {
    login = null;
    return encodeSuccessReply(null);
  }

  String _keepCredential(String? credential) {
    containerCredential = credential;
    return encodeSuccessReply(null);
  }
}
