use std::fs;
use std::time::Duration;

use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use serde_json::{Value, json};

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::runner_access::test_runtime;
use crate::support::runner_address::wait_for_runner_address;
use crate::support::test_device::{describe, read_text};
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const LIVE_LIMIT: Duration = Duration::from_secs(60);
const WATCHED_TASK: &str = "Watch the change";
const FIRST_LIVE_MESSAGE: &str = "first live message";
const FINAL_LIVE_MESSAGE: &str = "final live message";
const USER_MESSAGE: &str = "Please also check the docs";
const AGENT_ANSWER: &str = "answered the follow-up";
const STRANGER_SECRET: [u8; 32] = [77; 32];

fn start_watched_run(nodes: &TwoNodes) -> Result<String, String> {
    let project = nodes.client.run(&json!({
        "command": "create_project",
        "workspace_id": nodes.workspace_id,
        "name": "acme-app",
        "repositories": [{
            "address": LOCAL_REPOSITORY_ADDRESS,
            "default_branch": "main",
            "agent_access": "read_only",
        }],
    }))?;
    let project_id = read_text(&project, "/id")?;
    let mut task =
        create_task_command(&nodes.workspace_id, &project_id, "watch it");
    task["task"]["title"] = json!(WATCHED_TASK);
    let created = nodes.client.run(&task)?;
    let run = nodes.client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created, "/id")?,
    }))?;
    let started_marker = nodes.records.path().join("watch-started");
    wait_for(LIVE_LIMIT, "the watched agent to start", || {
        Ok(started_marker.exists().then_some(()))
    })?;
    read_text(&run, "/id")
}

fn release(nodes: &TwoNodes, marker: &str) -> Result<(), String> {
    fs::write(nodes.records.path().join(marker), "").map_err(describe)
}

fn watch(nodes: &TwoNodes, run_id: &str) -> Result<Value, String> {
    nodes
        .client
        .run(&json!({ "command": "watch_run", "run_id": run_id }))
}

fn show_run(nodes: &TwoNodes, run_id: &str) -> Result<Value, String> {
    nodes
        .client
        .run(&json!({ "command": "show_run", "run_id": run_id }))
}

fn has_chat_text(events: &Value, text: &str) -> bool {
    let Some(events) = events.as_array() else {
        return false;
    };
    events.iter().any(|event| {
        event["kind"] == "chat_appended" && event["message"]["text"] == text
    })
}

fn wait_for_live_message(
    nodes: &TwoNodes,
    run_id: &str,
    text: &str,
) -> Result<Vec<Value>, String> {
    let mut received = Vec::new();
    wait_for(LIVE_LIMIT, "a live message", || {
        let view = watch(nodes, run_id)?;
        let events = view["events"].as_array().cloned().unwrap_or_default();
        received.extend(events);
        let arrived = has_chat_text(&Value::Array(received.clone()), text);
        Ok(arrived.then_some(()))
    })?;
    Ok(received)
}

fn chat_texts(shown: &Value) -> String {
    shown["run"]["chat"].to_string()
}

#[test]
fn a_live_link_streams_events_and_chat_and_falls_back_when_it_drops() {
    let mut nodes = start_two_nodes_or_panic();
    let Ok(run_id) = start_watched_run(&nodes) else {
        panic!("the watched run starts");
    };

    let runner_address = wait_for_runner_address(&nodes);
    let first_view = watch(&nodes, &run_id);
    let Ok(()) = release(&nodes, "release") else {
        panic!("the agent is released");
    };
    let live_events =
        wait_for_live_message(&nodes, &run_id, FIRST_LIVE_MESSAGE);
    let sent = nodes.client.run(&json!({
        "command": "send_chat_message",
        "workspace_id": nodes.workspace_id,
        "run_id": run_id,
        "text": USER_MESSAGE,
    }));
    let reached_history = wait_for(LIVE_LIMIT, "the chat in history", || {
        let shown = show_run(&nodes, &run_id)?;
        Ok(chat_texts(&shown).contains(USER_MESSAGE).then_some(()))
    });
    let restarted = nodes.client.restart();
    let fallback = wait_for(LIVE_LIMIT, "the dropped link", || {
        let shown = show_run(&nodes, &run_id)?;
        let is_lost = shown["link"] == "unreachable"
            && shown["link_lost_at"].is_string();
        Ok(is_lost.then_some(shown))
    });
    let Ok(()) = release(&nodes, "release-2") else {
        panic!("the agent finishes");
    };
    let finished = wait_for(LIVE_LIMIT, "the run to finish", || {
        let shown = show_run(&nodes, &run_id)?;
        let is_done = shown["run"]["status"] == "done";
        Ok(is_done.then_some(shown))
    });

    let Ok(first_view) = first_view else {
        panic!("the run is watched: {first_view:?}");
    };
    let direct_address_count = runner_address.direct_addresses.len();
    assert_ne!(direct_address_count, 0, "{runner_address:?}");
    assert_eq!(first_view["link"], "direct", "{first_view}");
    assert!(live_events.is_ok(), "{live_events:?}");
    assert!(sent.is_ok(), "{sent:?}");
    assert_eq!(reached_history, Ok(()));
    assert_eq!(restarted, Ok(()));
    assert!(fallback.is_ok(), "{fallback:?}");
    let Ok(finished) = finished else {
        panic!("the run finishes: {finished:?}");
    };
    let history = chat_texts(&finished);
    for text in [FIRST_LIVE_MESSAGE, USER_MESSAGE, FINAL_LIVE_MESSAGE] {
        assert!(history.contains(text), "{text} is missing from {history}");
    }
    assert!(history.contains(AGENT_ANSWER), "{history}");
    let resumed = fs::read_to_string(nodes.records.path().join("resumed.txt"));
    assert!(resumed.is_ok_and(|resumed| resumed.contains(USER_MESSAGE)));
}

#[test]
fn a_peer_key_that_belongs_to_no_client_is_refused() {
    let nodes = start_two_nodes_or_panic();
    let Ok(run_id) = start_watched_run(&nodes) else {
        panic!("the watched run starts");
    };
    let address = wait_for_runner_address(&nodes);
    let Ok(runtime) = test_runtime() else {
        panic!("a runtime starts");
    };

    let answer = runtime.block_on(async {
        let stranger = PeerEndpoint::bind(PeerConfiguration {
            secret_key: STRANGER_SECRET,
            relay: RelayChoice::Disabled,
        })
        .await
        .map_err(describe)?;
        let mut link = stranger.connect(&address).await.map_err(describe)?;
        let run_uuid =
            serde_json::from_value(json!(run_id)).map_err(describe)?;
        let request = ClientMessage::Watch { run_id: run_uuid };
        let frame = encode_link_message(&request).map_err(describe)?;
        link.sender.send_frame(&frame).await.map_err(describe)?;
        let reply = link.receiver.receive_frame().await.map_err(describe)?;
        stranger.close().await;
        let reply = reply.ok_or_else(|| "the runner hung up".to_owned())?;
        decode_link_message::<RunnerMessage>(&reply).map_err(describe)
    });

    let Ok(RunnerMessage::Refused { reason }) = answer else {
        panic!("the stranger is refused: {answer:?}");
    };
    assert!(reason.contains("trusted"), "{reason}");
    let Ok(()) = release(&nodes, "release") else {
        panic!("the agent is released");
    };
    let Ok(()) = release(&nodes, "release-2") else {
        panic!("the agent finishes");
    };
}
