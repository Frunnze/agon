use crate::workflow::AgentKind;

pub(crate) fn label_agent_kind(kind: AgentKind) -> &'static str {
    match kind {
        AgentKind::ClaudeCode => "claude-code",
        AgentKind::Codex => "codex",
        AgentKind::GeminiCli => "gemini-cli",
    }
}

#[must_use]
pub fn describe_agent_kind(kind: AgentKind) -> &'static str {
    match kind {
        AgentKind::ClaudeCode => "Claude Code",
        AgentKind::Codex => "Codex",
        AgentKind::GeminiCli => "Gemini CLI",
    }
}
