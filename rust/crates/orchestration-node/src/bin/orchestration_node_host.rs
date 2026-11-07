use std::io::{self, BufRead, Write};
use std::process::ExitCode;

use orchestration_node::command_reply::{
    render_error_reply, render_node_error_reply, render_success_reply,
};
use orchestration_node::node_runtime::NodeRuntime;
use serde_json::Value;

const MISSING_CONFIGURATION: &str =
    "the first input line must be the node configuration";
const UNREADABLE_COMMAND: &str = "a command line must be UTF-8 text";

fn main() -> ExitCode {
    let standard_input = io::stdin();
    let mut input_lines = standard_input.lock().lines();
    let mut standard_output = io::stdout().lock();

    let Some(Ok(configuration)) = input_lines.next() else {
        let reply = render_error_reply(MISSING_CONFIGURATION);
        return fail_with(&mut standard_output, &reply);
    };
    let node_runtime = match NodeRuntime::start(&configuration) {
        Ok(node_runtime) => node_runtime,
        Err(problem) => {
            let reply = render_node_error_reply(&problem);
            return fail_with(&mut standard_output, &reply);
        }
    };
    let started_reply = render_success_reply(&Value::Null);
    if writeln!(standard_output, "{started_reply}").is_err() {
        return ExitCode::FAILURE;
    }

    for input_line in input_lines {
        let reply = match input_line {
            Ok(command) => node_runtime.handle_command(&command),
            Err(problem) if problem.kind() == io::ErrorKind::InvalidData => {
                render_error_reply(UNREADABLE_COMMAND)
            }
            Err(_) => return ExitCode::FAILURE,
        };
        if writeln!(standard_output, "{reply}").is_err() {
            return ExitCode::FAILURE;
        }
    }
    ExitCode::SUCCESS
}

fn fail_with(standard_output: &mut impl Write, reply: &str) -> ExitCode {
    let _written = writeln!(standard_output, "{reply}");
    ExitCode::FAILURE
}
