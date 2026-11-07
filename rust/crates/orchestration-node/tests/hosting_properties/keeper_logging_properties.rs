use std::fs::{self, Permissions};
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use serde_json::json;

use crate::backup_group::{
    STEADY_TAKEOVER_SECONDS, pair_a_keeping_device, start_backup_group,
};
use crate::hosting_desk::{heavy_cases, read_own_group};
use crate::logged_host::count_lines_starting;
use crate::process_group::{
    ProcessBackup, move_backup_into_a_process,
    move_paired_device_into_a_process, revoke_the_backup,
    wait_for_logged_line,
};
use crate::support::server_backups::create_project;
use crate::support::test_device::fail;

const KEEPER_LINE_START: &str = "the app server group keeper hit a problem: ";
const REMOVAL_LINE: &str = "the app server group keeper hit a problem: \
                            this device no longer keeps the app server";
const CLEANUP_LINE_START: &str =
    "the unfinished app server backup was not removed: ";
const NOT_REMOVED_TEXT: &str =
    "the app server on this device could not be removed: ";
const SERVER_FAILED_START: &str = "the app server on this device failed: ";
const HOSTED_SERVER_DIRECTORY: &str = "hosted-app-server";
const STATE_FILE_NAME: &str = "state.json";
const LOCKED_FOLDER_NAME: &str = "locked";
const KEPT_FILE_NAME: &str = "kept";
const READ_ONLY_FOLDER_MODE: u32 = 0o500;
const OWNER_FOLDER_MODE: u32 = 0o700;
const QUIET_PERIOD: Duration = Duration::from_secs(8);
const PROJECT_PREFIX: &str = "logged-project";

#[derive(Debug)]
struct LockedFolder {
    path: PathBuf,
}

impl Drop for LockedFolder {
    fn drop(&mut self) {
        let unlocked = Permissions::from_mode(OWNER_FOLDER_MODE);
        let _restored = fs::set_permissions(&self.path, unlocked);
    }
}

fn start_process_backup() -> Result<ProcessBackup, TestCaseError> {
    let group = start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
    move_backup_into_a_process(group, STEADY_TAKEOVER_SECONDS).map_err(fail)
}

fn start_paired_process() -> Result<ProcessBackup, TestCaseError> {
    let paired =
        pair_a_keeping_device(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
    move_paired_device_into_a_process(paired, STEADY_TAKEOVER_SECONDS)
        .map_err(fail)
}

fn block_the_first_copy(
    data_directory: &Path,
) -> Result<PathBuf, TestCaseError> {
    let server_directory = data_directory.join(HOSTED_SERVER_DIRECTORY);
    fs::create_dir_all(server_directory.join(STATE_FILE_NAME))
        .map_err(fail)?;
    Ok(server_directory)
}

fn lock_a_folder(
    server_directory: &Path,
) -> Result<LockedFolder, TestCaseError> {
    let path = server_directory.join(LOCKED_FOLDER_NAME);
    fs::create_dir_all(&path).map_err(fail)?;
    fs::write(path.join(KEPT_FILE_NAME), KEPT_FILE_NAME).map_err(fail)?;
    let locked = Permissions::from_mode(READ_ONLY_FOLDER_MODE);
    fs::set_permissions(&path, locked).map_err(fail)?;
    Ok(LockedFolder { path })
}

fn write_projects(
    backup: &ProcessBackup,
    project_count: usize,
) -> Result<(), TestCaseError> {
    for index in 0..project_count {
        let name = format!("{PROJECT_PREFIX}-{index}");
        create_project(&backup.hosting.device, &backup.workspace_id, &name)
            .map_err(fail)?;
    }
    Ok(())
}

fn start_the_backup(
    backup: &mut ProcessBackup,
) -> Result<String, TestCaseError> {
    let started = backup
        .host
        .run(&json!({ "command": "start_server_backup" }));
    match started {
        Ok(view) => Err(fail(format!("the backup started: {view}"))),
        Err(problem) => Ok(problem),
    }
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_log_keeper_problem_property_a_revoked_backup_logs_its_removal(
        _round in 0_u8..1,
    ) {
        let backup = start_process_backup()?;

        revoke_the_backup(&backup).map_err(fail)?;
        let logged =
            wait_for_logged_line(&backup.host, KEEPER_LINE_START)
                .map_err(fail)?;

        prop_assert_eq!(logged, REMOVAL_LINE);
    }

    #[test]
    fn test_log_keeper_problem_property_a_steady_backup_logs_nothing(
        project_count in 1_usize..3,
    ) {
        let backup = start_process_backup()?;

        write_projects(&backup, project_count)?;
        thread::sleep(QUIET_PERIOD);
        let lines = backup.host.stop().map_err(fail)?;

        prop_assert_eq!(count_lines_starting(&lines, KEEPER_LINE_START), 0);
    }

    #[test]
    fn test_log_keeper_problem_property_the_keeper_falls_silent_after_removal(
        project_count in 1_usize..3,
    ) {
        let backup = start_process_backup()?;

        revoke_the_backup(&backup).map_err(fail)?;
        wait_for_logged_line(&backup.host, KEEPER_LINE_START).map_err(fail)?;
        write_projects(&backup, project_count)?;
        thread::sleep(QUIET_PERIOD);
        let lines = backup.host.stop().map_err(fail)?;

        prop_assert_eq!(count_lines_starting(&lines, KEEPER_LINE_START), 1);
    }

    #[test]
    fn test_log_backup_cleanup_problem_property_an_unremovable_copy_is_logged(
        _round in 0_u8..1,
    ) {
        let mut backup = start_paired_process()?;
        let server_directory =
            block_the_first_copy(backup.data_directory.path())?;
        let locked = lock_a_folder(&server_directory)?;

        start_the_backup(&mut backup)?;
        let logged = wait_for_logged_line(&backup.host, CLEANUP_LINE_START)
            .map_err(fail)?;
        drop(locked);

        let expected_start = format!("{CLEANUP_LINE_START}{NOT_REMOVED_TEXT}");
        prop_assert!(logged.starts_with(&expected_start), "{logged}");
    }

    #[test]
    fn test_log_backup_cleanup_problem_property_the_caller_hears_the_copy(
        _round in 0_u8..1,
    ) {
        let mut backup = start_paired_process()?;
        let server_directory =
            block_the_first_copy(backup.data_directory.path())?;
        let locked = lock_a_folder(&server_directory)?;

        let problem = start_the_backup(&mut backup)?;
        let view = read_own_group(&backup.hosting.device, backup.hosting.port)
            .map_err(fail)?;
        drop(locked);

        prop_assert!(problem.starts_with(SERVER_FAILED_START), "{problem}");
        prop_assert_eq!(view.group.members.len(), 1);
    }

    #[test]
    fn test_log_backup_cleanup_problem_property_a_clean_undo_logs_nothing(
        _round in 0_u8..1,
    ) {
        let mut backup = start_paired_process()?;
        let server_directory =
            block_the_first_copy(backup.data_directory.path())?;

        let problem = start_the_backup(&mut backup)?;
        let is_left = server_directory.exists();
        let lines = backup.host.stop().map_err(fail)?;

        prop_assert!(problem.starts_with(SERVER_FAILED_START), "{problem}");
        prop_assert!(!is_left);
        prop_assert_eq!(count_lines_starting(&lines, CLEANUP_LINE_START), 0);
    }
}
