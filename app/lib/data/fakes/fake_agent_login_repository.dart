import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';

const String _openLoginProblem = 'a Claude Code login is already open';
const String _noLoginProblem = 'no Claude Code login is open';
const String _blankKeyProblem =
    'the Claude Code token or API key cannot be '
    'empty';
const String _brokenKeyProblem =
    'the token or API key cannot have spaces or '
    'line breaks';
const String _loginPrompt = 'Paste code here if prompted >';
const String _enterKey = '\r';
final RegExp _surroundingWhitespace = RegExp(
  r'^\p{White_Space}+|\p{White_Space}+$',
  unicode: true,
);
final RegExp _breakingCharacters = RegExp(
  r'[\p{White_Space}\p{Cc}]',
  unicode: true,
);

final class FakeAgentLoginRepository extends ChangeNotifier
    implements AgentLoginRepository {
  FakeAgentLoginRepository({required AgentLoginStatus? status})
    : _status = status;

  AgentLoginStatus? _status;
  LoginTerminal? _terminal;

  @override
  AgentLoginStatus? findStatus() => _status;

  @override
  LoginTerminal? findTerminal() => _terminal;

  @override
  Future<void> checkStatus() async {
    notifyListeners();
  }

  @override
  Future<void> openTerminal(AgentPlace place) async {
    if (_terminal?.state == LoginTerminalState.running) {
      throw StateError(_openLoginProblem);
    }

    _terminal = LoginTerminal(
      place: place,
      command: _describeLoginCommand(place),
      lines: const <String>[_loginPrompt],
      state: LoginTerminalState.running,
      problem: null,
    );
    notifyListeners();
  }

  @override
  Future<void> typeIntoTerminal(String keys) async {
    final LoginTerminal? terminal = _terminal;
    if (terminal == null || terminal.state != LoginTerminalState.running) {
      throw StateError(_noLoginProblem);
    }

    _terminal = LoginTerminal(
      place: terminal.place,
      command: terminal.command,
      lines: <String>[...terminal.lines, ..._splitTypedLines(keys)],
      state: terminal.state,
      problem: terminal.problem,
    );
    notifyListeners();
  }

  @override
  Future<void> closeTerminal() async {
    _terminal = null;
    notifyListeners();
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    final String trimmed = apiKey.replaceAll(_surroundingWhitespace, '');
    if (trimmed.isEmpty) {
      throw StateError(_blankKeyProblem);
    }
    if (_breakingCharacters.hasMatch(trimmed)) {
      throw StateError(_brokenKeyProblem);
    }

    _keepContainerCredential(AgentCredentialKind.apiKey);
  }

  @override
  Future<void> forgetCredential() async {
    _keepContainerCredential(null);
  }

  void endTerminal({required String? problem}) {
    final LoginTerminal? terminal = _terminal;
    if (terminal == null || terminal.state != LoginTerminalState.running) {
      throw StateError(_noLoginProblem);
    }

    if (problem != null) {
      _terminal = LoginTerminal(
        place: terminal.place,
        command: terminal.command,
        lines: terminal.lines,
        state: LoginTerminalState.failed,
        problem: problem,
      );
      notifyListeners();
      return;
    }

    _terminal = null;
    if (terminal.place == AgentPlace.container) {
      _keepContainerCredential(AgentCredentialKind.longLivedToken);
      return;
    }
    _markClaudeLoggedIn();
  }

  void _keepContainerCredential(AgentCredentialKind? credential) {
    final AgentLoginStatus? knownStatus = _status;
    if (knownStatus != null) {
      _status = AgentLoginStatus(
        claudeLogin: knownStatus.claudeLogin,
        containerCredential: credential,
      );
    }
    notifyListeners();
  }

  void _markClaudeLoggedIn() {
    final AgentLoginStatus? knownStatus = _status;
    if (knownStatus != null) {
      _status = AgentLoginStatus(
        claudeLogin: ClaudeLogin.loggedIn,
        containerCredential: knownStatus.containerCredential,
      );
    }
    notifyListeners();
  }
}

List<String> _splitTypedLines(String keys) {
  final List<String> typedLines = keys.split(_enterKey);
  if (keys.endsWith(_enterKey)) {
    typedLines.removeLast();
  }
  return typedLines;
}

String _describeLoginCommand(AgentPlace place) {
  return switch (place) {
    AgentPlace.container => 'claude setup-token',
    AgentPlace.localProcess => 'claude auth login',
  };
}
