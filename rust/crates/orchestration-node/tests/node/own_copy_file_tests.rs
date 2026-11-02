use std::time::Duration;

use serde_json::{Value, json};

use crate::support::folder_laptop::{
    FOLDER_README_TEXT, LAPTOP_NAME, LaptopWithFolder,
    start_laptop_with_folder,
};
use crate::support::test_device::read_text;
use crate::support::waiting::wait_for;

const FILES_LIMIT: Duration = Duration::from_secs(120);
const READ_ONLY_ACCESS: &str = "read_only";
const TASK_TITLE: &str = "Plan the change";
const README_PATH: &str = "README.md";
const DEFAULT_BRANCH: &str = "main";

struct OwnCopy {
    nodes: LaptopWithFolder,
    project_id: String,
    address: String,
    source: Value,
}

struct FileQuestion<'question> {
    command: &'question str,
    branch: &'question str,
    field: &'question str,
    text: &'question str,
}

fn wait_for_finished_run(
    nodes: &LaptopWithFolder,
    run_id: &str,
) -> Result<(), String> {
    wait_for(FILES_LIMIT, "the run to finish", || {
        let shown = nodes
            .laptop
            .run(&json!({ "command": "show_run", "run_id": run_id }))?;
        let status = &shown["run"]["status"];
        if status == "failed" || status == "cancelled" {
            return Err(format!("the run ended early: {}", shown["run"]));
        }
        Ok((status == "done").then_some(()))
    })
}

fn wait_for_own_source(
    nodes: &LaptopWithFolder,
    project_id: &str,
    address: &str,
) -> Result<Value, String> {
    let request = json!({
        "command": "list_repository_branches",
        "project_id": project_id,
        "repository_address": address,
    });
    wait_for(FILES_LIMIT, "this computer to offer its own copy", || {
        let reply = nodes.laptop.send(&request)?;
        if let Some(problem) = reply["error"].as_str() {
            return Err(problem.to_owned());
        }
        let is_available = reply["ok"]["kind"] == "available";
        Ok(is_available.then(|| reply["ok"].clone()))
    })
}

fn prepare_own_copy() -> Result<OwnCopy, String> {
    let nodes = start_laptop_with_folder()?;
    let project = nodes.create_folder_project(READ_ONLY_ACCESS)?;
    let project_id = read_text(&project, "/id")?;
    let address = read_text(&project, "/repositories/0/address")?;
    let run_id = nodes.start_folder_task(&project_id, TASK_TITLE)?;
    wait_for_finished_run(&nodes, &run_id)?;
    let source = wait_for_own_source(&nodes, &project_id, &address)?;
    Ok(OwnCopy {
        nodes,
        project_id,
        address,
        source,
    })
}

fn ask(own: &OwnCopy, question: &FileQuestion<'_>) -> Value {
    let mut request = json!({
        "command": question.command,
        "project_id": own.project_id,
        "repository_address": own.address,
        "runner_id": own.source["runner"]["device_id"],
        "branch": question.branch,
    });
    request[question.field] = json!(question.text);
    let reply = own.nodes.laptop.send(&request);
    reply.unwrap_or_else(|problem| json!({ "error": problem }))
}

fn list_root(own: &OwnCopy, branch: &str) -> Value {
    ask(
        own,
        &FileQuestion {
            command: "list_repository_files",
            branch,
            field: "folder",
            text: "",
        },
    )
}

fn read_on_main(own: &OwnCopy, path: &str) -> Value {
    ask(
        own,
        &FileQuestion {
            command: "read_repository_file",
            branch: DEFAULT_BRANCH,
            field: "path",
            text: path,
        },
    )
}

fn entry_names(reply: &Value) -> Vec<String> {
    let entries = reply["ok"]["entries"].as_array().cloned();
    entries
        .unwrap_or_default()
        .iter()
        .filter_map(|entry| entry["name"].as_str().map(str::to_owned))
        .collect()
}

#[test]
fn a_client_and_runner_computer_reads_its_own_copy_without_the_peer_link() {
    let own = match prepare_own_copy() {
        Ok(own) => own,
        Err(problem) => panic!("this computer offers its own copy: {problem}"),
    };
    let source = &own.source;
    let task_branch = source["task_branches"][0].as_str().unwrap_or_default();

    let root = list_root(&own, DEFAULT_BRANCH);
    let readme = read_on_main(&own, README_PATH);
    let task_root = list_root(&own, task_branch);
    let escape = read_on_main(&own, "../secret");

    assert_eq!(source["runner"]["name"], LAPTOP_NAME, "{source}");
    assert!(task_branch.starts_with("task/"), "{source}");
    assert_eq!(entry_names(&root), [README_PATH], "{root}");
    assert_eq!(readme["ok"]["preview"]["text"], FOLDER_README_TEXT);
    assert_eq!(entry_names(&task_root), [README_PATH], "{task_root}");
    let refusal = escape["error"].as_str().unwrap_or_default();
    assert!(refusal.contains("leaves the repository"), "{escape}");
}
