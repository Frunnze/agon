use orchestration_api::work::HeartbeatRequest;
use orchestration_core::device::{RunnerLink, SandboxKind};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_task_command, create_workflow_command,
    prepare_workspace,
};
use crate::support::server_access::use_server_at;
use crate::support::test_device::{TestDevice, read_text};

fn start_prepared_device() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is not prepared: {message}"),
    }
}

fn run_or_panic(device: &TestDevice, command: &Value) -> Value {
    match device.run(command) {
        Ok(reply) => reply,
        Err(message) => panic!("{} failed: {message}", command["command"]),
    }
}

fn list_in_workspace(
    device: &TestDevice,
    name: &str,
    workspace_id: &str,
) -> Value {
    run_or_panic(
        device,
        &json!({ "command": name, "workspace_id": workspace_id }),
    )
}

#[test]
fn tasks_show_the_summary_text_and_project_name() {
    let prepared = start_prepared_device();
    let device = &prepared.device;
    run_or_panic(
        device,
        &create_task_command(
            &prepared.workspace_id,
            &prepared.project_id,
            "x",
        ),
    );

    let tasks =
        list_in_workspace(device, "list_tasks", &prepared.workspace_id);

    assert_eq!(tasks["summary_text"], "1 to do");
    assert_eq!(tasks["tasks"][0]["project_name"], "acme-app");
}

#[test]
fn jobs_show_the_schedule_in_words() {
    let prepared = start_prepared_device();
    let device = &prepared.device;
    let mut job_command =
        create_task_command(&prepared.workspace_id, &prepared.project_id, "x");
    job_command["command"] = json!("create_job");
    job_command["schedule"] = json!({
        "every": "day",
        "at": { "hour": 2, "minute": 0 },
    });
    if let Some(fields) = job_command.as_object_mut() {
        fields.remove("start");
    }
    run_or_panic(device, &job_command);

    let jobs = list_in_workspace(device, "list_jobs", &prepared.workspace_id);

    assert_eq!(jobs[0]["schedule_description"], "Every day at 02:00");
    assert!(jobs[0]["next_run_at"].is_string());
}

#[test]
fn a_signed_workflow_shows_signed_and_a_changed_one_shows_its_changes() {
    let prepared = start_prepared_device();
    let device = &prepared.device;
    let workspace_id = &prepared.workspace_id;
    let created = run_or_panic(
        device,
        &create_workflow_command(workspace_id, "Plan the feature"),
    );
    let Ok(workflow_id) = read_text(&created, "/workflow/id") else {
        panic!("the workflow has an id");
    };
    run_or_panic(
        device,
        &json!({
            "command": "sign_workflow",
            "workflow_id": workflow_id,
        }),
    );
    let signed = list_in_workspace(device, "list_workflows", workspace_id);
    let mut changed_workflow = signed[0]["workflow"].clone();
    changed_workflow["agents"][0]["task"] = json!("Plan the whole release");

    run_or_panic(
        device,
        &json!({
            "command": "save_workflow",
            "workspace_id": workspace_id,
            "workflow": changed_workflow,
        }),
    );
    let changed = list_in_workspace(device, "list_workflows", workspace_id);

    assert_eq!(created["signature_state"], "not_signed_yet");
    assert_eq!(signed[0]["signature_state"], "signed");
    assert_eq!(changed[0]["signature_state"], "changed_not_signed");
    let diff_text = changed[0]["changes"].to_string();
    assert!(diff_text.contains("Plan the whole release"));
    assert!(diff_text.contains("removed"));
}

#[test]
fn projects_keep_canonical_repository_addresses() {
    let prepared = start_prepared_device();
    let device = &prepared.device;

    let projects =
        list_in_workspace(device, "list_projects", &prepared.workspace_id);
    let repositories = run_or_panic(
        device,
        &json!({
            "command": "list_repositories",
            "project_id": prepared.project_id,
        }),
    );

    assert_eq!(projects[0]["project"]["name"], "acme-app");
    assert_eq!(projects[0]["task_count"], 0);
    assert_eq!(repositories[0]["address"], "github.com/acme/app");
}

#[test]
fn a_project_with_an_invalid_name_is_rejected() {
    let prepared = start_prepared_device();
    let device = &prepared.device;

    let created = device.run(&json!({
        "command": "create_project",
        "workspace_id": prepared.workspace_id,
        "name": "Acme App",
        "repositories": [],
    }));

    assert!(created.is_err());
}

#[test]
fn runners_show_the_design_summary() {
    let prepared = start_prepared_device();
    let device = &prepared.device;
    if let Err(message) = send_heartbeat(&prepared) {
        panic!("the heartbeat is sent: {message}");
    }

    let runners =
        list_in_workspace(device, "list_runners", &prepared.workspace_id);

    assert_eq!(runners["summary_text"], "1 of 1 online · 3 free slots");
    assert_eq!(runners["runners"][0]["device_name"], "air-laptop");
}

#[test]
fn a_paused_runner_stops_accepting_new_runs() {
    let prepared = start_prepared_device();
    let device = &prepared.device;
    if let Err(message) = send_heartbeat(&prepared) {
        panic!("the heartbeat is sent: {message}");
    }
    let devices = list_devices(device);

    run_or_panic(
        device,
        &json!({
            "command": "pause_runner",
            "device_id": devices[0]["device"]["id"],
        }),
    );
    let runners =
        list_in_workspace(device, "list_runners", &prepared.workspace_id);

    assert_eq!(runners["runners"][0]["runner"]["accepting_new_runs"], false);
}

fn send_heartbeat(prepared: &PreparedWorkspace) -> Result<(), String> {
    let identity = prepared.device.load_identity()?;
    let heartbeat = HeartbeatRequest {
        labels: vec!["mac".to_owned()],
        slots_total: 4,
        slots_busy: 1,
        link: RunnerLink::Direct,
        sandbox: SandboxKind::Container,
        allowed_hosts: Vec::new(),
        cached_repositories: Vec::new(),
    };
    use_server_at(&prepared.server.address, async |server| {
        server.signed(&identity).send_heartbeat(&heartbeat).await
    })
}

fn list_devices(device: &TestDevice) -> Value {
    run_or_panic(device, &json!({ "command": "list_devices" }))
}

#[test]
fn devices_mark_this_device_and_name_its_workspaces() {
    let prepared = start_prepared_device();
    let device = &prepared.device;

    let devices = list_devices(device);

    assert_eq!(devices[0]["is_this_device"], true);
    assert_eq!(devices[0]["workspace_names"], json!(["acme"]));
}
