use std::sync::OnceLock;

use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use proptest::sample::select;
use proptest::test_runner::TestCaseError;
use serde_json::Value;

use crate::command_device::{BareNode, CommandDevice};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

pub const UNIT_COMMAND_CASES: u32 = 24;
pub const AGENT_LOGIN_UNIT_COMMANDS: [&str; 4] = [
    "agent_login_status",
    "read_agent_login",
    "stop_agent_login",
    "forget_agent_credential",
];
pub const APPROVAL_UNIT_COMMANDS: [&str; 1] = ["list_approvals"];
pub const DEVICE_UNIT_COMMANDS: [&str; 3] =
    ["list_devices", "list_workspaces", "list_audit"];
pub const PAIRING_UNIT_COMMANDS: [&str; 2] = ["start_pairing", "join_status"];
pub const RUN_UNIT_COMMANDS: [&str; 1] = ["list_person_steps"];
pub const SERVER_BACKUP_UNIT_COMMANDS: [&str; 2] =
    ["start_server_backup", "stop_server_backup"];
const COMMAND_FIELD: &str = "command";
const STRAY_FIELD_PATTERN: &str = "[a-z_]{1,16}";
const INVALID_ARGUMENTS_START: &str = "invalid arguments for";

static FRESH_DEVICE: OnceLock<Result<TestDevice, String>> = OnceLock::new();
static SERVED_NODE: OnceLock<Result<ServedNode, String>> = OnceLock::new();

#[derive(Debug)]
pub struct ServedNode {
    node: BareNode,
    server: TestServer,
}

impl ServedNode {
    fn open() -> Result<Self, String> {
        let server = TestServer::start()?;
        let node = BareNode::open(PeerRelayChoice::Disabled)?;
        let account_command = serde_json::json!({
            "command": "create_account",
            "server_address": server.address,
            "setup_code": server.read_setup_code()?,
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        });
        node.run(&account_command)?;
        Ok(Self { node, server })
    }
}

pub fn unit_command_strategy(
    names: &'static [&'static str],
) -> impl Strategy<Value = &'static str> {
    select(names)
}

pub fn stray_field_strategy() -> impl Strategy<Value = String> {
    STRAY_FIELD_PATTERN
        .prop_filter("not the command field", |field| field != COMMAND_FIELD)
}

pub fn check_stray_field_is_refused(
    name: &str,
    stray_field: &str,
    stray_value: Value,
) -> Result<(), TestCaseError> {
    let device = shared_fresh_device()?;
    let command = build_command(name, Some((stray_field, stray_value)));

    let refusal = device.run(&command).err().unwrap_or_default();

    let expected_start = format!("{INVALID_ARGUMENTS_START} {name}:");
    prop_assert!(refusal.starts_with(&expected_start), "{}", refusal);
    prop_assert!(refusal.contains(stray_field), "{}", refusal);
    Ok(())
}

pub fn check_bare_command_parses(
    name: &str,
    repeat_count: usize,
) -> Result<(), TestCaseError> {
    let device = shared_fresh_device()?;
    let command = build_command(name, None);

    for _ in 0..repeat_count {
        let outcome = device.run(&command);
        let problem = outcome.err().unwrap_or_default();
        prop_assert!(
            !problem.starts_with(INVALID_ARGUMENTS_START),
            "{}",
            problem
        );
    }
    Ok(())
}

pub fn check_refused_command_stays_local(
    name: &str,
    stray_field: &str,
    stray_value: Value,
) -> Result<(), TestCaseError> {
    let served = shared_served_node()?;
    let command = build_command(name, Some((stray_field, stray_value)));
    let requests_before = served.server.recorded_requests().len();

    let refusal = served.node.run(&command).err().unwrap_or_default();

    let requests_after = served.server.recorded_requests().len();
    prop_assert!(refusal.starts_with(INVALID_ARGUMENTS_START), "{}", refusal);
    prop_assert_eq!(requests_after, requests_before);
    Ok(())
}

fn build_command(name: &str, stray: Option<(&str, Value)>) -> Value {
    let mut command = Value::Object(serde_json::Map::new());
    command[COMMAND_FIELD] = Value::from(name);
    if let Some((stray_field, stray_value)) = stray {
        command[stray_field] = stray_value;
    }
    command
}

fn shared_fresh_device() -> Result<&'static TestDevice, TestCaseError> {
    let started_device = FRESH_DEVICE.get_or_init(TestDevice::start);
    started_device.as_ref().map_err(fail)
}

fn shared_served_node() -> Result<&'static ServedNode, TestCaseError> {
    let opened_node = SERVED_NODE.get_or_init(ServedNode::open);
    opened_node.as_ref().map_err(fail)
}
