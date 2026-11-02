use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use orchestration_node::live_link_messages::{
    ClientMessage, FileRequest, RepositoryReference, RunnerMessage,
    decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use serde_json::{Value, json};

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::{LOCAL_REPOSITORY_ADDRESS, run_git};
use crate::support::runner_access::test_runtime;
use crate::support::runner_address::wait_for_runner_address;
use crate::support::test_device::{describe, read_text};
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const FILES_LIMIT: Duration = Duration::from_secs(90);
const SOURCE_PATH: &str = "src/app.ts";
const SOURCE_TEXT: &str = "export const answer = 42;\n";
const ICON_PATH: &str = "assets/icon.png";
const TASK_NOTE_NAME: &str = "task-note.md";
const TASK_NOTE_TEXT: &str = "# Found on the task branch\n";
const STRANGER_SECRET: [u8; 32] = [91; 32];
const TINY_PNG: [u8; 33] = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48,
    0x44, 0x52, 0, 0, 0, 2, 0, 0, 0, 3, 8, 6, 0, 0, 0, 0x1C, 0x2F, 0x3F, 0x5B,
];

fn write_file(root: &Path, path: &str, content: &[u8]) -> Result<(), String> {
    let target = root.join(path);
    let parent = target.parent().ok_or("the file has no folder")?;
    fs::create_dir_all(parent).map_err(describe)?;
    fs::write(target, content).map_err(describe)
}

fn add_origin_files(nodes: &TwoNodes) -> Result<(), String> {
    let origin = nodes.origin_root.path().join(LOCAL_REPOSITORY_ADDRESS);
    let work = nodes.origin_root.path().join("work");
    let origin_text = origin.display().to_string();
    let work_text = work.display().to_string();
    run_git(
        nodes.origin_root.path(),
        &["clone", &origin_text, &work_text],
    )?;
    write_file(&work, SOURCE_PATH, SOURCE_TEXT.as_bytes())?;
    write_file(&work, ICON_PATH, &TINY_PNG)?;
    run_git(&work, &["add", "--all"])?;
    run_git(&work, &["commit", "--message", "Add the app"])?;
    run_git(&work, &["push", "origin", "main"])?;
    Ok(())
}

fn run_one_task(nodes: &TwoNodes) -> Result<String, String> {
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
    let task = create_task_command(&nodes.workspace_id, &project_id, "plan");
    let created = nodes.client.run(&task)?;
    let run = nodes.client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created, "/id")?,
    }))?;
    let run_id = read_text(&run, "/id")?;
    wait_for(FILES_LIMIT, "the run to finish", || {
        let shown = nodes
            .client
            .run(&json!({ "command": "show_run", "run_id": run_id }))?;
        Ok((shown["run"]["status"] == "done").then_some(()))
    })?;
    Ok(project_id)
}

fn find_task_worktree(nodes: &TwoNodes) -> Result<PathBuf, String> {
    let worktrees = nodes.runner_data.path().join("worktrees");
    let task_folder = fs::read_dir(worktrees)
        .map_err(describe)?
        .next()
        .ok_or("the runner made no worktree")?
        .map_err(describe)?;
    Ok(task_folder.path().join("app"))
}

fn commit_on_task_branch(nodes: &TwoNodes) -> Result<(), String> {
    let worktree = find_task_worktree(nodes)?;
    write_file(&worktree, TASK_NOTE_NAME, TASK_NOTE_TEXT.as_bytes())?;
    run_git(&worktree, &["add", "--all"])?;
    run_git(&worktree, &["commit", "--message", "Note the task"])?;
    Ok(())
}

fn ask(nodes: &TwoNodes, command: &str, arguments: &Value) -> Value {
    let mut request = arguments.clone();
    request["command"] = json!(command);
    nodes.client.send(&request)
}

fn wait_for_source(
    nodes: &TwoNodes,
    project_id: &str,
) -> Result<Value, String> {
    let arguments = json!({
        "project_id": project_id,
        "repository_address": LOCAL_REPOSITORY_ADDRESS,
    });
    wait_for(FILES_LIMIT, "a runner with the repository", || {
        let reply = ask(nodes, "list_repository_branches", &arguments);
        let is_available = reply["ok"]["kind"] == "available";
        Ok(is_available.then(|| reply["ok"].clone()))
    })
}

fn location(project_id: &str, source: &Value, branch: &str) -> Value {
    json!({
        "project_id": project_id,
        "repository_address": LOCAL_REPOSITORY_ADDRESS,
        "runner_id": source["runner"]["device_id"],
        "branch": branch,
    })
}

fn with_field(location: &Value, field: &str, text: &str) -> Value {
    let mut arguments = location.clone();
    arguments[field] = json!(text);
    arguments
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
fn a_client_reads_files_from_a_paired_runner_over_the_peer_link() {
    let nodes = start_two_nodes_or_panic();
    let prepared = add_origin_files(&nodes)
        .and_then(|()| run_one_task(&nodes))
        .and_then(|project_id| {
            commit_on_task_branch(&nodes)?;
            Ok(project_id)
        });
    let Ok(project_id) = prepared else {
        panic!("the runner worked on the repository: {prepared:?}");
    };

    let Ok(source) = wait_for_source(&nodes, &project_id) else {
        panic!("a runner offers the repository");
    };
    let task_branch = source["task_branches"][0].as_str().unwrap_or_default();
    let on_main = location(&project_id, &source, "main");
    let on_task = location(&project_id, &source, task_branch);
    let root = ask(
        &nodes,
        "list_repository_files",
        &with_field(&on_main, "folder", ""),
    );
    let source_file = ask(
        &nodes,
        "read_repository_file",
        &with_field(&on_main, "path", SOURCE_PATH),
    );
    let icon = ask(
        &nodes,
        "read_repository_file",
        &with_field(&on_main, "path", ICON_PATH),
    );
    let task_root = ask(
        &nodes,
        "list_repository_files",
        &with_field(&on_task, "folder", ""),
    );
    let note = ask(
        &nodes,
        "read_repository_file",
        &with_field(&on_task, "path", TASK_NOTE_NAME),
    );
    let escape = ask(
        &nodes,
        "read_repository_file",
        &with_field(&on_main, "path", "../secret"),
    );
    let note_on_main = ask(
        &nodes,
        "read_repository_file",
        &with_field(&on_main, "path", TASK_NOTE_NAME),
    );

    assert_eq!(source["runner"]["name"], "office-runner", "{source}");
    assert!(
        source["branches"].to_string().contains("\"main\""),
        "{source}"
    );
    assert!(task_branch.starts_with("task/"), "{source}");
    assert_eq!(entry_names(&root), ["assets", "src", "README.md"], "{root}");
    assert_eq!(source_file["ok"]["preview"]["text"], SOURCE_TEXT);
    assert_eq!(icon["ok"]["preview"]["kind"], "image", "{icon}");
    assert_eq!(icon["ok"]["preview"]["width"], 2);
    assert_eq!(icon["ok"]["preview"]["height"], 3);
    assert!(entry_names(&task_root).contains(&TASK_NOTE_NAME.to_owned()));
    assert_eq!(note["ok"]["preview"]["text"], TASK_NOTE_TEXT, "{note}");
    let refusal = escape["error"].as_str().unwrap_or_default();
    assert!(refusal.contains("leaves the repository"), "{escape}");
    assert!(note_on_main["error"].is_string(), "{note_on_main}");
}

#[test]
fn a_peer_key_of_no_client_cannot_read_files() {
    let nodes = start_two_nodes_or_panic();
    let Ok(project_id) = run_one_task(&nodes) else {
        panic!("the runner worked on the repository");
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
        let project_id =
            serde_json::from_value(json!(project_id)).map_err(describe)?;
        let request = ClientMessage::Browse {
            request: FileRequest::ListBranches {
                repository: RepositoryReference {
                    project_id,
                    address: LOCAL_REPOSITORY_ADDRESS.to_owned(),
                },
            },
        };
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
}
