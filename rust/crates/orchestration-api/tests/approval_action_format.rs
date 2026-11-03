use orchestration_core::approval::ApprovalAction;
use proptest::prelude::*;
use serde_json::{Value, json};

#[test]
fn a_run_command_approval_has_the_agreed_wire_shape() {
    let action = ApprovalAction::RunCommand {
        tool: "Bash".to_string(),
        command: "npm test".to_string(),
    };

    let encoded_action = serde_json::to_value(&action).ok();

    let expected_action =
        json!({"kind": "run_command", "tool": "Bash", "command": "npm test"});
    assert_eq!(encoded_action, Some(expected_action));
}

proptest! {
    #[test]
    fn test_approval_action_property_run_command_keeps_its_wire_shape(
        tool in "\\PC{0,20}",
        command in "\\PC{0,200}",
    ) {
        let action = ApprovalAction::RunCommand {
            tool: tool.clone(),
            command: command.clone(),
        };

        let encoded_action = serde_json::to_value(&action).ok();
        let decoded_action = encoded_action
            .clone()
            .and_then(|encoded| serde_json::from_value(encoded).ok());

        let expected_action: Value =
            json!({"kind": "run_command", "tool": tool, "command": command});
        prop_assert_eq!(encoded_action, Some(expected_action));
        prop_assert_eq!(decoded_action, Some(action));
    }
}
