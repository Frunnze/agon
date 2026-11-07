use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::{Value, json};

pub const ERROR_FIELD: &str = "error";
pub const ERROR_KIND_FIELD: &str = "error_kind";
pub const SUCCESS_FIELD: &str = "ok";
pub const NO_ACCOUNT_KIND: &str = "no_account";
pub const NO_ACCOUNT_MESSAGE: &str = "this device has no account yet";
pub const NO_ACCOUNT_COMMANDS: [&str; 3] =
    ["list_workspaces", "list_devices", POLL_EVENTS_COMMAND];
const POLL_EVENTS_COMMAND: &str = "poll_events";
const ERROR_SHAPE_COUNT: usize = 8;
const LINE_BREAKS: [char; 2] = ['\n', '\r'];

#[derive(Clone, Debug)]
pub struct ErrorRecipe {
    pub shape: usize,
    pub text: String,
}

impl ErrorRecipe {
    pub fn build(&self) -> NodeError {
        let text = self.text.clone();
        match self.shape {
            0 => NodeError::NoAccount,
            1 => NodeError::InvalidCommand(text),
            2 => NodeError::Startup(text),
            3 => NodeError::ServerUnreachable(text),
            4 => NodeError::ServerRejected {
                status: 401,
                message: text,
            },
            5 => NodeError::NoAppServer,
            6 => NodeError::AccountExists,
            _ => NodeError::DraftFailed(text),
        }
    }

    pub fn is_no_account(&self) -> bool {
        self.shape == 0
    }
}

pub fn error_recipe_strategy() -> impl Strategy<Value = ErrorRecipe> {
    let text = prop_oneof![
        Just(NO_ACCOUNT_MESSAGE.to_owned()),
        Just(NO_ACCOUNT_KIND.to_owned()),
        any::<String>(),
    ];
    (0..ERROR_SHAPE_COUNT, text)
        .prop_map(|(shape, text)| ErrorRecipe { shape, text })
}

pub fn kindless_recipe_strategy() -> impl Strategy<Value = ErrorRecipe> {
    error_recipe_strategy()
        .prop_filter("kindless", |recipe| !recipe.is_no_account())
}

pub fn build_account_command(name: &str, after: u64) -> Value {
    if name == POLL_EVENTS_COMMAND {
        return json!({ "command": name, "after": after });
    }
    json!({ "command": name })
}

pub fn no_account_reply() -> Value {
    json!({
        ERROR_FIELD: NO_ACCOUNT_MESSAGE,
        ERROR_KIND_FIELD: NO_ACCOUNT_KIND,
    })
}

pub fn is_one_line(reply_text: &str) -> bool {
    !reply_text.contains(LINE_BREAKS)
}

pub fn read_kind(reply: &Value) -> Option<&str> {
    reply.get(ERROR_KIND_FIELD).and_then(Value::as_str)
}
