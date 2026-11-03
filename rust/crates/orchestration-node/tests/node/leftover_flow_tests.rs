use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::Duration;

use serde_json::json;

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::{LOCAL_REPOSITORY_ADDRESS, run_git};
use crate::support::test_device::{describe, read_text};
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const FLOW_LIMIT: Duration = Duration::from_secs(150);
const WORKTREES_FOLDER_NAME: &str = "worktrees";
const CACHE_FOLDER_NAME: &str = "repository-cache";
const TASK_BRANCH_PATTERN: &str = "refs/heads/task/";
const IDENTIFIER_SEPARATOR: &str = "-";

struct StartedTask {
    folder_marker: String,
    run_id: String,
    task_id: String,
}

fn create_read_only_project(nodes: &TwoNodes) -> Result<String, String> {
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

fn start_task(
    nodes: &TwoNodes,
    project_id: &str,
) -> Result<StartedTask, String> {
    let mut task =
        create_task_command(&nodes.workspace_id, project_id, "details");
    task["start"] = json!("now");
    let created = nodes.client.run(&task)?;
    let task_id = read_text(&created, "/id")?;
    let runs = nodes.client.run(&json!({
        "command": "list_runs",
        "task_id": task_id,
    }))?;
    Ok(StartedTask {
        folder_marker: task_id.replace(IDENTIFIER_SEPARATOR, ""),
        run_id: read_text(&runs, "/0/id")?,
        task_id,
    })
}

fn wait_until_done(
    nodes: &TwoNodes,
    task: &StartedTask,
) -> Result<(), String> {
    wait_for(FLOW_LIMIT, "the run to be done", || {
        let shown = nodes.client.run(&json!({
            "command": "show_run",
            "run_id": task.run_id,
        }))?;
        Ok((shown["run"]["status"] == "done").then_some(()))
    })
}

fn list_folder_names(folder: &Path) -> Result<Vec<String>, String> {
    let folder_entries = match fs::read_dir(folder) {
        Ok(folder_entries) => folder_entries,
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => {
            return Ok(Vec::new());
        }
        Err(problem) => return Err(describe(problem)),
    };
    let mut names = Vec::new();
    for folder_entry in folder_entries {
        let folder_entry = folder_entry.map_err(describe)?;
        names.push(folder_entry.file_name().to_string_lossy().into_owned());
    }
    Ok(names)
}

fn worktrees_root(nodes: &TwoNodes) -> PathBuf {
    nodes.runner_data.path().join(WORKTREES_FOLDER_NAME)
}

fn cache_root(nodes: &TwoNodes) -> PathBuf {
    nodes.runner_data.path().join(CACHE_FOLDER_NAME)
}

fn holds_folder_of(
    nodes: &TwoNodes,
    task: &StartedTask,
) -> Result<bool, String> {
    let names = list_folder_names(&worktrees_root(nodes))?;
    Ok(names.iter().any(|name| name.contains(&task.folder_marker)))
}

fn list_task_branches(nodes: &TwoNodes) -> Result<String, String> {
    let mut branches = String::new();
    for clone_name in list_folder_names(&cache_root(nodes))? {
        let clone = cache_root(nodes).join(clone_name);
        let listing = run_git(
            &clone,
            &["for-each-ref", "--format=%(refname)", TASK_BRANCH_PATTERN],
        )?;
        branches.push_str(&listing);
    }
    Ok(branches)
}

fn delete_task_and_wait(
    nodes: &TwoNodes,
    doomed: &StartedTask,
) -> Result<(), String> {
    nodes.client.run(&json!({
        "command": "delete_task",
        "task_id": doomed.task_id,
    }))?;
    wait_for(
        FLOW_LIMIT,
        "the deleted task's folder and branch to go",
        || {
            let has_folder = holds_folder_of(nodes, doomed)?;
            let branches = list_task_branches(nodes)?;
            let has_branch = branches.contains(&doomed.folder_marker);
            Ok((!has_folder && !has_branch).then_some(()))
        },
    )
}

fn delete_project_and_wait(
    nodes: &TwoNodes,
    project_id: &str,
) -> Result<(), String> {
    nodes.client.run(&json!({
        "command": "delete_project",
        "project_id": project_id,
    }))?;
    wait_for(FLOW_LIMIT, "the project's folders to go", || {
        let worktree_names = list_folder_names(&worktrees_root(nodes))?;
        let clone_names = list_folder_names(&cache_root(nodes))?;
        let is_empty = worktree_names.is_empty() && clone_names.is_empty();
        Ok(is_empty.then_some(()))
    })
}

#[test]
fn deleting_a_task_then_its_project_leaves_nothing_on_the_runner() {
    let nodes = start_two_nodes_or_panic();
    let project_id = create_read_only_project(&nodes);
    let Ok(project_id) = project_id else {
        panic!("the project is created: {project_id:?}");
    };
    let doomed = start_task(&nodes, &project_id);
    let kept = start_task(&nodes, &project_id);
    let (Ok(doomed), Ok(kept)) = (doomed, kept) else {
        panic!("both tasks start");
    };
    for task in [&doomed, &kept] {
        let finished = wait_until_done(&nodes, task);
        assert!(finished.is_ok(), "{finished:?}");
    }

    let task_deleted = delete_task_and_wait(&nodes, &doomed);
    let kept_folder = holds_folder_of(&nodes, &kept);
    let branches = list_task_branches(&nodes);
    let project_deleted = delete_project_and_wait(&nodes, &project_id);

    assert!(task_deleted.is_ok(), "{task_deleted:?}");
    assert_eq!(kept_folder, Ok(true));
    let Ok(branches) = branches else {
        panic!("the task branches are listed: {branches:?}");
    };
    assert!(!branches.contains(&doomed.folder_marker), "{branches}");
    assert!(branches.contains(&kept.folder_marker), "{branches}");
    assert!(project_deleted.is_ok(), "{project_deleted:?}");
    let origin = nodes.origin_root.path().join(LOCAL_REPOSITORY_ADDRESS);
    assert!(origin.join("HEAD").exists());
}
