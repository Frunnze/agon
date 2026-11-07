use std::future::pending;
use std::path::Path;

use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::RunId;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_output::AgentOutputReader;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use orchestration_runner::output_relay::{
    RelayEnding, RelayedOutput, relay_agent_output,
};
use orchestration_runner::user_message_watch::NewUserMessages;
use proptest::prelude::*;
use serde_json::json;
use tokio::runtime::Runtime;
use tokio::sync::mpsc::unbounded_channel;
use tokio::task::yield_now;
use uuid::Uuid;

use crate::fake_server::FakeServer;
use crate::support::TestResult;

pub type RelayedRun = (RelayEnding, Vec<RunEvent>);

pub const MESSAGE_DELIVERED_NOTE: &str = "Message delivered to the agent";
pub const SAID_PREFIX: &str = "Said: ";

const STEP_NAME: &str = "gemini-cli";
const RUN_NUMBER: u128 = 0x7e11;
const USER_MESSAGE: &str = "Please also update the readme.";

pub fn any_speech_parts() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec("[a-zA-Z0-9,.']{1,8} ?", 1..6)
}

pub fn any_session() -> impl Strategy<Value = String> {
    "[a-f0-9]{8}-[a-f0-9]{4}"
}

pub fn gemini_init_line(session: &str) -> String {
    json!({"type": "init", "session_id": session}).to_string()
}

pub fn gemini_speech_lines(parts: &[String]) -> Vec<String> {
    let mut lines = Vec::new();
    for part in parts {
        let line = json!({
            "type": "message",
            "role": "assistant",
            "content": part,
            "delta": true,
        });
        lines.push(line.to_string());
    }
    lines
}

pub fn gemini_finished_line() -> String {
    json!({"type": "result", "status": "success"}).to_string()
}

pub fn join_speech(parts: &[String]) -> String {
    parts.concat().trim().to_owned()
}

fn run_id() -> RunId {
    RunId(Uuid::from_u128(RUN_NUMBER))
}

fn read_in_container(agent: AgentKind) -> RelayedOutput {
    let task_folder = Path::new(CONTAINER_WORKSPACE_DIRECTORY);
    RelayedOutput::new(AgentOutputReader::new(agent, task_folder), 0)
}

async fn arrive_after_polls(poll_count: usize) -> NewUserMessages {
    for _ in 0..poll_count {
        yield_now().await;
    }
    NewUserMessages {
        prompt: USER_MESSAGE.to_owned(),
        answered_messages: 1,
    }
}

pub fn relay_until_output_ends(
    agent: AgentKind,
    lines: &[String],
) -> TestResult<RelayedRun> {
    let runtime = Runtime::new()?;
    let server = FakeServer::with_queue(Vec::new());
    let (sender, mut receiver) = unbounded_channel();
    for line in lines {
        sender.send(line.clone())?;
    }
    drop(sender);

    let ending = runtime.block_on(relay_agent_output(
        &server,
        run_id(),
        STEP_NAME,
        read_in_container(agent),
        &mut receiver,
        pending(),
        pending::<NewUserMessages>(),
    ))?;
    Ok((ending, server.events_of(run_id())))
}

pub fn relay_until_stopped_for_messages(
    lines: &[String],
    polls_before_messages: usize,
) -> TestResult<RelayedRun> {
    let runtime = Runtime::new()?;
    let server = FakeServer::with_queue(Vec::new());
    let (sender, mut receiver) = unbounded_channel();
    for line in lines {
        sender.send(line.clone())?;
    }

    let ending = runtime.block_on(relay_agent_output(
        &server,
        run_id(),
        STEP_NAME,
        read_in_container(AgentKind::GeminiCli),
        &mut receiver,
        pending(),
        arrive_after_polls(polls_before_messages),
    ))?;
    drop(sender);
    Ok((ending, server.events_of(run_id())))
}
