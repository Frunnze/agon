use std::ffi::CString;

use orchestration_ffi::orchestration_start;
use serde_json::Value;

use super::replies::take_reply;

pub fn start_with(configuration: &Value) -> Value {
    let Ok(configuration_text) = CString::new(configuration.to_string())
    else {
        return Value::Null;
    };
    let reply_pointer =
        unsafe { orchestration_start(configuration_text.as_ptr()) };
    take_reply(reply_pointer)
}
