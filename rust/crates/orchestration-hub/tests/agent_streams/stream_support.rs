use std::path::Path;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::{AgentLogLine, describe_agent_log_lines};
use orchestration_hub::agent_output::AgentOutputReader;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::prelude::*;

use crate::json_texts::reads_as_json;

pub const UNKNOWN_TOOL_FAILURE: &str = "the tool failed";
pub const UNKNOWN_AGENT_ERROR: &str = "the agent reported an error";
pub const UNKNOWN_FAILURE_REASON: &str = "the agent stopped with an error";

pub fn any_tool_detail() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9_.=][a-zA-Z0-9 _./=]{0,58}[a-zA-Z0-9_./=]"
}

pub fn any_relative_path() -> impl Strategy<Value = String> {
    "[a-z0-9_-]{1,12}(/[a-z0-9_-]{1,12}){0,4}/[a-z0-9_-]{1,20}\\.[a-z]{1,4}"
}

pub fn fixture_lines(stream: &str) -> Vec<String> {
    stream.lines().map(String::from).collect()
}

fn read_each_line(
    agent: AgentKind,
    task_folder: &Path,
    lines: &[String],
) -> Vec<Vec<AgentEvent>> {
    let mut reader = AgentOutputReader::new(agent, task_folder);
    let mut events_of_each_line = Vec::new();
    for line in lines {
        let (next_reader, agent_events) = reader.read_line(line);
        reader = next_reader;
        events_of_each_line.push(agent_events);
    }
    events_of_each_line
}

pub fn read_agent_events(
    agent: AgentKind,
    task_folder: &Path,
    lines: &[String],
) -> Vec<AgentEvent> {
    read_each_line(agent, task_folder, lines).concat()
}

pub fn read_container_events(
    agent: AgentKind,
    lines: &[String],
) -> Vec<AgentEvent> {
    let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);
    read_agent_events(agent, task_folder, lines)
}

pub fn describe_agent_log(
    agent: AgentKind,
    task_folder: &Path,
    lines: &[String],
) -> Vec<AgentLogLine> {
    let events_of_each_line = read_each_line(agent, task_folder, lines);
    let mut log_lines = Vec::new();
    for (line, agent_events) in lines.iter().zip(&events_of_each_line) {
        log_lines.extend(describe_agent_log_lines(line, agent_events));
    }
    log_lines
}

pub fn describe_container_log(
    agent: AgentKind,
    lines: &[String],
) -> Vec<AgentLogLine> {
    let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);
    describe_agent_log(agent, task_folder, lines)
}

pub fn shows_no_raw_line(
    log_lines: &[AgentLogLine],
    lines: &[String],
) -> bool {
    log_lines.iter().all(|log_line| {
        let text = &log_line.text;
        let repeats_a_json_line = lines
            .iter()
            .any(|line| reads_as_json(line) && text.contains(line.as_str()));
        !reads_as_json(text)
            && !repeats_a_json_line
            && !text.contains('\n')
            && !text.trim().is_empty()
    })
}

pub fn normal_line(text: &str) -> AgentLogLine {
    AgentLogLine {
        text: text.to_string(),
        is_error: false,
    }
}

pub fn error_line(text: &str) -> AgentLogLine {
    AgentLogLine {
        text: text.to_string(),
        is_error: true,
    }
}

pub fn used_tool(description: &str) -> AgentEvent {
    AgentEvent::UsedTool(description.to_string())
}

pub fn expect_given_text(given_text: &str, fallback: &str) -> String {
    let text = given_text.trim();
    if text.is_empty() {
        return fallback.to_string();
    }
    text.to_string()
}
