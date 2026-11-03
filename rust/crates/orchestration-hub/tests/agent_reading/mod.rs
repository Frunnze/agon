use std::path::Path;

use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_output::AgentOutputReader;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;

pub fn parse_agent_line(agent: AgentKind, line: &str) -> Vec<AgentEvent> {
    let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);
    let reader = AgentOutputReader::new(agent, task_folder);
    let (_reader_after_the_line, agent_events) = reader.read_line(line);
    agent_events
}
