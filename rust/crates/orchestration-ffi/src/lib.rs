#![allow(clippy::missing_safety_doc)]

use std::ffi::{CStr, CString, c_char};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::{Arc, PoisonError, RwLock};

use orchestration_node::command_reply::{
    render_error_reply, render_success_reply,
};
use orchestration_node::node_configuration::NodeConfiguration;
use orchestration_node::node_runtime::NodeRuntime;
use serde_json::Value;

type SharedRuntime = Option<Arc<NodeRuntime>>;

static NODE_RUNTIME: RwLock<SharedRuntime> = RwLock::new(None);

const NULL_INPUT_MESSAGE: &str = "the input pointer is null";
const INVALID_TEXT_MESSAGE: &str = "the input is not valid UTF-8 text";
const NOT_STARTED_MESSAGE: &str =
    "the node has not started, call orchestration_start first";
const PANIC_MESSAGE: &str = "the node failed unexpectedly during the call";
const UNENCODABLE_REPLY: &CStr =
    c"{\"error\":\"the reply could not be encoded\"}";

#[unsafe(no_mangle)]
pub unsafe extern "C" fn orchestration_start(
    configuration_json: *const c_char,
) -> *mut c_char {
    let reply = match unsafe { read_input(configuration_json) } {
        Ok(configuration) => guard_call(|| start_node(&configuration)),
        Err(message) => render_error_reply(message),
    };
    into_raw_reply(reply)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn orchestration_handle_command(
    command_json: *const c_char,
) -> *mut c_char {
    let reply = match unsafe { read_input(command_json) } {
        Ok(command) => guard_call(|| handle_command(&command)),
        Err(message) => render_error_reply(message),
    };
    into_raw_reply(reply)
}

#[unsafe(no_mangle)]
pub extern "C" fn orchestration_stop() -> *mut c_char {
    into_raw_reply(guard_call(stop_node))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn orchestration_free_string(text: *mut c_char) {
    if text.is_null() {
        return;
    }
    drop(unsafe { CString::from_raw(text) });
}

unsafe fn read_input(input: *const c_char) -> Result<String, &'static str> {
    if input.is_null() {
        return Err(NULL_INPUT_MESSAGE);
    }
    let input_text = unsafe { CStr::from_ptr(input) };
    let checked_text =
        input_text.to_str().map_err(|_| INVALID_TEXT_MESSAGE)?;
    Ok(checked_text.to_owned())
}

fn guard_call(call: impl FnOnce() -> String) -> String {
    catch_unwind(AssertUnwindSafe(call))
        .unwrap_or_else(|_| render_error_reply(PANIC_MESSAGE))
}

fn start_node(configuration_json: &str) -> String {
    let configuration = match NodeConfiguration::from_json(configuration_json)
    {
        Ok(configuration) => configuration,
        Err(error) => return render_error_reply(&error.to_string()),
    };

    let mut shared_runtime =
        NODE_RUNTIME.write().unwrap_or_else(PoisonError::into_inner);
    let previous_runtime = shared_runtime.take();
    drop(previous_runtime);

    let runtime = match NodeRuntime::start_configured(&configuration) {
        Ok(runtime) => runtime,
        Err(error) => return render_error_reply(&error.to_string()),
    };
    *shared_runtime = Some(Arc::new(runtime));
    render_success_reply(&Value::Null)
}

fn stop_node() -> String {
    let stopped_runtime = NODE_RUNTIME
        .write()
        .unwrap_or_else(PoisonError::into_inner)
        .take();
    drop(stopped_runtime);
    render_success_reply(&Value::Null)
}

fn handle_command(command: &str) -> String {
    let current_runtime = NODE_RUNTIME
        .read()
        .unwrap_or_else(PoisonError::into_inner)
        .clone();
    match current_runtime {
        Some(runtime) => runtime.handle_command(command),
        None => render_error_reply(NOT_STARTED_MESSAGE),
    }
}

fn into_raw_reply(reply: String) -> *mut c_char {
    match CString::new(reply) {
        Ok(reply_text) => reply_text.into_raw(),
        Err(_) => UNENCODABLE_REPLY.to_owned().into_raw(),
    }
}
