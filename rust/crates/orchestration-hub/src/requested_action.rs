use orchestration_core::approval::ApprovalAction;
use serde_json::Value;

use crate::claude_control::ToolPermissionRequest;
use crate::known_tools::CLAUDE_TOOLS;
use crate::text_shortening::{shorten_keeping_the_end, shorten_to_characters};
use crate::tool_description::DetailKind;

const SHELL_TOOL_NAME: &str = "Bash";
const SHELL_COMMAND_FIELD: &str = "command";
const MAXIMUM_SHOWN_CHARACTERS: usize = 200;

#[must_use]
pub fn describe_requested_action(
    request: &ToolPermissionRequest,
) -> ApprovalAction {
    ApprovalAction::RunCommand {
        tool: request.tool_name.clone(),
        command: describe_requested_command(request),
    }
}

fn describe_requested_command(request: &ToolPermissionRequest) -> String {
    let is_shell = request.tool_name == SHELL_TOOL_NAME;
    if is_shell
        && let Some(shell_command) =
            read_text_field(&request.input, SHELL_COMMAND_FIELD)
    {
        return shell_command.to_string();
    }

    match find_telling_detail(request) {
        Some((detail, DetailKind::FilePath)) => {
            shorten_keeping_the_end(detail, MAXIMUM_SHOWN_CHARACTERS)
        }
        Some((detail, DetailKind::Text)) => {
            shorten_to_characters(detail, MAXIMUM_SHOWN_CHARACTERS)
        }
        None => {
            let input_text = request.input.to_string();
            shorten_to_characters(&input_text, MAXIMUM_SHOWN_CHARACTERS)
        }
    }
}

fn find_telling_detail(
    request: &ToolPermissionRequest,
) -> Option<(&str, DetailKind)> {
    let known_tool = CLAUDE_TOOLS
        .iter()
        .find(|known_tool| known_tool.action.tool_name == request.tool_name)?;
    let detail = read_text_field(&request.input, known_tool.input_field)?;
    Some((detail, known_tool.action.detail_kind))
}

fn read_text_field<'input>(
    input: &'input Value,
    field: &str,
) -> Option<&'input str> {
    input.get(field).and_then(Value::as_str)
}
