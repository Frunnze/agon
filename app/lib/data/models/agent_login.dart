import 'package:agent_orchestration/data/models/runner.dart';

enum ClaudeLogin { loggedIn, notLoggedIn, notInstalled, unknown }

enum AgentCredentialKind { longLivedToken, apiKey }

enum LoginTerminalState { running, finished, failed }

final class AgentLoginStatus {
  const AgentLoginStatus({
    required this.claudeLogin,
    required this.containerCredential,
  });

  final ClaudeLogin claudeLogin;
  final AgentCredentialKind? containerCredential;
}

final class LoginTerminal {
  LoginTerminal({
    required this.place,
    required this.command,
    required List<String> lines,
    required this.state,
    required this.problem,
  }) : lines = List<String>.unmodifiable(lines);

  final AgentPlace place;
  final String command;
  final List<String> lines;
  final LoginTerminalState state;
  final String? problem;
}
