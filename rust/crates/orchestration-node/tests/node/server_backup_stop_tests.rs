use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::Duration;

use serde_json::Value;

use crate::support::hosting_steps::{
    hosted_server_files, read_hosted_address, start_hosting_device,
};
use crate::support::server_backups::{
    create_project, pair_client_at, read_hosted_state, start_server_backup,
    start_steady_backup_device, stop_server_backup,
};
use crate::support::test_device::{TestDevice, read_text};
use crate::support::waiting::wait_for;

const BACKUP_NAME: &str = "studio-mac";
const STOP_ROUNDS: usize = 40;
const BUSY_PROJECT_PREFIX: &str = "busy-project";
const COPY_ARRIVAL_LIMIT: Duration = Duration::from_secs(30);
const MISSING_REVISION: &str = "the copied state has no revision";
const WRITER_PANICKED: &str = "the project writer panicked";

#[derive(Debug)]
struct BusyGroup<'devices> {
    hosting: &'devices TestDevice,
    backup: &'devices TestDevice,
    workspace_id: &'devices str,
}

fn keep_creating_projects(
    group: &BusyGroup<'_>,
    round: usize,
    is_writing: &AtomicBool,
) -> Result<(), String> {
    let mut created_count: usize = 0;
    while is_writing.load(Ordering::SeqCst) {
        let name = format!("{BUSY_PROJECT_PREFIX}-{round}-{created_count}");
        create_project(group.hosting, group.workspace_id, &name)?;
        created_count += 1;
    }
    Ok(())
}

fn read_copied_revision(backup: &TestDevice) -> Result<u64, String> {
    let copied_state = read_hosted_state(backup)?;
    let revision = copied_state["revision"].as_u64();
    revision.ok_or_else(|| MISSING_REVISION.to_owned())
}

fn wait_until_copies_arrive(
    backup: &TestDevice,
    seeded_revision: u64,
) -> Result<(), String> {
    wait_for(COPY_ARRIVAL_LIMIT, "fresh copies to arrive", || {
        let copied_revision = read_copied_revision(backup)?;
        Ok((copied_revision > seeded_revision).then_some(()))
    })
}

fn stop_while_copies_arrive(
    group: &BusyGroup<'_>,
    round: usize,
) -> Result<Value, String> {
    let seeded_revision = read_copied_revision(group.backup)?;
    let is_writing = AtomicBool::new(true);
    thread::scope(|scope| {
        let writer =
            scope.spawn(|| keep_creating_projects(group, round, &is_writing));

        let arrived = wait_until_copies_arrive(group.backup, seeded_revision);
        let stopped = arrived.and_then(|()| stop_server_backup(group.backup));
        is_writing.store(false, Ordering::SeqCst);

        let written = writer.join().map_err(|_| WRITER_PANICKED.to_owned())?;
        written?;
        stopped
    })
}

#[test]
fn test_stop_server_backup_property_stops_cleanly_while_copies_arrive() {
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
    let group = BusyGroup {
        hosting: &hosting.device,
        backup: &backup,
        workspace_id: &workspace_id,
    };
    let [server_directory, _server_record] = hosted_server_files(&backup);

    for round in 0..STOP_ROUNDS {
        assert!(!server_directory.exists(), "before round {round}");
        let started = start_server_backup(&backup);
        assert!(started.is_ok(), "round {round}: {started:?}");

        let stopped = stop_while_copies_arrive(&group, round);

        assert!(stopped.is_ok(), "round {round}: {stopped:?}");
        assert!(!server_directory.exists(), "round {round}");
    }
}
