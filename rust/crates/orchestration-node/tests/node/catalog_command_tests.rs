use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_task_command, create_workflow_command,
    prepare_workspace,
};
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::support::test_server::TestServer;

const UPDATE_CASES: u32 = 6;
const CONCURRENT_COMMANDS: usize = 24;

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn update_command(
    prepared: &PreparedWorkspace,
    task_id: &str,
    title: &str,
) -> Value {
    let mut command = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        "changed details",
    );
    command["command"] = json!("update_task");
    command["task_id"] = json!(task_id);
    command["task"]["title"] = json!(title);
    if let Some(fields) = command.as_object_mut() {
        fields.remove("start");
    }
    command
}

#[test]
fn test_update_task_property_keeps_the_id_and_changes_the_fields() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(UPDATE_CASES));

    let outcome = runner.run(&"[A-Z][a-z ]{0,20}", |title| {
        let created = device
            .run(&create_task_command(
                &prepared.workspace_id,
                &prepared.project_id,
                "first details",
            ))
            .map_err(fail)?;
        let task_id = read_text(&created, "/id").map_err(fail)?;

        let updated = device
            .run(&update_command(&prepared, &task_id, &title))
            .map_err(fail)?;

        prop_assert_eq!(&updated["id"], &Value::String(task_id));
        prop_assert_eq!(&updated["title"], &Value::String(title));
        prop_assert_eq!(&updated["details"], "changed details");
        prop_assert_eq!(&updated["created_at"], &created["created_at"]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn update_job_changes_the_schedule() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut job = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        "nightly",
    );
    job["command"] = json!("create_job");
    job["schedule"] =
        json!({ "every": "day", "at": { "hour": 2, "minute": 0 } });
    if let Some(fields) = job.as_object_mut() {
        fields.remove("start");
    }
    let Ok(created) = device.run(&job) else {
        panic!("the job is created");
    };
    let Ok(job_id) = read_text(&created, "/id") else {
        panic!("the job has an id");
    };
    let mut changed = job.clone();
    changed["command"] = json!("update_job");
    changed["task_id"] = json!(job_id);
    changed["schedule"] = json!({ "every": "hour", "minute": 15 });

    let updated = device.run(&changed);
    let jobs = device.run(&json!({
        "command": "list_jobs",
        "workspace_id": prepared.workspace_id,
    }));

    assert!(updated.is_ok(), "{updated:?}");
    let Ok(jobs) = jobs else {
        panic!("the jobs are listed");
    };
    assert_eq!(jobs.as_array().map(Vec::len), Some(1));
    assert_eq!(jobs[0]["schedule_description"], "Every hour at :15");
}

#[test]
fn remove_repository_leaves_the_project_without_it() {
    let prepared = prepared_or_panic();

    let remaining = prepared.device.run(&json!({
        "command": "remove_repository",
        "project_id": prepared.project_id,
        "address": "https://github.com/acme/app.git",
    }));
    let again = prepared.device.run(&json!({
        "command": "remove_repository",
        "project_id": prepared.project_id,
        "address": "github.com/acme/app",
    }));

    assert_eq!(remaining, Ok(json!([])));
    assert!(again.is_err());
}

#[test]
fn workflow_views_say_who_changed_and_signed_them() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let workspace_id = &prepared.workspace_id;
    let Ok(created) =
        device.run(&create_workflow_command(workspace_id, "Plan it"))
    else {
        panic!("the workflow is created");
    };
    let unsigned_at = created["signed_at"].clone();
    let Ok(workflow_id) = read_text(&created, "/workflow/id") else {
        panic!("the workflow has an id");
    };

    let signed = device.run(&json!({
        "command": "sign_workflow",
        "workflow_id": workflow_id,
    }));

    let Ok(signed) = signed else {
        panic!("the workflow is signed: {signed:?}");
    };
    assert_eq!(unsigned_at, Value::Null);
    assert!(signed["signed_at"].is_string());
    assert!(signed["changed_at"].is_string());
    assert_eq!(signed["changed_by_name"], "air-laptop");
}

#[test]
fn pairing_screens_show_when_pairing_started_and_both_words() {
    let prepared = prepared_or_panic();
    let Ok(joining) = TestDevice::start() else {
        panic!("the joining device starts");
    };
    let Ok(session) =
        prepared.device.run(&json!({ "command": "start_pairing" }))
    else {
        panic!("pairing starts");
    };
    let Ok(_) = joining.run(&json!({
        "command": "join_with_code",
        "server_address": prepared.server.address,
        "code": session["display_code"],
        "device_name": "mac-mini",
        "role": "client",
    })) else {
        panic!("the join is sent");
    };
    let Ok(request) = prepared.device.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    })) else {
        panic!("the request shows the joining device");
    };
    let Ok(_) = prepared.device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [prepared.workspace_id],
    })) else {
        panic!("the join is approved");
    };

    let status = joining.run(&json!({ "command": "join_status" }));

    assert!(session["started_at"].is_string());
    let Ok(status) = status else {
        panic!("the join status answers");
    };
    assert_eq!(status["state"], "approved");
    assert_eq!(
        status["fingerprint_words"],
        request["joining"]["fingerprint_words"]
    );
    assert_eq!(status["workspaces"][0]["name"], "acme");
}

#[test]
fn audit_entries_carry_a_detail_line_for_runs() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut task = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        "details",
    );
    task["start"] = json!("now");
    let Ok(_) = device.run(&task) else {
        panic!("the task starts");
    };

    let audit = device.run(&json!({ "command": "list_audit" }));

    let Ok(audit) = audit else {
        panic!("the audit log is listed");
    };
    let details: Vec<&Value> = audit["entries"]
        .as_array()
        .map(|entries| entries.iter().map(|entry| &entry["detail"]).collect())
        .unwrap_or_default();
    let expected = json!("Ship release 2.4 #1 · acme/app");
    assert!(details.contains(&&expected), "{details:?}");
}

#[test]
fn a_published_peer_address_appears_on_the_device_list() {
    let Ok(server) = TestServer::start() else {
        panic!("the server starts");
    };
    let Ok(device) = TestDevice::start() else {
        panic!("the device starts");
    };
    let Ok(_) = device.create_account(&server, "acme") else {
        panic!("the account is created");
    };

    let published = crate::support::waiting::wait_for(
        std::time::Duration::from_secs(10),
        "the peer address",
        || {
            let devices = device.run(&json!({ "command": "list_devices" }))?;
            let address = devices[0]["device"]["peer_address"].clone();
            Ok((!address.is_null()).then_some(address))
        },
    );

    let Ok(published) = published else {
        panic!("the address is published: {published:?}");
    };
    let key = &published["address"]["endpoint_public_key"];
    assert_eq!(key.as_array().map(Vec::len), Some(32));
    let devices = device.run(&json!({ "command": "list_devices" }));
    let verified =
        devices.map(|devices| devices[0]["peer_address_verified"].clone());
    assert_eq!(verified, Ok(json!(true)));
    let status = device.run(&json!({ "command": "status" }));
    assert!(status.is_ok_and(|status| status["peer"]["problem"].is_null()));
}

#[test]
fn identical_commands_sent_at_once_all_succeed() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let command = json!({
        "command": "list_projects",
        "workspace_id": prepared.workspace_id,
    });

    let replies: Vec<Value> = std::thread::scope(|scope| {
        let mut workers = Vec::new();
        for _ in 0..CONCURRENT_COMMANDS {
            workers.push(scope.spawn(|| device.send(&command)));
        }
        workers
            .into_iter()
            .map(|worker| worker.join().unwrap_or(Value::Null))
            .collect()
    });

    assert_eq!(replies.len(), CONCURRENT_COMMANDS);
    for reply in &replies {
        assert!(reply["ok"].is_array(), "{reply}");
    }
}
