use orchestration_core::protected_files::DEFAULT_PROTECTED_PATTERNS;
use proptest::collection::btree_set;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::test_device::{TestDevice, fail};

const PROTECTED_FILES_CASES: u32 = 4;

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn default_patterns() -> Value {
    json!(DEFAULT_PROTECTED_PATTERNS.to_vec())
}

fn listed_patterns(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Value, String> {
    let views = device.run(&json!({ "command": "list_workspaces" }))?;
    for view in views.as_array().cloned().unwrap_or_default() {
        if view["workspace"]["id"] == json!(workspace_id) {
            let workspace = &view["workspace"];
            return Ok(workspace["protected_files"]["patterns"].clone());
        }
    }
    Err(format!("workspace {workspace_id} is not listed"))
}

fn set_patterns(
    device: &TestDevice,
    workspace_id: &str,
    patterns: &[String],
) -> Result<Value, String> {
    device.run(&json!({
        "command": "set_protected_files",
        "workspace_id": workspace_id,
        "patterns": patterns,
    }))
}

#[test]
fn test_list_workspaces_shows_the_default_protected_files() {
    let prepared = prepared_or_panic();

    let patterns = listed_patterns(&prepared.device, &prepared.workspace_id);

    assert_eq!(patterns, Ok(default_patterns()));
}

#[test]
fn test_set_protected_files_property_the_list_is_kept() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let workspace_id = prepared.workspace_id.as_str();
    let patterns = btree_set("~/\\.[a-z]{1,8}|[a-z]{1,8}\\.pem", 0..5);
    let mut runner =
        TestRunner::new(Config::with_cases(PROTECTED_FILES_CASES));

    let outcome = runner.run(&patterns, |chosen| {
        let chosen: Vec<String> = chosen.into_iter().collect();

        let answered =
            set_patterns(device, workspace_id, &chosen).map_err(fail)?;

        let listed = listed_patterns(device, workspace_id).map_err(fail)?;
        prop_assert_eq!(
            &answered["protected_files"]["patterns"],
            &json!(chosen)
        );
        prop_assert_eq!(listed, json!(chosen));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_reset_protected_files_brings_back_the_defaults() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let workspace_id = prepared.workspace_id.as_str();
    let only_keys = vec!["*.pem".to_owned()];
    let set = set_patterns(device, workspace_id, &only_keys);
    assert!(set.is_ok(), "{set:?}");

    let reset = device.run(&json!({
        "command": "reset_protected_files",
        "workspace_id": workspace_id,
    }));

    let answered = reset
        .map(|workspace| workspace["protected_files"]["patterns"].clone());
    assert_eq!(answered, Ok(default_patterns()));
    let listed = listed_patterns(device, workspace_id);
    assert_eq!(listed, Ok(default_patterns()));
}

#[test]
fn test_set_protected_files_refuses_an_invalid_pattern() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let workspace_id = prepared.workspace_id.as_str();
    let invalid = vec!["~/../secret".to_owned()];

    let refused = set_patterns(device, workspace_id, &invalid);

    let problem = refused.err().unwrap_or_default();
    assert!(problem.contains(".."), "{problem}");
    let listed = listed_patterns(device, workspace_id);
    assert_eq!(listed, Ok(default_patterns()));
}
