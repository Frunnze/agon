use orchestration_core::approval::ApprovalAction;
use orchestration_hub::claude_control::ToolPermissionRequest;
use orchestration_hub::requested_action::describe_requested_action;
use proptest::prelude::*;
use serde_json::{Value, json};

const TASK_FOLDER: &str =
    "/Users/someone/Library/Application Support/agon/worktrees/task-7";
const TASK_FOLDER_NAME: &str = "the task folder";
const LONGEST_SUMMARY_CHARACTERS: usize = 81;
const TASK_FOLDER_PATTERN: &str = concat!(
    "/Users/[a-z]{1,8}/Library/Application Support/",
    "[a-z.]{1,20}/task-[0-9]{1,4}",
);

fn request_for(tool_name: &str, input: Value) -> ToolPermissionRequest {
    ToolPermissionRequest {
        request_id: "request-1".to_string(),
        tool_name: tool_name.to_string(),
        input,
    }
}

fn run_command(tool: &str, summary: &str, command: &str) -> ApprovalAction {
    ApprovalAction::RunCommand {
        tool: tool.to_string(),
        summary: summary.to_string(),
        command: command.to_string(),
    }
}

fn read_summary_and_command(action: &ApprovalAction) -> (String, String) {
    match action {
        ApprovalAction::RunCommand {
            summary, command, ..
        } => (summary.clone(), command.clone()),
        _ => (String::new(), String::new()),
    }
}

fn describe(tool_name: &str, input: Value) -> ApprovalAction {
    describe_requested_action(&request_for(tool_name, input), TASK_FOLDER)
}

fn any_tool_with_field() -> impl Strategy<Value = (&'static str, &'static str)>
{
    prop_oneof![
        Just(("Bash", "command")),
        Just(("Edit", "file_path")),
        Just(("MultiEdit", "file_path")),
        Just(("Write", "file_path")),
        Just(("Read", "file_path")),
        Just(("NotebookEdit", "notebook_path")),
        Just(("Grep", "pattern")),
        Just(("Glob", "pattern")),
        Just(("WebFetch", "url")),
        Just(("WebSearch", "query")),
    ]
}

#[test]
fn a_bash_request_with_a_description_leads_with_it() {
    let input = json!({"command": "npm test", "description": "Run tests"});

    let action = describe("Bash", input);

    assert_eq!(action, run_command("Bash", "Run tests", "npm test"));
}

#[test]
fn a_bash_request_without_a_description_is_named_from_the_command() {
    let input = json!({"command": "npm install -D markdownlint-cli2"});

    let action = describe("Bash", input);

    let expected = run_command(
        "Bash",
        "Install markdownlint-cli2 with npm",
        "npm install -D markdownlint-cli2",
    );
    assert_eq!(action, expected);
}

#[test]
fn the_task_folder_is_named_in_the_command() {
    let command = format!("C=\"{TASK_FOLDER}/app\"; cd \"$C\" && npm test");
    let input = json!({"command": command});

    let action = describe("Bash", input);

    let shown = "C=\"the task folder/app\"; cd \"$C\" && npm test";
    assert_eq!(action, run_command("Bash", "Run the tests", shown));
}

#[test]
fn a_file_request_names_the_file_and_keeps_the_whole_path() {
    let path = format!("{TASK_FOLDER}/app/README.md");
    let input = json!({"file_path": path, "old_string": "x"});

    let action = describe("Edit", input);

    let shown = "the task folder/app/README.md";
    assert_eq!(action, run_command("Edit", "Edit README.md", shown));
}

#[test]
fn a_web_fetch_names_the_address() {
    let input = json!({"url": "https://example.com/a", "prompt": "read"});

    let action = describe("WebFetch", input);

    let expected = run_command(
        "WebFetch",
        "Fetch https://example.com/a",
        "https://example.com/a",
    );
    assert_eq!(action, expected);
}

#[test]
fn an_unknown_tool_shows_its_whole_input() {
    let input = json!({"server": "docs", "query": "approvals"});

    let action = describe("mcp__docs", input);

    let expected = r#"{"query":"approvals","server":"docs"}"#;
    assert_eq!(action, run_command("mcp__docs", "Use mcp__docs", expected));
}

#[test]
fn a_long_description_is_shortened_to_one_line() {
    let description = format!("{}\nsecond line", "word ".repeat(40));
    let input = json!({"command": "ls", "description": description});

    let action = describe("Bash", input);

    let (summary, _) = read_summary_and_command(&action);
    assert!(summary.chars().count() <= LONGEST_SUMMARY_CHARACTERS);
    assert!(!summary.contains('\n'));
    assert!(summary.starts_with("word word"));
}

proptest! {
    #[test]
    fn test_describe_requested_action_property_uses_the_description(
        (tool_name, field) in any_tool_with_field(),
        detail in "[a-z0-9/._ -]{1,80}",
        description in "[A-Z][a-z0-9 ]{0,60}[a-z]",
    ) {
        let input = json!({field: detail, "description": description});

        let action = describe(tool_name, input);

        let (summary, _) = read_summary_and_command(&action);
        prop_assert_eq!(summary, description);
    }

    #[test]
    fn test_describe_requested_action_property_label_hides_the_task_folder(
        task_folder in TASK_FOLDER_PATTERN,
        (tool_name, field) in any_tool_with_field(),
        before in "\\PC{0,40}",
        after in "\\PC{0,40}",
        has_description in any::<bool>(),
    ) {
        let detail = format!("{before}{task_folder}/{after}{task_folder}");
        let mut input = json!({field: detail});
        if has_description {
            let description = format!("{task_folder} {before} {task_folder}");
            input["description"] = json!(description);
        }
        let request = request_for(tool_name, input);

        let action = describe_requested_action(&request, &task_folder);

        let (summary, command) = read_summary_and_command(&action);
        prop_assert!(!summary.contains(&task_folder));
        prop_assert!(!command.contains(&task_folder));
    }

    #[test]
    fn test_describe_requested_action_property_keeps_the_whole_command(
        task_folder in TASK_FOLDER_PATTERN,
        (tool_name, field) in any_tool_with_field(),
        detail in "\\PC{1,400}(\n\\PC{1,80}){0,3}",
        has_folder in any::<bool>(),
    ) {
        prop_assume!(!detail.contains(TASK_FOLDER_NAME));
        let given_detail = if has_folder {
            format!("{task_folder}/{detail}")
        } else {
            detail.clone()
        };
        let input = json!({field: given_detail.clone(), "other": "ignored"});
        let request = request_for(tool_name, input);

        let action = describe_requested_action(&request, &task_folder);

        let (_, command) = read_summary_and_command(&action);
        let restored = command.replace(TASK_FOLDER_NAME, &task_folder);
        prop_assert_eq!(restored, given_detail);
    }

    #[test]
    fn test_describe_requested_action_property_label_is_one_short_line(
        tool_name in "[A-Za-z_]{1,20}",
        (known_tool, field) in any_tool_with_field(),
        detail in "\\PC{0,300}(\n\\PC{0,80}){0,3}",
        description in proptest::option::of("\\PC{0,300}(\n\\PC{0,80}){0,2}"),
        is_known in any::<bool>(),
    ) {
        let chosen_tool = if is_known {
            known_tool
        } else {
            tool_name.as_str()
        };
        let mut input = json!({field: detail});
        if let Some(description) = description {
            input["description"] = json!(description);
        }

        let action = describe(chosen_tool, input);

        let (summary, _) = read_summary_and_command(&action);
        prop_assert!(!summary.trim().is_empty());
        prop_assert!(!summary.contains('\n'));
        prop_assert!(summary.chars().count() <= LONGEST_SUMMARY_CHARACTERS);
        let ApprovalAction::RunCommand { tool, .. } = action else {
            return Err(TestCaseError::fail("not a run command"));
        };
        prop_assert_eq!(tool, chosen_tool);
    }
}
