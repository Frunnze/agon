use serde_json::Value;

use crate::text_shortening::{shorten_keeping_the_end, shorten_to_characters};

const MAXIMUM_DETAIL_CHARACTERS: usize = 100;
const UNNAMED_TOOL_DESCRIPTION: &str = "Used a tool";
const PATH_SEPARATOR: char = '/';
const LINE_BREAKS: [char; 7] = [
    '\n', '\r', '\u{0B}', '\u{0C}', '\u{85}', '\u{2028}', '\u{2029}',
];

#[derive(Clone, Copy)]
pub(crate) enum DetailKind {
    FilePath,
    Text,
}

#[derive(Clone, Copy)]
pub(crate) struct ToolAction {
    pub(crate) tool_name: &'static str,
    pub(crate) verb: &'static str,
    pub(crate) detail_kind: DetailKind,
}

pub(crate) struct KnownTool {
    pub(crate) action: ToolAction,
    pub(crate) input_field: &'static str,
}

pub(crate) const fn define_known_tool(
    tool_name: &'static str,
    input_field: &'static str,
    verb: &'static str,
    detail_kind: DetailKind,
) -> KnownTool {
    KnownTool {
        action: ToolAction {
            tool_name,
            verb,
            detail_kind,
        },
        input_field,
    }
}

pub(crate) fn describe_tool_use(
    known_tools: &[KnownTool],
    tool_name: &str,
    input: &Value,
    task_folder: &str,
) -> String {
    let known_tool = known_tools
        .iter()
        .find(|known_tool| known_tool.action.tool_name == tool_name);
    let Some(known_tool) = known_tool else {
        return name_tool(tool_name);
    };

    let given_detail = input
        .get(known_tool.input_field)
        .and_then(Value::as_str)
        .unwrap_or_default();
    describe_tool_action(known_tool.action, given_detail, task_folder)
}

pub(crate) fn describe_tool_action(
    action: ToolAction,
    given_detail: &str,
    task_folder: &str,
) -> String {
    let readable_detail = match action.detail_kind {
        DetailKind::FilePath => describe_file_path(given_detail, task_folder),
        DetailKind::Text => {
            let detail = read_first_line(given_detail);
            shorten_to_characters(detail, MAXIMUM_DETAIL_CHARACTERS)
        }
    };

    if readable_detail.is_empty() {
        return name_tool(action.tool_name);
    }
    format!("{} {readable_detail}", action.verb)
}

pub(crate) fn describe_file_path(
    given_path: &str,
    task_folder: &str,
) -> String {
    let path = read_first_line(given_path);
    let relative_path = relative_to_task_folder(path, task_folder);
    shorten_keeping_the_end(relative_path, MAXIMUM_DETAIL_CHARACTERS)
}

pub(crate) fn name_tool(tool_name: &str) -> String {
    let first_line = read_first_line(tool_name);
    let name = shorten_to_characters(first_line, MAXIMUM_DETAIL_CHARACTERS);
    if name.is_empty() {
        return UNNAMED_TOOL_DESCRIPTION.to_string();
    }
    format!("Used {name}")
}

pub(crate) fn read_first_line(text: &str) -> &str {
    let first_line = text.trim().split(LINE_BREAKS).next().unwrap_or_default();
    first_line.trim()
}

fn relative_to_task_folder<'path>(
    path: &'path str,
    task_folder: &str,
) -> &'path str {
    let relative_path = path
        .strip_prefix(task_folder)
        .and_then(|rest| rest.strip_prefix(PATH_SEPARATOR))
        .map(|rest| rest.trim_start_matches(PATH_SEPARATOR))
        .unwrap_or_default();
    if relative_path.is_empty() {
        return path;
    }
    relative_path
}
