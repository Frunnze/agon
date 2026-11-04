use std::fs;
use std::path::Path;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::command_builders::PreparedWorkspace;
use crate::support::folder_checks::prepared_or_panic;
use crate::support::git_origin::run_git;
use crate::support::test_device::{fail, read_text};

const CREATION_CASES: u32 = 6;
const FOLDER_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const STARTED_BRANCH: &str = "main";
const MISSING_PARENT_NAME: &str = "missing-parent";

fn create_folder(
    prepared: &PreparedWorkspace,
    parent: &Path,
    name: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_local_folder",
        "parent": parent.display().to_string(),
        "name": name,
    }))
}

fn read_device_id(prepared: &PreparedWorkspace) -> Result<String, String> {
    let status = prepared.device.run(&json!({ "command": "status" }))?;
    read_text(&status, "/device_id")
}

#[test]
fn test_create_local_folder_property_makes_a_started_git_folder() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CREATION_CASES));

    let outcome = runner.run(&FOLDER_NAME_PATTERN, |name| {
        let parent = TempDir::new().map_err(fail)?;
        let folder = parent.path().join(&name);
        let device_id = read_device_id(&prepared).map_err(fail)?;

        let created =
            create_folder(&prepared, parent.path(), &name).map_err(fail)?;

        let expected_address =
            format!("local:{device_id}:{}", folder.display());
        prop_assert_eq!(&created["address"], &json!(expected_address));
        prop_assert_eq!(&created["default_branch"], &json!(STARTED_BRANCH));
        prop_assert_eq!(&created["has_started_git"], &json!(true));
        prop_assert!(folder.is_dir());
        let branch = run_git(&folder, &["symbolic-ref", "--short", "HEAD"])
            .map_err(fail)?;
        prop_assert_eq!(branch, STARTED_BRANCH);
        let commits = run_git(&folder, &["rev-list", "--count", "HEAD"])
            .map_err(fail)?;
        prop_assert_eq!(commits, "1");
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_local_folder_property_refuses_an_existing_folder() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CREATION_CASES));

    let outcome = runner.run(&FOLDER_NAME_PATTERN, |name| {
        let parent = TempDir::new().map_err(fail)?;
        let folder = parent.path().join(&name);
        fs::create_dir(&folder).map_err(fail)?;

        let refused = create_folder(&prepared, parent.path(), &name);

        let problem = refused.err().unwrap_or_default();
        prop_assert!(problem.contains("already exists"), "{}", problem);
        let leftovers = fs::read_dir(&folder).map_err(fail)?.count();
        prop_assert_eq!(leftovers, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_local_folder_property_refuses_a_missing_parent() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CREATION_CASES));

    let outcome = runner.run(&FOLDER_NAME_PATTERN, |name| {
        let parent = TempDir::new().map_err(fail)?;
        let missing_parent = parent.path().join(MISSING_PARENT_NAME);

        let refused = create_folder(&prepared, &missing_parent, &name);

        let problem = refused.err().unwrap_or_default();
        prop_assert!(problem.contains("does not exist"), "{}", problem);
        prop_assert!(!missing_parent.exists());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_local_folder_property_refuses_unsafe_names() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(CREATION_CASES));
    let strategy = prop_oneof![
        Just(String::new()),
        Just("..".to_owned()),
        "[a-z]{1,4}/[a-z]{1,4}",
    ];

    let outcome = runner.run(&strategy, |name| {
        let parent = TempDir::new().map_err(fail)?;

        let refused = create_folder(&prepared, parent.path(), &name);

        let problem = refused.err().unwrap_or_default();
        prop_assert!(
            problem.contains("cannot name a new folder"),
            "{}",
            problem
        );
        let made_folders = fs::read_dir(parent.path()).map_err(fail)?.count();
        prop_assert_eq!(made_folders, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
