use std::fs;
use std::time::Duration;

use serde_json::{Value, json};

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::test_device::read_text;
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const FOLLOW_UP_LIMIT: Duration = Duration::from_secs(120);
const TASK_DETAILS: &str = "Answer a question after the plan.";
const FIRST_REPLY: &str = "the plan is to touch the readme";
const FOLLOW_UP_MESSAGE: &str = "Please also update the changelog";
const FOLLOW_UP_REPLY: &str = "answered the follow-up";
const PLAN_SESSION_START: &str = "plan-";

fn start_one_agent_task(nodes: &TwoNodes) -> Result<String, String> {
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
    let task =
        create_task_command(&nodes.workspace_id, &project_id, TASK_DETAILS);
    let created = nodes.client.run(&task)?;
    let run = nodes.client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created, "/id")?,
    }))?;
    read_text(&run, "/id")
}

fn wait_until_done_with(
    nodes: &TwoNodes,
    run_id: &str,
    expected_reply: &str,
) -> Result<Value, String> {
    wait_for(FOLLOW_UP_LIMIT, "the run to finish", || {
        let shown = nodes
            .client
            .run(&json!({ "command": "show_run", "run_id": run_id }))?;
        let run = &shown["run"];
        let is_failed = run["status"] == "failed";
        if is_failed {
            return Err(format!("the run failed: {run}"));
        }
        let is_done = run["status"] == "done";
        let has_reply = run["chat"].to_string().contains(expected_reply);
        Ok((is_done && has_reply).then(|| run.clone()))
    })
}

fn chat_texts(run: &Value) -> Vec<String> {
    let mut texts = Vec::new();
    let messages = run["chat"].as_array().cloned().unwrap_or_default();
    for message in messages {
        let text = message["text"].as_str().unwrap_or_default();
        texts.push(text.to_owned());
    }
    texts
}

#[test]
fn a_message_to_a_finished_run_wakes_the_agent_and_it_replies() {
    let nodes = start_two_nodes_or_panic();
    let Ok(run_id) = start_one_agent_task(&nodes) else {
        panic!("the task starts");
    };
    let first_finish = wait_until_done_with(&nodes, &run_id, FIRST_REPLY);
    let sent = nodes.client.run(&json!({
        "command": "send_chat_message",
        "workspace_id": nodes.workspace_id,
        "run_id": run_id,
        "text": FOLLOW_UP_MESSAGE,
    }));
    let second_finish = wait_until_done_with(&nodes, &run_id, FOLLOW_UP_REPLY);

    let Ok(first_finish) = first_finish else {
        panic!("the first turn finishes: {first_finish:?}");
    };
    assert!(sent.is_ok(), "{sent:?}");
    let Ok(second_finish) = second_finish else {
        panic!("the follow-up finishes: {second_finish:?}");
    };
    let expected_texts = vec![
        FIRST_REPLY.to_owned(),
        FOLLOW_UP_MESSAGE.to_owned(),
        FOLLOW_UP_REPLY.to_owned(),
    ];
    assert_eq!(chat_texts(&second_finish), expected_texts);
    let first_start = &first_finish["steps"][0]["started_at"];
    let second_start = &second_finish["steps"][0]["started_at"];
    assert_ne!(first_start, second_start);
    let resumed_path = nodes.records.path().join("resumed.txt");
    let resumed = fs::read_to_string(resumed_path).unwrap_or_default();
    assert!(resumed.starts_with(PLAN_SESSION_START), "{resumed}");
    assert!(resumed.contains(FOLLOW_UP_MESSAGE), "{resumed}");
}
