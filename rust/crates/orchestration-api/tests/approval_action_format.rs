use orchestration_core::approval::{
    ApprovalAction, UNLABELLED_COMMAND_SUMMARY,
};
use orchestration_core::identifiers::SkillId;
use orchestration_core::library::{Skill, SkillImprovement};
use proptest::prelude::*;
use serde_json::{Value, json};
use uuid::Uuid;

#[test]
fn a_run_command_approval_has_the_agreed_wire_shape() {
    let action = ApprovalAction::RunCommand {
        tool: "Bash".to_string(),
        summary: "Run the tests".to_string(),
        command: "npm test".to_string(),
    };

    let encoded_action = serde_json::to_value(&action).ok();

    let expected_action = json!({
        "kind": "run_command",
        "tool": "Bash",
        "summary": "Run the tests",
        "command": "npm test",
    });
    assert_eq!(encoded_action, Some(expected_action));
}

proptest! {
    #[test]
    fn test_approval_action_property_run_command_keeps_its_wire_shape(
        tool in "\\PC{0,20}",
        summary in "\\PC{0,80}",
        command in "\\PC{0,200}",
    ) {
        let action = ApprovalAction::RunCommand {
            tool: tool.clone(),
            summary: summary.clone(),
            command: command.clone(),
        };

        let encoded_action = serde_json::to_value(&action).ok();
        let decoded_action = encoded_action
            .clone()
            .and_then(|encoded| serde_json::from_value(encoded).ok());

        let expected_action: Value = json!({
            "kind": "run_command",
            "tool": tool,
            "summary": summary,
            "command": command,
        });
        prop_assert_eq!(encoded_action, Some(expected_action));
        prop_assert_eq!(decoded_action, Some(action));
    }

    #[test]
    fn test_approval_action_property_stored_command_reads_without_summary(
        tool in "\\PC{0,20}",
        command in "\\PC{0,200}",
    ) {
        let stored_action =
            json!({"kind": "run_command", "tool": tool, "command": command});

        let decoded_action: Option<ApprovalAction> =
            serde_json::from_value(stored_action).ok();

        let expected_action = ApprovalAction::RunCommand {
            tool,
            summary: UNLABELLED_COMMAND_SUMMARY.to_string(),
            command,
        };
        prop_assert_eq!(decoded_action, Some(expected_action));
    }
}

#[test]
fn an_improve_skill_approval_has_the_agreed_wire_shape() {
    let skill_id = SkillId(Uuid::from_u128(7));
    let action = ApprovalAction::ImproveSkill {
        skill_id,
        summary: "1 line added, 0 lines removed".to_string(),
        proposed_instructions: "sealed-v1:aW1wcm92ZWQ".to_string(),
    };

    let encoded_action = serde_json::to_value(&action).ok();

    let expected_action = json!({
        "kind": "improve_skill",
        "skill_id": skill_id.0.to_string(),
        "summary": "1 line added, 0 lines removed",
        "proposed_instructions": "sealed-v1:aW1wcm92ZWQ",
    });
    assert_eq!(encoded_action, Some(expected_action));
}

#[test]
fn a_skill_saved_before_improvements_reads_as_never_with_no_history() {
    let stored_skill = json!({
        "id": Uuid::from_u128(8).to_string(),
        "name": "release",
        "summary": "Ship it",
        "instructions": "sealed-v1:c2hpcA",
        "scope": {
            "workspaces": {"kind": "all_workspaces"},
            "projects": {"kind": "all_projects"},
        },
        "usage": "automatic",
        "source": "created",
    });

    let skill: Option<Skill> = serde_json::from_value(stored_skill).ok();

    let read_setting = skill.as_ref().map(|skill| skill.improvement);
    assert_eq!(read_setting, Some(SkillImprovement::Never));
    assert_eq!(skill.map(|skill| skill.history), Some(Vec::new()));
}
