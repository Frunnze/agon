use std::ffi::{CStr, CString, c_char};

use orchestration_ffi::{
    orchestration_free_string, orchestration_handle_command,
};
use serde_json::Value;

pub fn take_reply(reply_pointer: *mut c_char) -> Value {
    if reply_pointer.is_null() {
        return Value::Null;
    }
    let reply_text = unsafe { CStr::from_ptr(reply_pointer) }
        .to_string_lossy()
        .into_owned();
    unsafe { orchestration_free_string(reply_pointer) };
    serde_json::from_str(&reply_text).unwrap_or(Value::Null)
}

pub fn handle_bytes(command_bytes: &[u8]) -> Value {
    let Ok(command_text) = CString::new(command_bytes.to_vec()) else {
        return Value::Null;
    };
    let reply_pointer =
        unsafe { orchestration_handle_command(command_text.as_ptr()) };
    take_reply(reply_pointer)
}

pub fn is_defined_reply(reply: &Value) -> bool {
    let Some(fields) = reply.as_object() else {
        return false;
    };
    let has_success = fields.contains_key("ok");
    let has_error = fields.get("error").is_some_and(Value::is_string);
    fields.len() == 1 && (has_success || has_error)
}
