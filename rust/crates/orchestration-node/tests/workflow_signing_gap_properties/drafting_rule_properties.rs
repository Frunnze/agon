use orchestration_core::naming::MAXIMUM_NAME_LENGTH;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::command_builders::create_workflow_command;
use crate::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::test_device::{fail, read_text};

const DRAFTING_CASES: u32 = 2;
const PLANNING_AGENT_ID: &str = "00000000-0000-0000-0000-000000000011";
const REQUEST_PATTERN: &str = "[A-Z][a-z ]{4,24}";
const PAIR_RULE_TEXT: &str =
    "At most one connection goes from one agent to another.";

fn step_name_rule_text() -> String {
    format!(
        "Each agent's name is lowercase letters, digits and dashes, at most \
         {MAXIMUM_NAME_LENGTH} characters, and no two agents share one."
    )
}

fn create_planning_workflow(desk: &DraftingDesk) -> Result<String, String> {
    let created = desk.prepared.device.run(&create_workflow_command(
        &desk.prepared.workspace_id,
        "Plan the feature",
    ))?;
    read_text(&created, "/workflow/id")
}

fn queue_and_read_details(
    desk: &DraftingDesk,
    command: &Value,
) -> Result<String, String> {
    desk.prepared.device.run(command)?;
    let assignment = desk.claim_drafting_run()?;
    Ok(assignment.task.details)
}

#[test]
fn test_render_workflow_format_instructions_property_draft_names_the_rule() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFTING_CASES));

    let outcome = runner.run(&REQUEST_PATTERN, |description| {
        let command = json!({
            "command": "draft_workflow",
            "workspace_id": desk.prepared.workspace_id,
            "description": description,
        });

        let details = queue_and_read_details(&desk, &command).map_err(fail)?;

        prop_assert!(details.contains(&step_name_rule_text()), "{}", details);
        prop_assert!(details.contains(PAIR_RULE_TEXT), "{}", details);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_render_workflow_format_instructions_property_change_names_the_rule() {
    let desk = open_desk_or_panic();
    let workflow_id = create_planning_workflow(&desk)
        .unwrap_or_else(|message| panic!("the workflow exists: {message}"));
    let mut runner = TestRunner::new(Config::with_cases(DRAFTING_CASES));

    let outcome = runner.run(&REQUEST_PATTERN, |change_request| {
        let command = json!({
            "command": "change_workflow",
            "workspace_id": desk.prepared.workspace_id,
            "workflow_id": workflow_id,
            "request": change_request,
            "agent": "claude_code",
        });

        let details = queue_and_read_details(&desk, &command).map_err(fail)?;

        prop_assert!(details.contains(&step_name_rule_text()), "{}", details);
        prop_assert!(details.contains(PAIR_RULE_TEXT), "{}", details);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_render_workflow_format_instructions_property_fill_names_the_rule() {
    let desk = open_desk_or_panic();
    let workflow_id = create_planning_workflow(&desk)
        .unwrap_or_else(|message| panic!("the workflow exists: {message}"));
    let mut runner = TestRunner::new(Config::with_cases(DRAFTING_CASES));

    let outcome = runner.run(&Just(PLANNING_AGENT_ID), |agent_id| {
        let command = json!({
            "command": "fill_agent_settings",
            "workspace_id": desk.prepared.workspace_id,
            "workflow_id": workflow_id,
            "agent_id": agent_id,
        });

        let details = queue_and_read_details(&desk, &command).map_err(fail)?;

        let name_rule_count = details.matches(&step_name_rule_text()).count();
        prop_assert_eq!(name_rule_count, 1, "{}", details);
        prop_assert_eq!(details.matches(PAIR_RULE_TEXT).count(), 1);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
