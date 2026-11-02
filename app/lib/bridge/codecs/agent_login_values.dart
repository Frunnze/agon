import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

enum ClaudeLogin implements WireNamed {
  loggedIn('logged_in'),
  notLoggedIn('not_logged_in'),
  notInstalled('not_installed');

  const ClaudeLogin(this.wireName);

  @override
  final String wireName;

  static ClaudeLogin decode(Object? json) => decodeWireName(values, json);
}

enum AgentCredentialKind implements WireNamed {
  longLivedToken('long_lived_token'),
  apiKey('api_key');

  const AgentCredentialKind(this.wireName);

  @override
  final String wireName;

  static AgentCredentialKind decode(Object? json) {
    return decodeWireName(values, json);
  }
}

enum LoginState implements WireNamed {
  running('running'),
  finished('finished'),
  failed('failed');

  const LoginState(this.wireName);

  @override
  final String wireName;

  static LoginState decode(Object? json) => decodeWireName(values, json);
}

final class AgentLoginStatusView implements JsonEncodable {
  const AgentLoginStatusView({
    required this.claudeLogin,
    required this.containerCredential,
  });

  factory AgentLoginStatusView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AgentLoginStatusView(
      claudeLogin: readField(fields, 'claude_login', ClaudeLogin.decode),
      containerCredential: readOptionalField(
        fields,
        'container_credential',
        AgentCredentialKind.decode,
      ),
    );
  }

  final ClaudeLogin claudeLogin;
  final AgentCredentialKind? containerCredential;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'claude_login': claudeLogin.wireName,
      'container_credential': containerCredential?.wireName,
    };
  }
}

final class AgentLoginView implements JsonEncodable {
  AgentLoginView({
    required this.place,
    required this.command,
    required List<String> lines,
    required this.state,
    required this.problem,
  }) : lines = List<String>.unmodifiable(lines);

  factory AgentLoginView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AgentLoginView(
      place: readField(fields, 'place', AgentPlace.decode),
      command: readField(fields, 'command', decodeText),
      lines: readListField(fields, 'lines', decodeText),
      state: readField(fields, 'state', LoginState.decode),
      problem: readOptionalField(fields, 'problem', decodeText),
    );
  }

  final AgentPlace place;
  final String command;
  final List<String> lines;
  final LoginState state;
  final String? problem;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'place': place.wireName,
      'command': command,
      'lines': lines,
      'state': state.wireName,
      'problem': problem,
    };
  }
}

AgentLoginView? decodeOptionalAgentLogin(Object? json) {
  if (json == null) {
    return null;
  }
  return AgentLoginView.fromJson(json);
}
