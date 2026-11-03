use std::fs;
use std::time::Duration;

use serde_json::{Value, json};

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::test_device::read_text;
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const FLOW_LIMIT: Duration = Duration::from_secs(120);
const DRAFT_ID: &str = "00000000-0000-0000-0000-000000000031";
const APPROVE_ID: &str = "00000000-0000-0000-0000-000000000032";
const SHIP_ID: &str = "00000000-0000-0000-0000-000000000033";
const QUESTION: &str = "Approve the draft?";
const LOOPED_IN: &str = "## Result from approve\nchanges";

fn step(agent_id: &str, name: &str, step_kind: &str, task: &str) -> Value {
    json!({
        "id": agent_id,
        "name": name,
        "step_kind": step_kind,
        "kind": "claude_code",
        "task": task,
        "runs_on": { "kind": "any_free_runner" },
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": "never_ask",
        "position": { "horizontal": 0.0, "vertical": 0.0 },
    })
}

fn create_review_workflow(nodes: &TwoNodes) -> Result<String, String> {
    let created = nodes.client.run(&json!({
        "command": "create_workflow",
        "workspace_id": nodes.workspace_id,
        "name": "review",
        "availability": { "kind": "all_workspaces" },
        "agents": [
            step(DRAFT_ID, "draft", "agent", "Draft the change"),
            step(APPROVE_ID, "approve", "person", QUESTION),
            step(SHIP_ID, "ship", "agent", "Ship the change"),
        ],
        "connections": [
            { "from": DRAFT_ID, "to": APPROVE_ID },
            { "from": APPROVE_ID, "to": SHIP_ID, "condition": "approved" },
            {
                "from": APPROVE_ID,
                "to": DRAFT_ID,
                "condition": "changes",
                "round_limit": 1,
            },
        ],
    }))?;
    let workflow_id = read_text(&created, "/workflow/id")?;
    nodes.client.run(&json!({
        "command": "sign_workflow",
        "workflow_id": workflow_id,
    }))?;
    Ok(workflow_id)
}

fn start_review_task(nodes: &TwoNodes) -> Result<String, String> {
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
    let workflow_id = create_review_workflow(nodes)?;
    let mut task =
        create_task_command(&nodes.workspace_id, &project_id, "details");
    task["task"]["doer"] =
        json!({ "kind": "workflow", "workflow_id": workflow_id });
    let created_task = nodes.client.run(&task)?;
    let run = nodes.client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created_task, "/id")?,
    }))?;
    read_text(&run, "/id")
}

fn show_run(nodes: &TwoNodes, run_id: &str) -> Result<Value, String> {
    let shown = nodes
        .client
        .run(&json!({ "command": "show_run", "run_id": run_id }))?;
    let status = &shown["run"]["status"];
    if status == "failed" || status == "cancelled" {
        return Err(format!("the run ended early: {}", shown["run"]));
    }
    Ok(shown["run"].clone())
}

fn wait_for_question(
    nodes: &TwoNodes,
    run_id: &str,
    draft_rounds: usize,
) -> Result<Value, String> {
    wait_for(FLOW_LIMIT, "the approval question", || {
        let run = show_run(nodes, run_id)?;
        let earlier_drafts = run["steps"][0]["earlier_rounds"]
            .as_array()
            .map_or(0, Vec::len);
        let open_steps = nodes
            .client
            .run(&json!({ "command": "list_person_steps" }))?;
        let is_open = open_steps[0]["step_name"] == "approve";
        Ok((is_open && earlier_drafts == draft_rounds).then_some(open_steps))
    })
}

fn answer(
    nodes: &TwoNodes,
    run_id: &str,
    text: &str,
) -> Result<Value, String> {
    nodes.client.run(&json!({
        "command": "answer_person_step",
        "run_id": run_id,
        "step_name": "approve",
        "answer": text,
    }))
}

fn run_the_review(nodes: &TwoNodes) -> Result<(Value, Value, String), String> {
    let run_id = start_review_task(nodes)?;
    let first_question = wait_for_question(nodes, &run_id, 0)?;
    let refusal = answer(nodes, &run_id, "maybe");
    let Err(refusal) = refusal else {
        return Err("an unmatched answer is refused".to_owned());
    };
    answer(nodes, &run_id, "changes")?;
    wait_for_question(nodes, &run_id, 1)?;
    answer(nodes, &run_id, "Approve")?;
    let finished = wait_for(FLOW_LIMIT, "the run to finish", || {
        let run = show_run(nodes, &run_id)?;
        Ok((run["status"] == "done").then_some(run))
    })?;
    Ok((first_question, finished, refusal))
}

#[test]
fn a_person_approves_after_one_round_of_changes_and_the_run_ships() {
    let nodes = start_two_nodes_or_panic();

    let outcome = run_the_review(&nodes);

    let Ok((first_question, run, refusal)) = outcome else {
        panic!("the review runs to the end: {outcome:?}");
    };
    assert_eq!(first_question[0]["question"], QUESTION);
    assert_eq!(first_question[0]["choices"], json!(["approved", "changes"]));
    assert!(refusal.contains("approved, changes"), "{refusal}");
    let steps = &run["steps"];
    assert_eq!(steps[0]["name"], "draft");
    assert_eq!(steps[0]["earlier_rounds"].as_array().map(Vec::len), Some(1));
    assert_eq!(steps[1]["status"], "done");
    assert_eq!(steps[1]["outcome"], "approved");
    assert_eq!(steps[1]["result"], "Approve");
    assert_eq!(steps[1]["earlier_rounds"][0]["outcome"], "changes");
    assert_eq!(steps[1]["earlier_rounds"][0]["result"], "changes");
    assert_eq!(steps[2]["status"], "done");
    assert_eq!(run["loop_rounds"][0]["rounds"], 1);
    let prompts_path = nodes.records.path().join("plan-prompts.txt");
    let prompts = fs::read_to_string(prompts_path).unwrap_or_default();
    assert!(prompts.contains(LOOPED_IN), "{prompts}");
    let Ok(stored_state) = nodes.server.read_stored_state() else {
        panic!("the server state is readable");
    };
    assert!(!stored_state.contains(QUESTION), "the question is readable");
}
