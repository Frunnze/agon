import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart'
    as node;
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/node_backed/mapping/agent_place_mapping.dart';

AgentLoginStatus mapAgentLoginStatusFromNode(node.AgentLoginStatusView view) {
  final node.AgentCredentialKind? credential = view.containerCredential;
  return AgentLoginStatus(
    claudeLogin: _mapClaudeLogin(view.claudeLogin),
    containerCredential: credential == null
        ? null
        : _mapCredentialKind(credential),
  );
}

LoginTerminal mapLoginTerminalFromNode(node.AgentLoginView view) {
  return LoginTerminal(
    place: mapAgentPlaceFromNode(view.place),
    command: view.command,
    lines: view.lines,
    state: _mapLoginState(view.state),
    problem: view.problem,
  );
}

ClaudeLogin _mapClaudeLogin(node.ClaudeLogin login) {
  return switch (login) {
    node.ClaudeLogin.loggedIn => ClaudeLogin.loggedIn,
    node.ClaudeLogin.notLoggedIn => ClaudeLogin.notLoggedIn,
    node.ClaudeLogin.notInstalled => ClaudeLogin.notInstalled,
  };
}

AgentCredentialKind _mapCredentialKind(node.AgentCredentialKind kind) {
  return switch (kind) {
    node.AgentCredentialKind.longLivedToken =>
      AgentCredentialKind.longLivedToken,
    node.AgentCredentialKind.apiKey => AgentCredentialKind.apiKey,
  };
}

LoginTerminalState _mapLoginState(node.LoginState state) {
  return switch (state) {
    node.LoginState.running => LoginTerminalState.running,
    node.LoginState.finished => LoginTerminalState.finished,
    node.LoginState.failed => LoginTerminalState.failed,
  };
}
