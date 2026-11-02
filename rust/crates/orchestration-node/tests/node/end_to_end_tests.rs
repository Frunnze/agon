use std::fs;
use std::time::Duration;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    create_rule_command, create_task_command, two_step_workflow_command,
};
use crate::support::command_strategies::arbitrary_command_strategy;
use crate::support::git_origin::{
    LOCAL_REPOSITORY_ADDRESS, read_branch_subject,
};
use crate::support::test_device::{
    describe, fail, is_defined_reply, read_text,
};
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const FLOW_LIMIT: Duration = Duration::from_secs(120);
const RULE_DETAILS: &str = "rule details only devices can read";
const TASK_DETAILS: &str = "task details only devices can read";
const PLAN_TASK: &str = "Plan the change";
const BUILD_TASK: &str = "Build the change";
const PLAN_RESULT: &str = "the plan is to touch the readme";
const USER_MESSAGE: &str = "Please also update the changelog";
const AGENT_REPLY: &str = "finished the first turn";
const AGENT_COMMIT_SUBJECT: &str = "Change by the fake agent";
const WORKTREES_FOLDER_NAME: &str = "worktrees";
const FUZZ_CASES: u32 = 24;

fn create_signed_workflow(nodes: &TwoNodes) -> Result<String, String> {
    let workflow =
        two_step_workflow_command(&nodes.workspace_id, PLAN_TASK, BUILD_TASK);
    let created = nodes.client.run(&workflow)?;
    let workflow_id = read_text(&created, "/workflow/id")?;
    nodes.client.run(&json!({
        "command": "sign_workflow",
        "workflow_id": workflow_id,
    }))?;
    Ok(workflow_id)
}

fn start_workflow_task(nodes: &TwoNodes) -> Result<String, String> {
    let client = &nodes.client;
    client.run(&create_rule_command(&nodes.workspace_id, RULE_DETAILS))?;
    let project = client.run(&json!({
        "command": "create_project",
        "workspace_id": nodes.workspace_id,
        "name": "acme-app",
        "repositories": [{
            "address": LOCAL_REPOSITORY_ADDRESS,
            "default_branch": "main",
            "agent_access": "push_after_approval",
        }],
    }))?;
    let project_id = read_text(&project, "/id")?;
    let workflow_id = create_signed_workflow(nodes)?;

    let mut task =
        create_task_command(&nodes.workspace_id, &project_id, TASK_DETAILS);
    task["task"]["doer"] =
        json!({ "kind": "workflow", "workflow_id": workflow_id });
    let created_task = client.run(&task)?;
    let run = client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created_task, "/id")?,
    }))?;
    read_text(&run, "/id")
}

fn show_run(nodes: &TwoNodes, run_id: &str) -> Result<Value, String> {
    nodes
        .client
        .run(&json!({ "command": "show_run", "run_id": run_id }))
}

fn refuse_an_ended_run(shown: &Value) -> Result<(), String> {
    let status = &shown["run"]["status"];
    if status == "failed" || status == "cancelled" {
        return Err(format!("the run ended early: {}", shown["run"]));
    }
    Ok(())
}

fn approve_the_push(nodes: &TwoNodes, run_id: &str) -> Result<(), String> {
    let approval_id = wait_for(FLOW_LIMIT, "the push approval", || {
        refuse_an_ended_run(&show_run(nodes, run_id)?)?;
        let approvals =
            nodes.client.run(&json!({ "command": "list_approvals" }))?;
        Ok(read_text(&approvals, "/approvals/0/approval/id").ok())
    })?;
    nodes.client.run(&json!({
        "command": "decide_approval",
        "approval_id": approval_id,
        "decision": "approved",
    }))?;
    Ok(())
}

fn talk_to_the_agent(nodes: &TwoNodes, run_id: &str) -> Result<(), String> {
    let started_marker = nodes.records.path().join("started");
    wait_for(FLOW_LIMIT, "the agent to start", || {
        refuse_an_ended_run(&show_run(nodes, run_id)?)?;
        Ok(started_marker.exists().then_some(()))
    })?;
    nodes.client.run(&json!({
        "command": "send_chat_message",
        "workspace_id": nodes.workspace_id,
        "run_id": run_id,
        "text": USER_MESSAGE,
    }))?;
    let release_marker = nodes.records.path().join("release");
    fs::write(release_marker, "").map_err(describe)
}

fn run_the_task_to_done(nodes: &TwoNodes) -> Result<Value, String> {
    let run_id = start_workflow_task(nodes)?;
    talk_to_the_agent(nodes, &run_id)?;
    approve_the_push(nodes, &run_id)?;
    wait_for(FLOW_LIMIT, "the run to finish", || {
        let shown = show_run(nodes, &run_id)?;
        refuse_an_ended_run(&shown)?;
        let is_done = shown["run"]["status"] == "done";
        Ok(is_done.then_some(shown))
    })
}

fn read_record(nodes: &TwoNodes, name: &str) -> String {
    let record_path = nodes.records.path().join(name);
    fs::read_to_string(record_path).unwrap_or_default()
}

#[test]
fn a_two_step_task_runs_on_a_paired_runner_to_a_pushed_branch() {
    let nodes = start_two_nodes_or_panic();

    let finished = run_the_task_to_done(&nodes);

    let Ok(finished) = finished else {
        panic!("the run finishes: {finished:?}");
    };
    let run = &finished["run"];
    let branch = run["worktree_branch"].as_str().unwrap_or_default();
    let origin = nodes.origin_root.path().join(LOCAL_REPOSITORY_ADDRESS);
    let pushed_subject = read_branch_subject(&origin, branch);
    assert_eq!(pushed_subject, Ok(AGENT_COMMIT_SUBJECT.to_owned()));
    let plan_prompt = read_record(&nodes, "plan-prompt.txt");
    assert!(
        plan_prompt.contains(PLAN_TASK) && plan_prompt.contains(TASK_DETAILS)
    );
    let build_prompt = read_record(&nodes, "build-prompt.txt");
    assert!(build_prompt.contains(BUILD_TASK), "{build_prompt}");
    assert!(build_prompt.contains(PLAN_RESULT), "{build_prompt}");
    assert!(build_prompt.contains(TASK_DETAILS), "{build_prompt}");
    assert!(read_record(&nodes, "agents.md").contains(RULE_DETAILS));
    assert_eq!(run["steps"][0]["name"], "plan");
    assert_eq!(run["steps"][0]["result"], PLAN_RESULT);
    assert_eq!(run["steps"][1]["status"], "done");
    let resumed = read_record(&nodes, "resumed.txt");
    assert!(resumed.starts_with("session-"), "{resumed}");
    assert!(resumed.contains(USER_MESSAGE), "{resumed}");
    let chat = run["chat"].to_string();
    assert!(chat.contains(AGENT_REPLY) && chat.contains(USER_MESSAGE));
    assert!(run["log"].as_array().is_some_and(|log| !log.is_empty()));
    let Ok(stored_state) = nodes.server.read_stored_state() else {
        panic!("the server state is readable");
    };
    let secrets = [
        AGENT_REPLY,
        USER_MESSAGE,
        TASK_DETAILS,
        RULE_DETAILS,
        PLAN_RESULT,
    ];
    for secret in secrets {
        assert!(!stored_state.contains(secret), "{secret} is readable");
    }
    let worktrees = nodes.runner_data.path().join(WORKTREES_FOLDER_NAME);
    assert!(worktrees.is_dir());
    let TwoNodes { runner, .. } = nodes;
    assert_eq!(runner.stop(), Ok(true));
}

#[test]
fn test_handle_command_property_arbitrary_commands_never_crash_either_node() {
    let nodes = start_two_nodes_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FUZZ_CASES));

    let outcome = runner.run(&arbitrary_command_strategy(), |command| {
        let client_reply = nodes.client.send(&command);
        let runner_reply = nodes.runner.send(&command).map_err(fail)?;

        prop_assert!(is_defined_reply(&client_reply), "{}", client_reply);
        prop_assert!(is_defined_reply(&runner_reply), "{}", runner_reply);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
    let still_answering = nodes.runner.run(&json!({ "command": "status" }));
    assert!(still_answering.is_ok(), "{still_answering:?}");
}
