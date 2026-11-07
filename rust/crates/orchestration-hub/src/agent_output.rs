use std::path::Path;

use orchestration_core::workflow::AgentKind;

use crate::agent_event::AgentEvent;
use crate::claude_stream::parse_claude_line;
use crate::codex_events::parse_codex_line;
use crate::gemini_stream::{GeminiLine, parse_gemini_line};
use crate::json_terminal_codes::strip_terminal_codes_in_json;
use crate::terminal_text::strip_terminal_control_sequences;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AgentOutputReader {
    agent: AgentKind,
    task_folder: String,
    unfinished_speech: String,
}

impl AgentOutputReader {
    #[must_use]
    pub fn new(agent: AgentKind, task_folder: &Path) -> Self {
        Self {
            agent,
            task_folder: task_folder.to_string_lossy().into_owned(),
            unfinished_speech: String::new(),
        }
    }

    #[must_use]
    pub fn read_line(self, line: &str) -> (Self, Vec<AgentEvent>) {
        let visible_text = strip_terminal_control_sequences(line);
        let text = visible_text.trim_end();
        if text.trim_start().is_empty() {
            return (self, Vec::new());
        }

        let readable_line = strip_terminal_codes_in_json(text);
        match self.agent {
            AgentKind::ClaudeCode => {
                let agent_events =
                    parse_claude_line(&readable_line, &self.task_folder);
                (self, agent_events)
            }
            AgentKind::Codex => {
                let agent_events =
                    parse_codex_line(&readable_line, &self.task_folder);
                (self, agent_events)
            }
            AgentKind::GeminiCli => self.read_gemini_line(text),
        }
    }

    #[must_use]
    pub fn read_end_of_output(self) -> Vec<AgentEvent> {
        describe_unfinished_speech(&self.unfinished_speech)
    }

    fn read_gemini_line(self, text: &str) -> (Self, Vec<AgentEvent>) {
        match parse_gemini_line(text, &self.task_folder) {
            GeminiLine::SpeechPart(part) => {
                let unfinished_speech =
                    format!("{}{part}", self.unfinished_speech);
                let reader = Self {
                    unfinished_speech,
                    ..self
                };
                (reader, Vec::new())
            }
            GeminiLine::KeepsSpeech => (self, Vec::new()),
            GeminiLine::EndsSpeech(agent_events) => {
                self.finish_speech_before(agent_events)
            }
        }
    }

    fn finish_speech_before(
        self,
        later_events: Vec<AgentEvent>,
    ) -> (Self, Vec<AgentEvent>) {
        let mut agent_events =
            describe_unfinished_speech(&self.unfinished_speech);
        agent_events.extend(later_events);

        let reader = Self {
            unfinished_speech: String::new(),
            ..self
        };
        (reader, agent_events)
    }
}

fn describe_unfinished_speech(unfinished_speech: &str) -> Vec<AgentEvent> {
    let visible_speech = strip_terminal_control_sequences(unfinished_speech);
    let speech = visible_speech.trim();
    if speech.is_empty() {
        return Vec::new();
    }
    vec![AgentEvent::Said(speech.to_string())]
}
