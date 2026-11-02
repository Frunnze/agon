use std::io::{self, BufRead, Write};
use std::process::ExitCode;

use orchestration_node::command_reply::{
    render_error_reply, render_success_reply,
};
use orchestration_node::node_runtime::NodeRuntime;
use serde_json::Value;

const MISSING_CONFIGURATION: &str =
    "the first input line must be the node configuration";

fn main() -> ExitCode {
    let standard_input = io::stdin();
    let mut input_lines = standard_input.lock().lines();
    let mut standard_output = io::stdout().lock();

    let Some(Ok(configuration)) = input_lines.next() else {
        return fail_with(&mut standard_output, MISSING_CONFIGURATION);
    };
    let node_runtime = match NodeRuntime::start(&configuration) {
        Ok(node_runtime) => node_runtime,
        Err(problem) => {
            return fail_with(&mut standard_output, &problem.to_string());
        }
    };
    let started_reply = render_success_reply(&Value::Null);
    if writeln!(standard_output, "{started_reply}").is_err() {
        return ExitCode::FAILURE;
    }

    for input_line in input_lines {
        let Ok(command) = input_line else {
            return ExitCode::FAILURE;
        };
        let reply = node_runtime.handle_command(&command);
        if writeln!(standard_output, "{reply}").is_err() {
            return ExitCode::FAILURE;
        }
    }
    ExitCode::SUCCESS
}

fn fail_with(standard_output: &mut impl Write, message: &str) -> ExitCode {
    let reply = render_error_reply(message);
    let _written = writeln!(standard_output, "{reply}");
    ExitCode::FAILURE
}
