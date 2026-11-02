use std::fs;
use std::path::{Path, PathBuf};

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::git_origin::run_git;
use crate::support::test_device::{describe, fail, read_text};

const FOLDER_CASES: u32 = 6;
const OTHER_DEVICE: &str = "77b1e0";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn read_device_id(prepared: &PreparedWorkspace) -> Result<String, String> {
    let status = prepared.device.run(&json!({ "command": "status" }))?;
    read_text(&status, "/device_id")
}

fn create_git_folder(
    parent: &Path,
    name: &str,
    branch: &str,
) -> Result<PathBuf, String> {
    let folder = parent.join(name);
    fs::create_dir_all(&folder).map_err(describe)?;
    let initial_branch = format!("--initial-branch={branch}");
    run_git(&folder, &["init", "--quiet", &initial_branch])?;
    fs::write(folder.join("README.md"), "hello").map_err(describe)?;
    run_git(&folder, &["add", "--all"])?;
    run_git(&folder, &["commit", "--quiet", "--message", "Start"])?;
    Ok(folder)
}

fn check_folder(
    prepared: &PreparedWorkspace,
    path: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "check_local_folder",
        "path": path,
    }))
}

fn create_project_with(
    prepared: &PreparedWorkspace,
    address: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_project",
        "workspace_id": prepared.workspace_id,
        "name": "billing",
        "repositories": [{
            "address": address,
            "default_branch": "main",
            "agent_access": "push_after_approval",
        }],
    }))
}

#[test]
fn test_check_local_folder_property_names_this_device_and_its_branch() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let strategy = ("[a-z][a-z0-9]{0,8}", "[a-z][a-z0-9-]{0,8}[a-z0-9]");

    let outcome = runner.run(&strategy, |(name, branch)| {
        let parent = TempDir::new().map_err(fail)?;
        let folder =
            create_git_folder(parent.path(), &name, &branch).map_err(fail)?;
        let path = folder.display().to_string();
        let device_id = read_device_id(&prepared).map_err(fail)?;

        let checked =
            check_folder(&prepared, &format!("{path}/")).map_err(fail)?;

        let expected_address = format!("local:{device_id}:{path}");
        prop_assert_eq!(&checked["address"], &json!(expected_address));
        prop_assert_eq!(&checked["default_branch"], &json!(branch));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_local_folder_property_refuses_what_is_not_a_repository() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&"[a-z][a-z0-9]{0,8}", |name| {
        let parent = TempDir::new().map_err(fail)?;
        let plain_folder = parent.path().join(&name);
        fs::create_dir_all(&plain_folder).map_err(fail)?;
        let missing_folder = parent.path().join(format!("{name}-missing"));
        let relative_folder = name.clone();

        let plain =
            check_folder(&prepared, &plain_folder.display().to_string());
        let missing =
            check_folder(&prepared, &missing_folder.display().to_string());
        let relative = check_folder(&prepared, &relative_folder);

        let plain_problem = plain.err().unwrap_or_default();
        let missing_problem = missing.err().unwrap_or_default();
        let relative_problem = relative.err().unwrap_or_default();
        prop_assert!(plain_problem.contains("is not a git repository"));
        prop_assert!(missing_problem.contains("does not exist"));
        prop_assert!(relative_problem.contains("not an absolute path"));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_project_property_takes_only_folders_of_this_device() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&"[a-z][a-z0-9]{0,8}", |name| {
        let parent = TempDir::new().map_err(fail)?;
        let folder =
            create_git_folder(parent.path(), &name, "main").map_err(fail)?;
        let path = folder.display().to_string();
        let checked = check_folder(&prepared, &path).map_err(fail)?;
        let own_address = read_text(&checked, "/address").map_err(fail)?;
        let foreign_address = format!("local:{OTHER_DEVICE}:{path}");
        let gone_address = format!("{own_address}-gone");

        let own = create_project_with(&prepared, &own_address);
        let foreign = create_project_with(&prepared, &foreign_address);
        let gone = create_project_with(&prepared, &gone_address);

        let own = own.map_err(fail)?;
        prop_assert_eq!(
            &own["repositories"][0]["address"],
            &json!(own_address)
        );
        let foreign_problem = foreign.err().unwrap_or_default();
        let gone_problem = gone.err().unwrap_or_default();
        prop_assert!(foreign_problem.contains("is on another computer"));
        prop_assert!(gone_problem.contains("does not exist"));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
