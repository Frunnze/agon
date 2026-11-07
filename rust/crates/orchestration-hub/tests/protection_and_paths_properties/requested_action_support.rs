use orchestration_core::approval::ApprovalAction;
use orchestration_hub::claude_control::ToolPermissionRequest;
use orchestration_hub::requested_action::describe_requested_action;
use proptest::prelude::*;
use serde_json::Value;

pub type ToolShape = (&'static str, &'static str, &'static str);

pub const TASK_FOLDER_NAME: &str = "the task folder";
pub const LONGEST_SUMMARY_CHARACTERS: usize = 81;
pub const SHORTENED_MARKER: char = '…';

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");

pub const FILE_TOOLS: [ToolShape; 5] = [
    ("Edit", "file_path", "Edit"),
    ("MultiEdit", "file_path", "Edit"),
    ("NotebookEdit", "notebook_path", "Edit"),
    ("Write", "file_path", "Write"),
    ("Read", "file_path", "Read"),
];

pub const TEXT_TOOLS: [ToolShape; 4] = [
    ("Grep", "pattern", "Search for"),
    ("Glob", "pattern", "Find files matching"),
    ("WebFetch", "url", "Fetch"),
    ("WebSearch", "query", "Search the web for"),
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DescribedAction {
    pub tool: String,
    pub summary: String,
    pub command: String,
}

pub fn any_task_folder() -> impl Strategy<Value = String> {
    "[a-z]{1,8}/task-[0-9]{1,4}"
        .prop_map(|inside| format!("{TARGET_TEMPORARY_FOLDER}/{inside}"))
}

pub fn any_file_tool() -> impl Strategy<Value = ToolShape> {
    prop::sample::select(FILE_TOOLS.to_vec())
}

pub fn any_text_tool() -> impl Strategy<Value = ToolShape> {
    prop::sample::select(TEXT_TOOLS.to_vec())
}

pub fn describe(
    tool_name: &str,
    input: Value,
    task_folder: &str,
) -> Result<DescribedAction, TestCaseError> {
    let request = ToolPermissionRequest {
        request_id: "request-1".to_owned(),
        tool_name: tool_name.to_owned(),
        input,
    };
    let action = describe_requested_action(&request, task_folder);
    let ApprovalAction::RunCommand {
        tool,
        summary,
        command,
    } = action
    else {
        return Err(TestCaseError::fail(format!("{action:?}")));
    };
    Ok(DescribedAction {
        tool,
        summary,
        command,
    })
}

pub fn is_one_short_line(summary: &str) -> bool {
    let has_line_break = summary.chars().any(|character| {
        matches!(
            character,
            '\n' | '\r'
                | '\u{0B}'
                | '\u{0C}'
                | '\u{85}'
                | '\u{2028}'
                | '\u{2029}'
        )
    });
    let is_short = summary.chars().count() <= LONGEST_SUMMARY_CHARACTERS;
    !has_line_break && is_short && summary.trim() == summary
}
