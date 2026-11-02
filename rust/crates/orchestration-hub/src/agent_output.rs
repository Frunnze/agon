use orchestration_core::workflow::AgentKind;

use crate::agent_event::AgentEvent;
use crate::claude_stream::parse_claude_line;
use crate::terminal_text::strip_terminal_control_sequences;

#[must_use]
pub fn parse_agent_line(agent: AgentKind, line: &str) -> Vec<AgentEvent> {
    let visible_text = strip_terminal_control_sequences(line);
    let text = visible_text.trim_end();
    if text.trim_start().is_empty() {
        return Vec::new();
    }

    match agent {
        AgentKind::ClaudeCode => parse_claude_line(text),
        AgentKind::Codex | AgentKind::GeminiCli => {
            vec![AgentEvent::Said(text.to_string())]
        }
    }
}
