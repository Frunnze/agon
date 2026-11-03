use std::time::Duration;

use serde_json::{Value, json};

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::test_device::read_text;
use crate::support::two_runners::{
    FIRST_RUNNER_NAME, PairedRunner, SECOND_RUNNER_NAME, TwoRunners,
    start_two_runners,
};
use crate::support::waiting::wait_for;

const FILES_LIMIT: Duration = Duration::from_secs(120);
const UNKNOWN_RUNNER_ID: &str = "nobody-holds-this";

struct TaskBranches {
    project_id: String,
    first_branch: String,
    second_branch: String,
}

fn create_project(nodes: &TwoRunners) -> Result<String, String> {
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
    read_text(&project, "/id")
}

fn run_task_on(
    nodes: &TwoRunners,
    project_id: &str,
    runner: &PairedRunner,
) -> Result<String, String> {
    let mut task =
        create_task_command(&nodes.workspace_id, project_id, "plan");
    task["task"]["runs_on"] = json!({
        "kind": "specific_runner",
        "device_id": runner.device_id,
    });
    let created = nodes.client.run(&task)?;
    let run = nodes.client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created, "/id")?,
    }))?;
    let run_id = read_text(&run, "/id")?;
    let finished = wait_for(FILES_LIMIT, "the run to finish", || {
        let shown = nodes
            .client
            .run(&json!({ "command": "show_run", "run_id": run_id }))?;
        let is_done = shown["run"]["status"] == "done";
        Ok(is_done.then_some(shown))
    })?;
    read_text(&finished, "/run/worktree_branch")
}

fn count_reported_copies(nodes: &TwoRunners) -> Result<usize, String> {
    let listed = nodes.client.run(&json!({
        "command": "list_runners",
        "workspace_id": nodes.workspace_id,
    }))?;
    let runners = listed["runners"].as_array().cloned().unwrap_or_default();
    let mut reported_copies = 0;
    for runner in runners {
        let cached = runner["runner"]["cached_repositories"].to_string();
        if cached.contains(LOCAL_REPOSITORY_ADDRESS) {
            reported_copies += 1;
        }
    }
    Ok(reported_copies)
}

fn wait_for_both_reported_copies(nodes: &TwoRunners) -> Result<(), String> {
    wait_for(FILES_LIMIT, "both runners to report their copies", || {
        let reported_copies = count_reported_copies(nodes)?;
        Ok((reported_copies == 2).then_some(()))
    })
}

fn prepare_task_branches(nodes: &TwoRunners) -> Result<TaskBranches, String> {
    let project_id = create_project(nodes)?;
    let first_branch = run_task_on(nodes, &project_id, &nodes.first)?;
    let second_branch = run_task_on(nodes, &project_id, &nodes.second)?;
    wait_for_both_reported_copies(nodes)?;
    Ok(TaskBranches {
        project_id,
        first_branch,
        second_branch,
    })
}

fn open_files(nodes: &TwoRunners, project_id: &str, preferred: &str) -> Value {
    let reply = nodes.client.send(&json!({
        "command": "list_repository_branches",
        "project_id": project_id,
        "repository_address": LOCAL_REPOSITORY_ADDRESS,
        "preferred_runner_id": preferred,
    }));
    reply["ok"].clone()
}

fn lists_task_branch(source: &Value, branch: &str) -> bool {
    let task_branches = source["task_branches"].as_array();
    task_branches.is_some_and(|branches| branches.contains(&json!(branch)))
}

#[test]
fn the_files_browser_reads_a_task_branch_from_the_runner_that_made_it() {
    let nodes = match start_two_runners() {
        Ok(nodes) => nodes,
        Err(problem) => panic!("two runners start and pair: {problem}"),
    };
    let branches = match prepare_task_branches(&nodes) {
        Ok(branches) => branches,
        Err(problem) => panic!("each runner made a task branch: {problem}"),
    };
    let project_id = &branches.project_id;

    let from_first = open_files(&nodes, project_id, &nodes.first.device_id);
    let from_second = open_files(&nodes, project_id, &nodes.second.device_id);
    let unknown = open_files(&nodes, project_id, UNKNOWN_RUNNER_ID);

    assert_eq!(from_first["runner"]["name"], FIRST_RUNNER_NAME);
    assert_eq!(from_first["runner"]["device_id"], nodes.first.device_id);
    assert!(lists_task_branch(&from_first, &branches.first_branch));
    assert!(!lists_task_branch(&from_first, &branches.second_branch));
    assert_eq!(from_second["runner"]["name"], SECOND_RUNNER_NAME);
    assert_eq!(from_second["runner"]["device_id"], nodes.second.device_id);
    assert!(lists_task_branch(&from_second, &branches.second_branch));
    assert!(!lists_task_branch(&from_second, &branches.first_branch));
    assert_eq!(unknown["kind"], "available", "{unknown}");
}
