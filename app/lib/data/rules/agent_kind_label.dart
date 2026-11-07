import 'package:agent_orchestration/data/models/workflow.dart';

String labelAgentKind(AgentKind kind) {
  return switch (kind) {
    AgentKind.claudeCode => 'claude-code',
    AgentKind.codex => 'codex',
    AgentKind.geminiCli => 'gemini-cli',
  };
}
