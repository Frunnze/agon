use std::fs;
use std::path::Path;
use std::time::Duration;

use orchestration_api::work::HeartbeatRequest;
use orchestration_core::server_group::ServerGroup;
use orchestration_node::device_files::DeviceFiles;
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};

use crate::support::command_builders::prepare_workspace;
use crate::support::hosted_runner::{
    HostedRunner, join_and_approve, run_a_task_from, start_host_pairing,
    start_runner_beside_host,
};
use crate::support::hosting_steps::read_hosted_address;
use crate::support::runner_access::{
    open_runner, sample_heartbeat, test_runtime,
};
use crate::support::server_backups::{
    TAKEOVER_SECONDS, pair_client_at, read_app_servers, start_backup_device,
    start_server_backup, wait_until_copied, wait_until_standing,
};
use crate::support::test_device::{
    RELAY_DISABLED, TestDevice, describe, fail,
};
use crate::support::waiting::wait_for;

const BACKUP_NAME: &str = "studio-mac";
const CLIENT_NAME: &str = "travel-laptop";
const SERVER_GROUP_FILE_NAME: &str = "server-group.json";
const GROUP_WITH_BACKUP_SIZE: usize = 2;
const MOST_SLOTS: u32 = 8;
const HEARTBEAT_CASES: u32 = 4;
const LEARNING_LIMIT: Duration = Duration::from_secs(60);
const DETECTION_SLACK: Duration = Duration::from_secs(40);

fn heartbeat_strategy() -> impl Strategy<Value = HeartbeatRequest> {
    (1..MOST_SLOTS)
        .prop_flat_map(|slots_total| (Just(slots_total), 0..=slots_total))
        .prop_map(|(slots_total, slots_busy)| HeartbeatRequest {
            slots_total,
            slots_busy,
            ..sample_heartbeat()
        })
}

fn read_stored_group(
    data_directory: &Path,
) -> Result<Option<ServerGroup>, String> {
    let device_files = DeviceFiles::open(data_directory).map_err(describe)?;
    device_files.load_server_group().map_err(describe)
}

fn wait_until_group_has_backup(
    data_directory: &Path,
) -> Result<ServerGroup, String> {
    wait_for(LEARNING_LIMIT, "the runner to learn the backup", || {
        let Some(group) = read_stored_group(data_directory)? else {
            return Ok(None);
        };
        let has_backup = group.members.len() == GROUP_WITH_BACKUP_SIZE;
        Ok(has_backup.then_some(group))
    })
}

#[test]
fn test_send_heartbeat_property_stores_the_group_of_the_app_server() {
    let Ok(prepared) = prepare_workspace() else {
        panic!("the workspace is prepared");
    };
    let Ok(runtime) = test_runtime() else {
        panic!("the runtime starts");
    };
    let Ok(runner) = open_runner(&prepared) else {
        panic!("the runner bridge opens");
    };
    let data_directory = prepared.device.data_directory.path();
    let group_path = data_directory.join(SERVER_GROUP_FILE_NAME);
    let mut test_runner = TestRunner::new(Config::with_cases(HEARTBEAT_CASES));

    let outcome = test_runner.run(&heartbeat_strategy(), |heartbeat| {
        if group_path.exists() {
            fs::remove_file(&group_path).map_err(fail)?;
        }
        let sending = runner.send_heartbeat(&heartbeat);
        runtime.block_on(sending).map_err(fail)?;
        let stored = read_stored_group(data_directory).map_err(fail)?;
        prop_assert_eq!(stored, Some(ServerGroup::default()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_send_heartbeat_property_a_runner_learns_a_backup_and_fails_over() {
    let Ok(nodes) = start_runner_beside_host(RELAY_DISABLED) else {
        panic!("the hosting device and the runner start");
    };
    let address =
        read_hosted_address(&nodes.hosting.device).unwrap_or_default();
    let Ok(backup) = start_backup_device() else {
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
        runner: _runner,
        workspace_id,
        records: _records,
        runner_data,
    } = nodes;

    let started = start_server_backup(&backup);
    let learned = wait_until_group_has_backup(runner_data.path());
    let client_view = read_app_servers(&client);
    let copied = wait_until_copied(&hosting.device, &backup);
    let _stopped_hosting = hosting.device.stop();
    let takeover_limit =
        Duration::from_secs(TAKEOVER_SECONDS) + DETECTION_SLACK;
    let took_over = wait_until_standing(&backup, "active", takeover_limit);
    let task_run = run_a_task_from(&client, &workspace_id);

    assert!(started.is_ok(), "{started:?}");
    assert!(learned.is_ok(), "{learned:?}");
    assert!(client_view.is_ok(), "{client_view:?}");
    assert!(copied.is_ok(), "{copied:?}");
    assert!(took_over.is_ok(), "{took_over:?}");
    let Ok(task_run) = task_run else {
        panic!("the runner finishes a task after the takeover: {task_run:?}");
    };
    assert_eq!(task_run["run"]["status"], "done");
}
