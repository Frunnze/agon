use std::collections::BTreeSet;
use std::sync::OnceLock;

use proptest::prelude::*;
use proptest::sample::select;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

pub const NODE_CASES: u32 = 3;
pub const PARSING_CASES: u32 = 32;
pub const ACCOUNT_FILE_NAME: &str = "account.json";
pub const SERVER_FILE_NAME: &str = "app-server.json";
pub const SERVER_GROUP_FILE_NAME: &str = "server-group.json";
pub const HOSTED_SERVER_FILE_NAME: &str = "hosted-app-server.json";
pub const DEVICE_NAME: &str = "air-laptop";
pub const WORKSPACE_NAME: &str = "acme";
pub const INVALID_NAME: &str = "Not A Name";
pub const INVALID_SERVER_ADDRESS: &str = "not a server address";
pub const SAMPLE_SETUP_CODE: &str = "ABC-DEF-GHJ-KMN";
pub const ROLE_NAMES: [&str; 3] = ["client", "runner", "client_and_runner"];
pub const ACCOUNT_COMMAND_NAMES: [&str; 6] = [
    "status",
    "create_account",
    "create_hosted_account",
    "retry_server",
    "poll_events",
    "forget_this_device",
];
const BLANK_CHARACTERS: [char; 8] = [
    ' ', '\t', '\n', '\r', '\u{a0}', '\u{2003}', '\u{3000}', '\u{200a}',
];
const LONGEST_BLANK_TEXT: usize = 6;

static FRESH_DEVICE: OnceLock<Result<TestDevice, String>> = OnceLock::new();

#[derive(Clone, Debug)]
pub struct AccountRequest {
    pub server_address: String,
    pub setup_code: String,
    pub device_name: String,
    pub role: String,
    pub workspace_name: String,
}

impl AccountRequest {
    pub fn for_server(server: &TestServer) -> Result<Self, TestCaseError> {
        Ok(Self {
            server_address: server.address.clone(),
            setup_code: server.read_setup_code().map_err(fail)?,
            device_name: DEVICE_NAME.to_owned(),
            role: ROLE_NAMES[0].to_owned(),
            workspace_name: WORKSPACE_NAME.to_owned(),
        })
    }

    pub fn to_command(&self) -> Value {
        json!({
            "command": "create_account",
            "server_address": self.server_address,
            "setup_code": self.setup_code,
            "device_name": self.device_name,
            "role": self.role,
            "workspace_name": self.workspace_name,
        })
    }
}

pub fn shared_fresh_device() -> Result<&'static TestDevice, TestCaseError> {
    let started_device = FRESH_DEVICE.get_or_init(TestDevice::start);
    started_device.as_ref().map_err(fail)
}

pub fn start_device_and_server()
-> Result<(TestDevice, TestServer), TestCaseError> {
    let server = TestServer::start().map_err(fail)?;
    let device = TestDevice::start().map_err(fail)?;
    Ok((device, server))
}

pub fn start_device_with_account()
-> Result<(TestDevice, TestServer, Value), TestCaseError> {
    let (device, server) = start_device_and_server()?;
    let request = AccountRequest::for_server(&server)?;
    let created = device.run(&request.to_command()).map_err(fail)?;
    Ok((device, server, created))
}

pub fn read_error(reply: &Value) -> String {
    let error = reply.get("error").and_then(Value::as_str);
    error.unwrap_or_default().to_owned()
}

pub fn read_status(device: &TestDevice) -> Result<Value, TestCaseError> {
    device.run(&json!({ "command": "status" })).map_err(fail)
}

pub fn retry_server(device: &TestDevice) -> Result<Value, TestCaseError> {
    device
        .run(&json!({ "command": "retry_server" }))
        .map_err(fail)
}

pub fn poll_events(
    device: &TestDevice,
    after: u64,
) -> Result<Value, TestCaseError> {
    let command = json!({ "command": "poll_events", "after": after });
    device.run(&command).map_err(fail)
}

pub fn has_data_file(device: &TestDevice, file_name: &str) -> bool {
    device.data_directory.path().join(file_name).exists()
}

pub fn harmless_command(name: &str) -> Value {
    match name {
        "poll_events" => json!({ "command": name, "after": 0 }),
        "create_account" => json!({
            "command": name,
            "server_address": INVALID_SERVER_ADDRESS,
            "setup_code": SAMPLE_SETUP_CODE,
            "device_name": DEVICE_NAME,
            "role": ROLE_NAMES[0],
            "workspace_name": WORKSPACE_NAME,
        }),
        "create_hosted_account" => json!({
            "command": name,
            "workspace_name": WORKSPACE_NAME,
            "device_name": INVALID_NAME,
            "role": ROLE_NAMES[0],
        }),
        _ => json!({ "command": name }),
    }
}

pub fn with_field(command: &Value, field: &str, field_value: Value) -> Value {
    let mut extended = command.clone();
    extended[field] = field_value;
    extended
}

pub fn valid_name_strategy() -> impl Strategy<Value = String> {
    "[a-z0-9][a-z0-9-]{0,24}"
}

pub fn invalid_name_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        blank_text_strategy(),
        "[a-z]{0,4}[A-Z][a-z]{0,4}",
        "[a-z]{0,4}[é漢😀 _.\u{200b}]{1,2}[a-z]{0,4}",
        "[a-z]{41,60}",
    ]
}

pub fn blank_text_strategy() -> impl Strategy<Value = String> {
    let blank_character = select(BLANK_CHARACTERS.to_vec());
    proptest::collection::vec(blank_character, 0..LONGEST_BLANK_TEXT)
        .prop_map(String::from_iter)
}

pub fn role_strategy() -> impl Strategy<Value = &'static str> {
    select(ROLE_NAMES.to_vec())
}

pub fn account_command_name_strategy() -> impl Strategy<Value = &'static str> {
    select(ACCOUNT_COMMAND_NAMES.to_vec())
}

pub fn read_field_names(view: &Value) -> BTreeSet<String> {
    let mut field_names = BTreeSet::new();
    if let Some(fields) = view.as_object() {
        for field_name in fields.keys() {
            field_names.insert(field_name.clone());
        }
    }
    field_names
}

pub fn collect_names(names: &[&str]) -> BTreeSet<String> {
    let mut collected = BTreeSet::new();
    for name in names {
        collected.insert((*name).to_owned());
    }
    collected
}
