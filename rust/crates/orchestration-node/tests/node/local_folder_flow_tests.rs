use std::fs;
use std::time::Duration;

use serde_json::{Value, json};

use crate::support::folder_laptop::{
    LaptopWithFolder, start_laptop_with_folder,
};
use crate::support::git_origin::{read_branch_subject, run_git};
use crate::support::test_device::{describe, read_text};
use crate::support::waiting::wait_for;

const FLOW_LIMIT: Duration = Duration::from_secs(120);
const CHECKED_OUT_BRANCH: &str = "main";
const AGENT_COMMIT_SUBJECT: &str = "Change by the fake agent";
const PUSHING_ACCESS: &str = "push_after_approval";
const TASK_TITLE: &str = "Build the change";

fn finish_the_run(
    nodes: &LaptopWithFolder,
    run_id: &str,
) -> Result<Value, String> {
    let started_marker = nodes.records.path().join("started");
    wait_for(FLOW_LIMIT, "the agent to start", || {
        Ok(started_marker.exists().then_some(()))
    })?;
    fs::write(nodes.records.path().join("release"), "").map_err(describe)?;
    wait_for(FLOW_LIMIT, "the run to finish", || {
        let shown = nodes
            .laptop
            .run(&json!({ "command": "show_run", "run_id": run_id }))?;
        let status = &shown["run"]["status"];
        if status == "failed" || status == "cancelled" {
            return Err(format!("the run ended early: {}", shown["run"]));
        }
        Ok((status == "done").then_some(shown))
    })
}

#[test]
fn a_task_on_a_folder_runs_here_and_pushes_its_branch_back() {
    let Ok(nodes) = start_laptop_with_folder() else {
        panic!("the laptop starts with an account and a folder");
    };

    let finished = nodes
        .create_folder_project(PUSHING_ACCESS)
        .and_then(|project| read_text(&project, "/id"))
        .and_then(|project_id| {
            nodes.start_folder_task(&project_id, TASK_TITLE)
        })
        .and_then(|run_id| finish_the_run(&nodes, &run_id));

    let Ok(finished) = finished else {
        panic!("the run finishes: {finished:?}");
    };
    let folder = nodes.folder();
    let branch = finished["run"]["worktree_branch"].as_str();
    let pushed_subject = read_branch_subject(&folder, branch.unwrap_or("-"));
    let checked_out = run_git(&folder, &["rev-parse", "--abbrev-ref", "HEAD"]);
    let main_subject = read_branch_subject(&folder, CHECKED_OUT_BRANCH);
    assert_eq!(pushed_subject, Ok(AGENT_COMMIT_SUBJECT.to_owned()));
    assert_eq!(checked_out, Ok(CHECKED_OUT_BRANCH.to_owned()));
    assert_eq!(main_subject, Ok("Start".to_owned()));
    let LaptopWithFolder { laptop, .. } = nodes;
    assert_eq!(laptop.stop(), Ok(true));
}
