use std::net::{Ipv4Addr, SocketAddr};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::json;

use crate::support::hosted_runner::{
    HostedRunner, join_and_approve, run_a_task_from, start_host_pairing,
    start_runner_beside_host,
};
use crate::support::hosting_steps::{
    pick_free_port, read_health_answer, read_hosted_address,
    start_hosting_device,
};
use crate::support::server_backups::{
    SYNC_LIMIT, TAKEOVER_SECONDS, create_project, list_task_titles,
    pair_client_at, read_app_servers, read_hosted_state,
    start_backup_ready_to_take_over, start_server_backup,
    start_steady_backup_device, stop_server_backup, wait_until_copied,
    wait_until_standing,
};
use crate::support::test_device::{RELAY_DISABLED, TestDevice, read_text};

const BACKUP_NAME: &str = "studio-mac";
const CLIENT_NAME: &str = "travel-laptop";
const TASK_TITLE: &str = "Plan over the peer link";
const DETECTION_SLACK: Duration = Duration::from_secs(40);
const PROJECT_NAMES: [&str; 2] = ["copied-app", "copied-site"];
const REVOCATION_PAUSE: Duration = Duration::from_secs(3);
const MISDIRECTED_ANSWER_START: &str = "HTTP/1.1 421";

fn read_device_id(device: &TestDevice) -> Result<String, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    read_text(&status, "/device_id")
}

#[test]
fn test_start_server_backup_property_the_backup_keeps_a_verified_copy() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let workspace_id =
        read_text(&hosting.account, "/workspaces/0/id").unwrap_or_default();
    let address = read_hosted_address(&hosting.device).unwrap_or_default();
    let Ok(backup) = start_steady_backup_device() else {
        panic!("the backup device starts");
    };
    let paired = pair_client_at(
        &hosting.device,
        &backup,
        &address,
        &workspace_id,
        BACKUP_NAME,
    );
    assert_eq!(paired, Ok(()));

    let started = start_server_backup(&backup);
    for name in PROJECT_NAMES {
        let created = create_project(&hosting.device, &workspace_id, name);
        assert!(created.is_ok(), "{created:?}");
    }
    let copied = wait_until_copied(&hosting.device, &backup);
    let hosting_view = read_app_servers(&hosting.device);
    let active_stops = stop_server_backup(&hosting.device);
    let second_start = start_server_backup(&hosting.device);

    let Ok(started) = started else {
        panic!("the backup starts: {started:?}");
    };
    assert_eq!(started["this_device"], "backup");
    assert_eq!(started["servers"][0]["standing"], "active");
    assert_eq!(started["servers"][1]["standing"], "backup");
    assert_eq!(started["can_keep_backup"], true);
    let Ok(copied) = copied else {
        panic!("the backup catches up: {copied:?}");
    };
    let copied_text = copied["projects"].to_string();
    for name in PROJECT_NAMES {
        assert!(copied_text.contains(name), "{copied_text}");
    }
    let Ok(hosting_view) = hosting_view else {
        panic!("the hosting device shows the servers");
    };
    assert_eq!(hosting_view["this_device"], "active");
    assert_eq!(hosting_view["servers"][0]["copy"], json!(null));
    let backup_copy = &hosting_view["servers"][1]["copy"];
    assert!(backup_copy["changes_behind"].is_u64(), "{hosting_view}");
    assert!(backup_copy["verified_at"].is_string(), "{hosting_view}");
    assert_eq!(
        active_stops,
        Err("this device is the active app server".to_owned())
    );
    assert_eq!(
        second_start,
        Err("this device already keeps the app server".to_owned())
    );
}

#[test]
fn test_stop_server_backup_property_the_device_leaves_the_group() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let workspace_id =
        read_text(&hosting.account, "/workspaces/0/id").unwrap_or_default();
    let address = read_hosted_address(&hosting.device).unwrap_or_default();
    let Ok(backup) = start_steady_backup_device() else {
        panic!("the backup device starts");
    };
    let paired = pair_client_at(
        &hosting.device,
        &backup,
        &address,
        &workspace_id,
        BACKUP_NAME,
    );
    assert_eq!(paired, Ok(()));
    let started = start_server_backup(&backup);
    assert!(started.is_ok(), "{started:?}");

    let stopped = stop_server_backup(&backup);
    let stopped_again = stop_server_backup(&backup);
    let hosting_view = read_app_servers(&hosting.device);
    let state_left = read_hosted_state(&backup);

    let Ok(stopped) = stopped else {
        panic!("the backup stops: {stopped:?}");
    };
    assert_eq!(stopped["this_device"], "none");
    assert_eq!(stopped["servers"].as_array().map(Vec::len), Some(1));
    assert_eq!(
        stopped_again,
        Err("this device keeps no app server".to_owned())
    );
    let Ok(hosting_view) = hosting_view else {
        panic!("the hosting device shows the servers");
    };
    assert_eq!(hosting_view["servers"].as_array().map(Vec::len), Some(1));
    assert!(state_left.is_err(), "{state_left:?}");
}

#[test]
fn test_start_server_backup_property_takes_over_and_the_old_server_catches_up()
{
    let Ok(nodes) = start_runner_beside_host(RELAY_DISABLED) else {
        panic!("the hosting device and the runner start");
    };
    let address =
        read_hosted_address(&nodes.hosting.device).unwrap_or_default();
    let Ok(backup) = start_backup_ready_to_take_over() else {
        panic!("the backup device starts");
    };
    let Ok(client) = TestDevice::start() else {
        panic!("the client device starts");
    };
    for (device, name) in [(&backup, BACKUP_NAME), (&client, CLIENT_NAME)] {
        let paired = pair_client_at(
            &nodes.hosting.device,
            device,
            &address,
            &nodes.workspace_id,
            name,
        );
        assert_eq!(paired, Ok(()));
    }
    let runner_paired = start_host_pairing(&nodes)
        .and_then(|session| join_and_approve(&nodes, &session, Some(address)));
    assert_eq!(runner_paired, Ok(()));
    let HostedRunner {
        hosting,
        runner,
        workspace_id,
        records: _records,
        runner_data: _runner_data,
    } = nodes;
    let started = start_server_backup(&backup);
    assert!(started.is_ok(), "{started:?}");
    let runner_refused =
        runner.run(&json!({ "command": "start_server_backup" }));
    let client_view = read_app_servers(&client);
    let runner_status = runner.run(&json!({ "command": "status" }));
    let copied = wait_until_copied(&hosting.device, &backup);
    assert!(copied.is_ok(), "{copied:?}");
    let backup_id = read_device_id(&backup).unwrap_or_default();

    let stopped_hosting = hosting.device.stop();
    let stopped_at = Instant::now();
    let takeover_limit =
        Duration::from_secs(TAKEOVER_SECONDS) + DETECTION_SLACK;
    let took_over = wait_until_standing(&backup, "active", takeover_limit);
    let takeover_time = stopped_at.elapsed();
    let task_run = run_a_task_from(&client, &workspace_id);
    let Ok(returned) = stopped_hosting.start_again() else {
        panic!("the old active server starts again");
    };
    let rejoined = wait_until_standing(&returned, "backup", SYNC_LIMIT);
    let caught_up = wait_until_copied(&backup, &returned);

    assert_eq!(
        runner_refused,
        Err("only a client device can keep a backup of the app server"
            .to_owned())
    );
    let Ok(client_view) = client_view else {
        panic!("the client shows the servers");
    };
    assert_eq!(client_view["this_device"], "none");
    assert_eq!(client_view["servers"].as_array().map(Vec::len), Some(2));
    assert!(runner_status.is_ok(), "{runner_status:?}");
    assert!(took_over.is_ok(), "{took_over:?}");
    assert!(takeover_time <= takeover_limit, "{takeover_time:?}");
    let Ok(task_run) = task_run else {
        panic!("the client runs a task after the takeover: {task_run:?}");
    };
    assert_eq!(task_run["run"]["status"], "done");
    let Ok(rejoined) = rejoined else {
        let last_view = read_app_servers(&returned);
        panic!("the old server becomes a backup: {rejoined:?} {last_view:?}");
    };
    assert_eq!(rejoined["servers"][0]["device_id"], backup_id.as_str());
    assert_eq!(rejoined["servers"][0]["standing"], "active");
    let Ok(caught_up) = caught_up else {
        panic!("the old server catches up: {caught_up:?}");
    };
    assert!(list_task_titles(&caught_up).contains(&TASK_TITLE.to_owned()));
}

#[test]
fn test_revoke_device_property_a_revoked_backup_never_takes_over() {
    let Ok(hosting) = start_hosting_device() else {
        panic!("the device hosts the app server");
    };
    let workspace_id =
        read_text(&hosting.account, "/workspaces/0/id").unwrap_or_default();
    let address = read_hosted_address(&hosting.device).unwrap_or_default();
    let backup_port = pick_free_port().unwrap_or_default();
    let Ok(backup) = TestDevice::start_keeping(backup_port, TAKEOVER_SECONDS)
    else {
        panic!("the backup device starts");
    };
    let paired = pair_client_at(
        &hosting.device,
        &backup,
        &address,
        &workspace_id,
        BACKUP_NAME,
    );
    assert_eq!(paired, Ok(()));
    let started = start_server_backup(&backup);
    assert!(started.is_ok(), "{started:?}");
    let backup_id = read_device_id(&backup).unwrap_or_default();

    let revoked = hosting.device.run(&json!({
        "command": "revoke_device",
        "device_id": backup_id,
    }));
    thread::sleep(REVOCATION_PAUSE);
    drop(hosting);
    thread::sleep(Duration::from_secs(TAKEOVER_SECONDS) + DETECTION_SLACK);
    let loopback = SocketAddr::from((Ipv4Addr::LOCALHOST, backup_port));
    let health = read_health_answer(loopback);

    assert!(revoked.is_ok(), "{revoked:?}");
    let Ok(health) = health else {
        panic!("the standby server still answers: {health:?}");
    };
    assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
}
