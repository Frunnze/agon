use std::sync::OnceLock;

use orchestration_node::commands::command_names;
use proptest::prelude::*;
use serde_json::Value;

use crate::support::command_strategies::arbitrary_command_strategy;
use crate::support::test_device::{
    TestDevice, UNREACHABLE_SERVER_ADDRESS, fail, is_defined_reply,
};

const UNKNOWN_COMMAND_PREFIX: &str = "unknown command";
const FUZZ_CASES: u32 = 64;
const LONGEST_FUZZ_TEXT: usize = 300;

static SHARED_DEVICE: OnceLock<Result<TestDevice, String>> = OnceLock::new();

fn shared_device() -> Result<&'static TestDevice, TestCaseError> {
    let started_device = SHARED_DEVICE.get_or_init(TestDevice::start);
    started_device.as_ref().map_err(fail)
}

fn read_error(reply: &Value) -> Option<&str> {
    reply.get("error").and_then(Value::as_str)
}

fn arbitrary_text_strategy() -> impl Strategy<Value = String> {
    proptest::collection::vec(any::<char>(), 0..LONGEST_FUZZ_TEXT)
        .prop_map(String::from_iter)
}

#[test]
fn a_command_that_is_not_an_object_gives_a_defined_error() {
    let Ok(device) = TestDevice::start() else {
        panic!("the test device starts");
    };

    let reply = device.send(&serde_json::json!(["status"]));

    assert!(is_defined_reply(&reply));
    assert!(read_error(&reply).is_some());
}

#[test]
fn status_on_a_new_device_reports_no_account_and_no_server() {
    let Ok(device) = TestDevice::start() else {
        panic!("the test device starts");
    };

    let status = device.run(&serde_json::json!({ "command": "status" }));

    let Ok(status) = status else {
        panic!("status answers: {status:?}");
    };
    assert_eq!(status["server_reachable"], Value::Bool(false));
    assert_eq!(status["account"], Value::Null);
    assert_eq!(status["device_id"], Value::Null);
    assert_eq!(status["server_address"], Value::Null);
}

#[test]
fn an_account_on_an_unreachable_server_is_not_remembered() {
    let Ok(device) = TestDevice::start() else {
        panic!("the test device starts");
    };

    let created = device.run(&serde_json::json!({
        "command": "create_account",
        "server_address": UNREACHABLE_SERVER_ADDRESS,
        "setup_code": "123456",
        "device_name": "air-laptop",
        "role": "client",
        "workspace_name": "acme",
    }));
    let status = device.run(&serde_json::json!({ "command": "status" }));

    assert!(created.is_err());
    let Ok(status) = status else {
        panic!("status answers: {status:?}");
    };
    assert_eq!(status["server_address"], Value::Null);
    assert_eq!(status["account"], Value::Null);
}

#[test]
fn unknown_argument_fields_give_an_invalid_arguments_error() {
    let Ok(device) = TestDevice::start() else {
        panic!("the test device starts");
    };

    let reply = device.send(&serde_json::json!({
        "command": "list_projects",
        "workspace_id": "00000000-0000-0000-0000-000000000001",
        "surprise": true,
    }));

    let error = read_error(&reply).unwrap_or_default();
    assert!(
        error.starts_with("invalid arguments for list_projects"),
        "{error}"
    );
}

#[test]
fn command_names_are_unique_and_cover_the_contract() {
    let names = command_names();
    let mut sorted_names = names.clone();
    sorted_names.sort_unstable();
    sorted_names.dedup();
    let contract_names = [
        "status",
        "create_account",
        "start_pairing",
        "pairing_request",
        "approve_pairing",
        "reject_pairing",
        "cancel_pairing",
        "join_with_code",
        "join_status",
        "list_workspaces",
        "create_workspace",
        "list_projects",
        "create_project",
        "list_repositories",
        "create_repository",
        "list_workflows",
        "create_workflow",
        "list_skills",
        "create_skill",
        "list_rules",
        "create_rule",
        "update_skill",
        "delete_skill",
        "update_rule",
        "delete_rule",
        "list_tasks",
        "create_task",
        "list_jobs",
        "create_job",
        "list_runs",
        "list_approvals",
        "create_approval",
        "list_runners",
        "list_devices",
        "list_audit",
        "start_task",
        "cancel_run",
        "retry_run",
        "send_chat_message",
        "decide_approval",
        "sign_workflow",
        "discard_workflow_change",
        "draft_workflow",
        "change_workflow",
        "fill_agent_settings",
        "workflow_draft_status",
        "revoke_device",
        "remove_device_from_workspace",
        "pause_runner",
        "choose_agent_offers",
        "retry_server",
        "poll_events",
        "forget_this_device",
        "list_repository_branches",
        "list_repository_files",
        "read_repository_file",
        "delete_project",
        "delete_workflow",
        "delete_task",
        "delete_workspace",
    ];

    assert_eq!(sorted_names.len(), names.len());
    for contract_name in contract_names {
        assert!(names.contains(&contract_name), "{contract_name} is missing");
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FUZZ_CASES))]

    #[test]
    fn test_dispatch_command_property_every_command_name_is_known(
        name_position in any::<prop::sample::Index>(),
    ) {
        let device = shared_device()?;
        let names = command_names();
        let name = names[name_position.index(names.len())];

        let reply = device.send(&serde_json::json!({ "command": name }));

        prop_assert!(is_defined_reply(&reply));
        let error = read_error(&reply).unwrap_or_default();
        prop_assert!(!error.starts_with(UNKNOWN_COMMAND_PREFIX));
    }

    #[test]
    fn test_dispatch_command_property_unknown_names_give_a_defined_error(
        name in "[a-z_]{1,30}",
    ) {
        prop_assume!(!command_names().contains(&name.as_str()));
        let device = shared_device()?;

        let reply = device.send(&serde_json::json!({ "command": name }));

        let expected_error = format!("{UNKNOWN_COMMAND_PREFIX}: {name}");
        prop_assert_eq!(read_error(&reply), Some(expected_error.as_str()));
    }

    #[test]
    fn test_dispatch_command_property_arbitrary_text_never_panics(
        arbitrary_text in arbitrary_text_strategy(),
    ) {
        let device = shared_device()?;

        let reply_text = device.runtime.handle_command(&arbitrary_text);

        let reply: Value = serde_json::from_str(&reply_text).map_err(fail)?;
        prop_assert!(is_defined_reply(&reply));
    }

    #[test]
    fn test_dispatch_command_property_arbitrary_arguments_never_panic(
        command in arbitrary_command_strategy(),
    ) {
        let device = shared_device()?;

        let reply = device.send(&command);

        prop_assert!(is_defined_reply(&reply));
    }
}
