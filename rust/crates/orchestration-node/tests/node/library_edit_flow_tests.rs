use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_rule_command, create_skill_command,
    prepare_workspace,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::{fail, read_text};

const EDIT_CASES: u32 = 4;
const SKILL_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,20}";
const RULE_TITLE_PATTERN: &str = "[A-Z][a-z ]{0,30}";
const FIRST_SECRET: &str = "the first instructions nobody else reads";
const UNKNOWN_ID: &str = "00000000-0000-0000-0000-0000000000aa";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn everywhere_scope() -> Value {
    json!({
        "workspaces": { "kind": "all_workspaces" },
        "projects": { "kind": "all_projects" },
    })
}

fn list_in_workspace(
    prepared: &PreparedWorkspace,
    command_name: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": command_name,
        "workspace_id": prepared.workspace_id,
    }))
}

fn read_agents_markdown(
    prepared: &PreparedWorkspace,
) -> Result<String, String> {
    let markdown = prepared.device.run(&json!({
        "command": "show_agents_markdown",
        "workspace_id": prepared.workspace_id,
        "project_id": prepared.project_id,
    }))?;
    read_text(&markdown, "/markdown")
}

#[test]
fn test_update_skill_property_lists_the_new_fields_and_seals_them() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(EDIT_CASES));
    let inputs = (SKILL_NAME_PATTERN, secret_text_strategy(), any::<bool>());

    let outcome = runner.run(&inputs, |(name, instructions, is_automatic)| {
        let create =
            create_skill_command(&prepared.workspace_id, FIRST_SECRET);
        let created = device.run(&create).map_err(fail)?;
        let usage = if is_automatic {
            "automatic"
        } else {
            "when_chosen"
        };
        let updated = device
            .run(&json!({
                "command": "update_skill",
                "workspace_id": prepared.workspace_id,
                "skill_id": created["id"],
                "name": name,
                "summary": "Changed summary",
                "instructions": instructions,
                "scope": everywhere_scope(),
                "usage": usage,
            }))
            .map_err(fail)?;
        let skills =
            list_in_workspace(&prepared, "list_skills").map_err(fail)?;
        let stored_state =
            prepared.server.read_stored_state().map_err(fail)?;

        prop_assert_eq!(&updated["id"], &created["id"]);
        prop_assert_eq!(&updated["name"], &json!(name));
        prop_assert_eq!(&updated["instructions"], &json!(instructions));
        prop_assert_eq!(&updated["usage"], &json!(usage));
        prop_assert_eq!(&updated["source"], &json!("created"));
        let listed = skills
            .as_array()
            .into_iter()
            .flatten()
            .find(|skill| skill["id"] == created["id"]);
        prop_assert_eq!(listed, Some(&updated));
        prop_assert!(!stored_state.contains(instructions.as_str()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_update_rule_property_agents_markdown_shows_the_new_details() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(EDIT_CASES));
    let inputs = (RULE_TITLE_PATTERN, secret_text_strategy());

    let outcome = runner.run(&inputs, |(title, details)| {
        let create = create_rule_command(&prepared.workspace_id, FIRST_SECRET);
        let created = device.run(&create).map_err(fail)?;
        let updated = device
            .run(&json!({
                "command": "update_rule",
                "workspace_id": prepared.workspace_id,
                "rule_id": created["id"],
                "title": title,
                "details": details,
                "scope": everywhere_scope(),
            }))
            .map_err(fail)?;
        let markdown = read_agents_markdown(&prepared).map_err(fail)?;
        let stored_state =
            prepared.server.read_stored_state().map_err(fail)?;

        prop_assert_eq!(&updated["id"], &created["id"]);
        prop_assert_eq!(&updated["title"], &json!(title));
        prop_assert_eq!(&updated["details"], &json!(details));
        prop_assert_eq!(&updated["enabled"], &created["enabled"]);
        prop_assert_eq!(&updated["added_at"], &created["added_at"]);
        prop_assert!(markdown.contains(details.as_str()));
        prop_assert!(!stored_state.contains(details.as_str()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_delete_skill_property_the_skill_is_no_longer_listed() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(EDIT_CASES));

    let outcome = runner.run(&secret_text_strategy(), |instructions| {
        let create =
            create_skill_command(&prepared.workspace_id, &instructions);
        let created = device.run(&create).map_err(fail)?;
        let deleted = device.run(&json!({
            "command": "delete_skill",
            "skill_id": created["id"],
        }));
        let skills =
            list_in_workspace(&prepared, "list_skills").map_err(fail)?;

        prop_assert_eq!(deleted, Ok(Value::Null));
        let is_listed = skills
            .as_array()
            .into_iter()
            .flatten()
            .any(|skill| skill["id"] == created["id"]);
        prop_assert!(!is_listed);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_delete_rule_property_the_rule_leaves_agents_markdown() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(EDIT_CASES));

    let outcome = runner.run(&secret_text_strategy(), |details| {
        let create = create_rule_command(&prepared.workspace_id, &details);
        let created = device.run(&create).map_err(fail)?;
        let deleted = device.run(&json!({
            "command": "delete_rule",
            "rule_id": created["id"],
        }));
        let rules =
            list_in_workspace(&prepared, "list_rules").map_err(fail)?;
        let markdown = read_agents_markdown(&prepared).map_err(fail)?;

        prop_assert_eq!(deleted, Ok(Value::Null));
        let is_listed = rules
            .as_array()
            .into_iter()
            .flatten()
            .any(|rule| rule["id"] == created["id"]);
        prop_assert!(!is_listed);
        prop_assert!(!markdown.contains(details.as_str()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn bad_edits_and_unknown_items_are_refused() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let Ok(rule) =
        device.run(&create_rule_command(&prepared.workspace_id, FIRST_SECRET))
    else {
        panic!("the rule is created");
    };

    let blank_title = device.run(&json!({
        "command": "update_rule",
        "workspace_id": prepared.workspace_id,
        "rule_id": rule["id"],
        "title": "  ",
        "details": "",
        "scope": everywhere_scope(),
    }));
    let bad_name = device.run(&json!({
        "command": "update_skill",
        "workspace_id": prepared.workspace_id,
        "skill_id": UNKNOWN_ID,
        "name": "Release Notes",
        "summary": "Write release notes",
        "instructions": FIRST_SECRET,
        "scope": everywhere_scope(),
        "usage": "automatic",
    }));
    let unknown_skill = device.run(&json!({
        "command": "delete_skill",
        "skill_id": UNKNOWN_ID,
    }));
    let unknown_rule = device.run(&json!({
        "command": "delete_rule",
        "rule_id": UNKNOWN_ID,
    }));

    assert!(blank_title.is_err(), "{blank_title:?}");
    assert!(bad_name.is_err(), "{bad_name:?}");
    assert!(unknown_skill.is_err(), "{unknown_skill:?}");
    assert!(unknown_rule.is_err(), "{unknown_rule:?}");
}
