use orchestration_core::approval::ApprovalAction;
use orchestration_hub::claude_control::ToolPermissionRequest;
use orchestration_hub::requested_action::describe_requested_action;
use proptest::prelude::*;
use serde_json::{Value, json};

const MAXIMUM_SHOWN_CHARACTERS: usize = 200;
const SHORTENED_MARKER: char = '…';

fn request_for(tool_name: &str, input: Value) -> ToolPermissionRequest {
    ToolPermissionRequest {
        request_id: "request-1".to_string(),
        tool_name: tool_name.to_string(),
        input,
    }
}

fn run_command(tool: &str, command: &str) -> ApprovalAction {
    ApprovalAction::RunCommand {
        tool: tool.to_string(),
        command: command.to_string(),
    }
}

fn shown_command(action: &ApprovalAction) -> String {
    match action {
        ApprovalAction::RunCommand { command, .. } => command.clone(),
        _ => String::new(),
    }
}

fn any_tool_with_field() -> impl Strategy<Value = (&'static str, &'static str)>
{
    prop_oneof![
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
fn a_bash_request_shows_the_command_text() {
    let input = json!({"command": "npm test", "description": "Run tests"});

    let action = describe_requested_action(&request_for("Bash", input));

    assert_eq!(action, run_command("Bash", "npm test"));
}

#[test]
fn a_file_request_shows_the_end_of_a_long_path() {
    let folder = "a".repeat(MAXIMUM_SHOWN_CHARACTERS);
    let path = format!("/{folder}/src/main.rs");
    let input = json!({"file_path": path, "old_string": "x"});

    let action = describe_requested_action(&request_for("Edit", input));

    let command = shown_command(&action);
    assert!(command.starts_with(SHORTENED_MARKER));
    assert!(command.ends_with("/src/main.rs"));
    assert_eq!(command.chars().count(), MAXIMUM_SHOWN_CHARACTERS + 1);
}

#[test]
fn an_unknown_tool_shows_its_input() {
    let input = json!({"server": "docs", "query": "approvals"});

    let action = describe_requested_action(&request_for("mcp__docs", input));

    let expected = r#"{"query":"approvals","server":"docs"}"#;
    assert_eq!(action, run_command("mcp__docs", expected));
}

proptest! {
    #[test]
    fn test_describe_requested_action_property_bash_keeps_the_whole_command(
        command in "\\PC{1,400}(\n\\PC{1,80}){0,3}",
    ) {
        let input = json!({"command": command, "description": "Run it"});

        let action = describe_requested_action(&request_for("Bash", input));

        prop_assert_eq!(action, run_command("Bash", &command));
    }

    #[test]
    fn test_describe_requested_action_property_shows_the_telling_field(
        (tool_name, field) in any_tool_with_field(),
        detail in "[a-zA-Z0-9/._*-]{1,200}",
    ) {
        let input = json!({field: detail, "other": "ignored"});

        let action = describe_requested_action(&request_for(tool_name, input));

        prop_assert_eq!(action, run_command(tool_name, &detail));
    }

    #[test]
    fn test_describe_requested_action_property_other_tools_stay_short(
        tool_name in "[A-Za-z_]{1,20}",
        detail in "\\PC{0,600}",
    ) {
        prop_assume!(tool_name != "Bash");
        let input = json!({
            "file_path": detail,
            "pattern": detail,
            "url": detail,
            "query": detail,
            "notebook_path": detail,
            "value": detail,
        });

        let request = request_for(&tool_name, input);

        let action = describe_requested_action(&request);

        let command = shown_command(&action);
        let shown_characters = command.chars().count();
        prop_assert!(shown_characters <= MAXIMUM_SHOWN_CHARACTERS + 1);
        let ApprovalAction::RunCommand { tool, .. } = action else {
            return Err(TestCaseError::fail("not a run command"));
        };
        prop_assert_eq!(tool, tool_name);
    }
}
