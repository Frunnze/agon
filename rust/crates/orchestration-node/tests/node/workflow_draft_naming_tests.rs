use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::create_workflow_command;
use crate::support::drafting_desk::{
    draft_command, drafted_workflow_with, open_desk_or_panic,
};
use crate::support::test_device::fail;

const DRAFTED_AGENT_TASK: &str = "Plan the whole feature";
const NAMING_CASES: u32 = 16;
const TAKEN_NAME: &str = "release";
const OTHER_WORKSPACE_ID: &str = "00000000-0000-0000-0000-00000000beef";

#[derive(Clone, Copy, Debug)]
enum DraftedName {
    Free,
    Taken,
    Broken,
}

#[derive(Clone, Copy, Debug)]
enum DraftedScope {
    Everywhere,
    ThisWorkspace,
    OtherWorkspace,
    ThisAndOther,
    Nowhere,
}

fn drafted_name_strategy() -> impl Strategy<Value = DraftedName> {
    prop_oneof![
        Just(DraftedName::Free),
        Just(DraftedName::Taken),
        Just(DraftedName::Broken),
    ]
}

fn drafted_scope_strategy() -> impl Strategy<Value = DraftedScope> {
    prop_oneof![
        Just(DraftedScope::Everywhere),
        Just(DraftedScope::ThisWorkspace),
        Just(DraftedScope::OtherWorkspace),
        Just(DraftedScope::ThisAndOther),
        Just(DraftedScope::Nowhere),
    ]
}

fn render_availability(
    availability: DraftedScope,
    workspace_id: &str,
) -> Value {
    match availability {
        DraftedScope::Everywhere => json!({ "kind": "all_workspaces" }),
        DraftedScope::ThisWorkspace => only_workspaces(&[workspace_id]),
        DraftedScope::OtherWorkspace => only_workspaces(&[OTHER_WORKSPACE_ID]),
        DraftedScope::ThisAndOther => {
            only_workspaces(&[workspace_id, OTHER_WORKSPACE_ID])
        }
        DraftedScope::Nowhere => only_workspaces(&[]),
    }
}

fn only_workspaces(workspace_ids: &[&str]) -> Value {
    json!({ "kind": "only_workspaces", "workspaces": workspace_ids })
}

fn is_allowed_availability(availability: DraftedScope) -> bool {
    matches!(
        availability,
        DraftedScope::Everywhere | DraftedScope::ThisWorkspace
    )
}

#[test]
fn test_workflow_draft_status_property_a_new_draft_gets_a_free_name_here() {
    let desk = open_desk_or_panic();
    let workspace_id = desk.prepared.workspace_id.clone();
    let taken = create_workflow_command(&workspace_id, DRAFTED_AGENT_TASK);
    let Ok(_) = desk.prepared.device.run(&taken) else {
        panic!("the workflow with the taken name is created");
    };
    let mut runner = TestRunner::new(Config::with_cases(NAMING_CASES));
    let cases = (
        drafted_name_strategy(),
        drafted_scope_strategy(),
        "[a-z]{8}",
    );

    let outcome = runner.run(&cases, |(name_kind, availability, letters)| {
        let name = match name_kind {
            DraftedName::Free => format!("plan-{letters}"),
            DraftedName::Taken => TAKEN_NAME.to_owned(),
            DraftedName::Broken => format!("Plan {letters}"),
        };
        let draft =
            desk.start(&draft_command(&desk.prepared)).map_err(fail)?;
        let rendered = render_availability(availability, &workspace_id);
        let drafted = drafted_workflow_with(
            &draft.workflow_id,
            &name,
            &rendered,
            DRAFTED_AGENT_TASK,
        );
        desk.finish(&draft, &drafted).map_err(fail)?;

        let status = desk.status_reply(&draft);

        let is_name_free = matches!(name_kind, DraftedName::Free);
        let is_accepted =
            is_name_free && is_allowed_availability(availability);
        prop_assert_eq!(status.get("ok").is_some(), is_accepted, "{}", status);
        let workflows = desk.list_workflows().map_err(fail)?;
        let is_saved = workflows.to_string().contains(&draft.workflow_id);
        prop_assert_eq!(is_saved, is_accepted);
        let run_count = desk.count_task_runs(&draft.task_id).map_err(fail)?;
        prop_assert_eq!(run_count, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
