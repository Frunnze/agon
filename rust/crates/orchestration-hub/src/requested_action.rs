use std::path::Path;

use orchestration_core::approval::ApprovalAction;
use serde_json::Value;

use crate::claude_control::ToolPermissionRequest;
use crate::command_label::label_shell_command;
use crate::known_tools::CLAUDE_TOOLS;
use crate::text_shortening::shorten_to_characters;
use crate::tool_description::{DetailKind, read_first_line};

const SHELL_TOOL_NAME: &str = "Bash";
const DESCRIPTION_FIELD: &str = "description";
const TASK_FOLDER_NAME: &str = "the task folder";
const MAXIMUM_SUMMARY_CHARACTERS: usize = 80;
const NAME_PUNCTUATION: [char; 8] = ['-', '_', '.', '~', '+', '@', '%', ','];

const IMPERATIVE_VERBS: [(&str, &str); 9] = [
    ("Edit", "Edit"),
    ("MultiEdit", "Edit"),
    ("NotebookEdit", "Edit"),
    ("Write", "Write"),
    ("Read", "Read"),
    ("Grep", "Search for"),
    ("Glob", "Find files matching"),
    ("WebFetch", "Fetch"),
    ("WebSearch", "Search the web for"),
];

#[must_use]
pub fn describe_requested_action(
    request: &ToolPermissionRequest,
    task_folder: &str,
) -> ApprovalAction {
    let telling_detail = find_telling_detail(request);
    let requested_input = match telling_detail {
        Some((detail, _)) => detail.to_owned(),
        None => request.input.to_string(),
    };
    let command = name_task_folder(&requested_input, task_folder);

    let agent_description = read_agent_description(request, task_folder);
    let summary = agent_description.unwrap_or_else(|| {
        make_up_summary(&request.tool_name, telling_detail, &command)
    });

    ApprovalAction::RunCommand {
        tool: request.tool_name.clone(),
        summary,
        command,
    }
}

fn read_agent_description(
    request: &ToolPermissionRequest,
    task_folder: &str,
) -> Option<String> {
    let description = read_text_field(&request.input, DESCRIPTION_FIELD)?;
    let readable_description = name_task_folder(description, task_folder);
    let summary = fit_on_one_line(&readable_description);
    if summary.is_empty() {
        return None;
    }
    Some(summary)
}

fn make_up_summary(
    tool_name: &str,
    telling_detail: Option<(&str, DetailKind)>,
    command: &str,
) -> String {
    let tool_use_label = match telling_detail {
        Some((_, detail_kind)) => {
            label_tool_use(tool_name, command, detail_kind)
        }
        None => format!("Use {tool_name}"),
    };
    fit_on_one_line(&tool_use_label)
}

fn label_tool_use(
    tool_name: &str,
    command: &str,
    detail_kind: DetailKind,
) -> String {
    if tool_name == SHELL_TOOL_NAME {
        return label_shell_command(command);
    }
    let Some((_, verb)) = IMPERATIVE_VERBS
        .iter()
        .find(|(known_tool_name, _)| *known_tool_name == tool_name)
    else {
        return format!("Use {tool_name}");
    };

    let detail = match detail_kind {
        DetailKind::FilePath => Path::new(command)
            .file_name()
            .and_then(|file_name| file_name.to_str())
            .unwrap_or(command),
        DetailKind::Text => command,
    };
    format!("{verb} {detail}")
}

fn name_task_folder(text: &str, task_folder: &str) -> String {
    let mut named_text = String::new();
    let mut copied_until = 0;
    for (start, _) in text.match_indices(task_folder) {
        let end = start + task_folder.len();
        let next_character = text[end..].chars().next();
        if next_character.is_some_and(continues_a_name) {
            continue;
        }
        named_text.push_str(&text[copied_until..start]);
        named_text.push_str(TASK_FOLDER_NAME);
        copied_until = end;
    }
    named_text.push_str(&text[copied_until..]);
    named_text
}

fn continues_a_name(character: char) -> bool {
    character.is_alphanumeric() || NAME_PUNCTUATION.contains(&character)
}

fn fit_on_one_line(text: &str) -> String {
    shorten_to_characters(read_first_line(text), MAXIMUM_SUMMARY_CHARACTERS)
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
