import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

const String loggedInText = 'Logged in';
const String notLoggedInText = 'Not logged in';
const String notInstalledText = 'Not installed';
const String connectedText = 'Connected';
const String connectedWithApiKeyText = 'Connected with an API key';
const String notConnectedText = 'Not connected';
const String logInLabel = 'Log in';
const String connectClaudeCodeLabel = 'Connect Claude Code';
const String useApiKeyLabel = 'Use an API key instead';
const String disconnectLabel = 'Disconnect';
const String sendLabel = 'Send';
const String closeLabel = 'Close';
const String saveKeyLabel = 'Save key';
const String cancelLabel = 'Cancel';
const String apiKeyFieldLabel = 'Anthropic API key';
const String apiKeyHint =
    'Each container gets it as ANTHROPIC_API_KEY. It stays on this computer.';
const String terminalPlaceholder = 'Type here, then press Enter';
const String terminalHint =
    'Finish in your browser. Paste the code here if Claude Code asks for it.';
const String terminalLabel = 'Claude Code login';
const String commandPrompt = r'$';
const String thisComputerLoginHint =
    "Claude Code couldn't log in for this run. Connect it on this "
    "computer's runner page.";
const List<String> _loginProblemMarks = <String>[
  'Not logged in',
  'Please run /login',
];

enum AgentLoginAction { logIn, connect, useApiKey, disconnect }

final class AgentLoginDescription {
  const AgentLoginDescription({
    required this.statusText,
    required this.detail,
    required this.isReady,
  });

  final String statusText;
  final String detail;
  final bool isReady;
}

AgentLoginDescription describeAgentLogin({
  required AgentPlace place,
  required AgentLoginStatus status,
}) {
  return switch (place) {
    AgentPlace.localProcess => _describeLocalLogin(status.claudeLogin),
    AgentPlace.container => _describeContainerLogin(status),
  };
}

List<AgentLoginAction> chooseAgentLoginActions({
  required AgentPlace place,
  required AgentLoginStatus status,
}) {
  if (place == AgentPlace.localProcess) {
    if (status.claudeLogin == ClaudeLogin.notLoggedIn) {
      return const <AgentLoginAction>[AgentLoginAction.logIn];
    }
    return const <AgentLoginAction>[];
  }

  if (status.containerCredential != null) {
    return const <AgentLoginAction>[AgentLoginAction.disconnect];
  }
  if (status.claudeLogin == ClaudeLogin.notInstalled) {
    return const <AgentLoginAction>[AgentLoginAction.useApiKey];
  }
  return const <AgentLoginAction>[
    AgentLoginAction.connect,
    AgentLoginAction.useApiKey,
  ];
}

String describeAgentLoginTitle(AgentPlace place) {
  return switch (place) {
    AgentPlace.container => 'Claude Code in Docker',
    AgentPlace.localProcess => 'Claude Code on this computer',
  };
}

String describeAgentLoginAction(AgentLoginAction action) {
  return switch (action) {
    AgentLoginAction.logIn => logInLabel,
    AgentLoginAction.connect => connectClaudeCodeLabel,
    AgentLoginAction.useApiKey => useApiKeyLabel,
    AgentLoginAction.disconnect => disconnectLabel,
  };
}

bool isAgentLoginProblem(String reason) {
  for (final String mark in _loginProblemMarks) {
    if (reason.contains(mark)) {
      return true;
    }
  }
  return false;
}

String describeOtherRunnerLoginHint(String runnerName) {
  return 'Claude Code is not connected on $runnerName. Connect it in the '
      'app on that computer, on its runner page.';
}

AgentLoginDescription _describeLocalLogin(ClaudeLogin login) {
  return switch (login) {
    ClaudeLogin.loggedIn => const AgentLoginDescription(
      statusText: loggedInText,
      detail: 'Agents here use your Claude Code login.',
      isReady: true,
    ),
    ClaudeLogin.notLoggedIn => const AgentLoginDescription(
      statusText: notLoggedInText,
      detail:
          'Agents here use your Claude Code login. Log in once and every '
          'run uses it.',
      isReady: false,
    ),
    ClaudeLogin.notInstalled => const AgentLoginDescription(
      statusText: notInstalledText,
      detail:
          'Install Claude Code on this computer, then open this page '
          'again.',
      isReady: false,
    ),
  };
}

AgentLoginDescription _describeContainerLogin(AgentLoginStatus status) {
  final AgentCredentialKind? credential = status.containerCredential;
  if (credential == AgentCredentialKind.longLivedToken) {
    return const AgentLoginDescription(
      statusText: connectedText,
      detail:
          'Each container gets your Claude Code token. It stays on this '
          'computer.',
      isReady: true,
    );
  }
  if (credential == AgentCredentialKind.apiKey) {
    return const AgentLoginDescription(
      statusText: connectedWithApiKeyText,
      detail: 'Each container gets your API key. It stays on this computer.',
      isReady: true,
    );
  }
  if (status.claudeLogin == ClaudeLogin.notInstalled) {
    return const AgentLoginDescription(
      statusText: notConnectedText,
      detail:
          'Install Claude Code on this computer to connect it, or use an '
          'API key.',
      isReady: false,
    );
  }
  return const AgentLoginDescription(
    statusText: notConnectedText,
    detail:
        "Containers can't use your Claude Code login. Connect it once; the "
        'token stays on this computer.',
    isReady: false,
  );
}
