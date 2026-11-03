use serde_json::{Value, json};

use super::command_builders::{PreparedWorkspace, prepare_workspace};

pub fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

pub fn check_folder(
    prepared: &PreparedWorkspace,
    path: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "check_local_folder",
        "path": path,
    }))
}
