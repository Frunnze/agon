use proptest::collection::btree_set;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::test_device::fail;
use crate::workflow_command_support::{
    BUILD_ID, OUTCOME_COUNT, START_ID, connection, create_fork,
    fork_connections, list_workflows, prepared_or_panic,
};

const COMMAND_CASES: u32 = 4;
const OUTCOME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const REPEATED_PAIR_TEXT: &str = "two connections from start to build";
const RULE_BREAKING_NAMES: [&str; 6] = [
    "Plan",
    "write code",
    "run_tests",
    "café",
    "",
    "build, at most 3 rounds",
];

fn fork_outcomes() -> impl Strategy<Value = Vec<String>> {
    btree_set(OUTCOME_PATTERN, OUTCOME_COUNT)
        .prop_map(|outcomes| outcomes.into_iter().collect())
}

fn with_plain_copy(connections: &[Value]) -> Vec<Value> {
    let mut copied = vec![connection(START_ID, BUILD_ID, None)];
    copied.extend(connections.iter().cloned());
    copied
}

fn find_listed(listings: &[Value], workflow_id: &Value) -> Option<Value> {
    listings
        .iter()
        .find(|listing| &listing["workflow"]["id"] == workflow_id)
        .cloned()
}

#[test]
fn test_create_workflow_property_refuses_a_repeated_step_pair() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(COMMAND_CASES));

    let outcome = runner.run(&fork_outcomes(), |outcomes| {
        let colliding = with_plain_copy(&fork_connections(&outcomes));

        let refusal = create_fork(&prepared, "build", &colliding);

        let message = refusal.err().unwrap_or_default();
        prop_assert!(message.contains(REPEATED_PAIR_TEXT), "{}", message);
        let listings = list_workflows(&prepared).map_err(fail)?;
        prop_assert!(listings.is_empty(), "{:?}", listings);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_workflow_property_refuses_a_rule_breaking_step_name() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(COMMAND_CASES));
    let cases = (fork_outcomes(), 0..RULE_BREAKING_NAMES.len());

    let outcome = runner.run(&cases, |(outcomes, name_position)| {
        let name = RULE_BREAKING_NAMES[name_position];

        let refusal =
            create_fork(&prepared, name, &fork_connections(&outcomes));

        let message = refusal.err().unwrap_or_default();
        prop_assert!(message.contains(&format!("{name:?}")), "{}", message);
        let listings = list_workflows(&prepared).map_err(fail)?;
        prop_assert!(listings.is_empty(), "{:?}", listings);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_save_workflow_property_refuses_a_document_collision() {
    let prepared = prepared_or_panic();
    let device = &prepared.device;
    let mut runner = TestRunner::new(Config::with_cases(COMMAND_CASES));

    let outcome = runner.run(&fork_outcomes(), |outcomes| {
        let honest_connections = fork_connections(&outcomes);
        let created = create_fork(&prepared, "build", &honest_connections)
            .map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();
        let signed = device
            .run(&json!({
                "command": "sign_workflow",
                "workflow_id": workflow_id,
            }))
            .map_err(fail)?;
        let mut colliding = signed["workflow"].clone();
        colliding["connections"] = json!(with_plain_copy(&honest_connections));

        let refusal = device.run(&json!({
            "command": "save_workflow",
            "workspace_id": prepared.workspace_id,
            "workflow": colliding,
        }));

        let message = refusal.err().unwrap_or_default();
        prop_assert!(message.contains(REPEATED_PAIR_TEXT), "{}", message);
        let listings = list_workflows(&prepared).map_err(fail)?;
        let listed = find_listed(&listings, &workflow_id)
            .ok_or_else(|| fail("the signed workflow is listed"))?;
        prop_assert_eq!(&listed["signature_state"], "signed");
        prop_assert_eq!(
            &listed["workflow"]["connections"],
            &signed["workflow"]["connections"]
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
