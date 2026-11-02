use serde_json::Value;

use crate::text_shortening::shorten_to_characters;
use crate::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;

const MAXIMUM_DETAIL_CHARACTERS: usize = 100;
const UNNAMED_TOOL_DESCRIPTION: &str = "Used a tool";
const PATH_SEPARATOR: char = '/';

#[derive(Clone, Copy)]
enum DetailKind {
    FilePath,
    Text,
}

struct ToolDescription {
    tool_name: &'static str,
    input_field: &'static str,
    verb: &'static str,
    detail_kind: DetailKind,
}

const TOOL_DESCRIPTIONS: [ToolDescription; 10] = [
    describe("Bash", "command", "Ran", DetailKind::Text),
    describe("Edit", "file_path", "Edited", DetailKind::FilePath),
    describe("MultiEdit", "file_path", "Edited", DetailKind::FilePath),
    describe(
        "NotebookEdit",
        "notebook_path",
        "Edited",
        DetailKind::FilePath,
    ),
    describe("Write", "file_path", "Wrote", DetailKind::FilePath),
    describe("Read", "file_path", "Read", DetailKind::FilePath),
    describe("Grep", "pattern", "Searched for", DetailKind::Text),
    describe(
        "Glob",
        "pattern",
        "Looked for files matching",
        DetailKind::Text,
    ),
    describe("WebFetch", "url", "Fetched", DetailKind::Text),
    describe(
        "WebSearch",
        "query",
        "Searched the web for",
        DetailKind::Text,
    ),
];

const fn describe(
    tool_name: &'static str,
    input_field: &'static str,
    verb: &'static str,
    detail_kind: DetailKind,
) -> ToolDescription {
    ToolDescription {
        tool_name,
        input_field,
        verb,
        detail_kind,
    }
}

pub(crate) fn describe_tool_use(tool_name: &str, input: &Value) -> String {
    let known_tool = TOOL_DESCRIPTIONS
        .iter()
        .find(|description| description.tool_name == tool_name);
    let Some(description) = known_tool else {
        return name_tool(tool_name);
    };

    let given_detail = input
        .get(description.input_field)
        .and_then(Value::as_str)
        .unwrap_or_default()
        .trim();
    let readable_detail = match description.detail_kind {
        DetailKind::FilePath => relative_to_workspace(given_detail),
        DetailKind::Text => given_detail,
    };
    let detail = shorten_detail(readable_detail);
    if detail.is_empty() {
        return name_tool(tool_name);
    }
    format!("{} {detail}", description.verb)
}

fn name_tool(tool_name: &str) -> String {
    let name = shorten_detail(tool_name);
    if name.is_empty() {
        return UNNAMED_TOOL_DESCRIPTION.to_string();
    }
    format!("Used {name}")
}

fn shorten_detail(detail: &str) -> String {
    let first_line = detail.trim().lines().next().unwrap_or_default().trim();
    shorten_to_characters(first_line, MAXIMUM_DETAIL_CHARACTERS)
}

fn relative_to_workspace(path: &str) -> &str {
    let relative_path = path
        .strip_prefix(CONTAINER_WORKSPACE_DIRECTORY)
        .and_then(|rest| rest.strip_prefix(PATH_SEPARATOR))
        .unwrap_or(path);
    if relative_path.is_empty() {
        return path;
    }
    relative_path
}
