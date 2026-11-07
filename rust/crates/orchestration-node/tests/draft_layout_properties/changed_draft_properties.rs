use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::command_builders::create_workflow_command;
use crate::drafted_graphs::{
    DraftedGraph, acyclic_graph_strategy, any_graph_strategy,
    cyclic_graph_strategy, decode_workflow, drafted_workflow_value,
    expected_draft_problem,
};
use crate::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::test_device::{fail, read_text};

const CHANGED_DRAFT_CASES: u32 = 8;
const STORED_TASK: &str = "Plan the whole feature";
const STORED_NAME: &str = "release";

#[derive(Debug)]
struct ChangeReply {
    status: Value,
    listed_before: Value,
    listed_after: Value,
}

fn create_stored_workflow(desk: &DraftingDesk) -> String {
    let workspace_id = &desk.prepared.workspace_id;
    let created = desk
        .prepared
        .device
        .run(&create_workflow_command(workspace_id, STORED_TASK));
    let workflow_id =
        created.and_then(|view| read_text(&view, "/workflow/id"));
    match workflow_id {
        Ok(workflow_id) => workflow_id,
        Err(problem) => panic!("the stored workflow is created: {problem}"),
    }
}

fn change_command(desk: &DraftingDesk, workflow_id: &str) -> Value {
    json!({
        "command": "change_workflow",
        "workspace_id": desk.prepared.workspace_id,
        "workflow_id": workflow_id,
        "request": "Split the work into steps",
        "agent": "claude_code",
    })
}

fn send_change(
    desk: &DraftingDesk,
    workflow_id: &str,
    final_message: &str,
) -> Result<ChangeReply, TestCaseError> {
    let listed_before = desk.list_workflows().map_err(fail)?;
    let draft = desk
        .start(&change_command(desk, workflow_id))
        .map_err(fail)?;
    desk.finish(&draft, final_message).map_err(fail)?;

    let status = desk.status_reply(&draft);

    let listed_after = desk.list_workflows().map_err(fail)?;
    Ok(ChangeReply {
        status,
        listed_before,
        listed_after,
    })
}

fn drafted_change(
    workflow_id: &str,
    graph: &DraftedGraph,
) -> Result<(Value, Workflow), TestCaseError> {
    let value = drafted_workflow_value(workflow_id, STORED_NAME, graph);
    let workflow = decode_workflow(&value).map_err(fail)?;
    Ok((value, workflow))
}

fn list_named_positions(workflow: &Workflow) -> Vec<(String, f64, f64)> {
    let mut named_positions = Vec::new();
    for agent in &workflow.agents {
        let position = &agent.position;
        named_positions.push((
            agent.name.clone(),
            position.horizontal,
            position.vertical,
        ));
    }
    named_positions
}

fn read_listed_workflow(listed: &Value) -> Result<Value, TestCaseError> {
    let workflow = listed.pointer("/0/workflow").cloned();
    workflow.ok_or_else(|| fail("one workflow is listed"))
}

#[test]
fn test_save_draft_property_a_valid_change_is_saved_as_laid_out() {
    let desk = open_desk_or_panic();
    let workflow_id = create_stored_workflow(&desk);
    let mut runner = TestRunner::new(Config::with_cases(CHANGED_DRAFT_CASES));

    let outcome = runner.run(&acyclic_graph_strategy(), |graph| {
        let (value, drafted) = drafted_change(&workflow_id, &graph)?;
        let reply = send_change(&desk, &workflow_id, &value.to_string())?;

        prop_assert_eq!(
            &reply.status["ok"]["state"],
            "done",
            "{}",
            reply.status
        );
        let listed = read_listed_workflow(&reply.listed_after)?;
        let saved = decode_workflow(&listed).map_err(fail)?;
        let laid_out = lay_out_workflow(&drafted);
        prop_assert_eq!(
            list_named_positions(&saved),
            list_named_positions(&laid_out)
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_save_draft_property_a_refused_change_keeps_the_stored_workflow() {
    let desk = open_desk_or_panic();
    let workflow_id = create_stored_workflow(&desk);
    let mut runner = TestRunner::new(Config::with_cases(CHANGED_DRAFT_CASES));

    let outcome = runner.run(&any_graph_strategy(), |graph| {
        let (value, drafted) = drafted_change(&workflow_id, &graph)?;
        let reply = send_change(&desk, &workflow_id, &value.to_string())?;

        let Some(expected_problem) = expected_draft_problem(&drafted) else {
            return Ok(());
        };
        let shown_problem = reply.status["error"].as_str();
        prop_assert_eq!(shown_problem, Some(expected_problem.as_str()));
        prop_assert_eq!(&reply.listed_after, &reply.listed_before);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_save_draft_property_an_unchanged_draft_saves_nothing() {
    let desk = open_desk_or_panic();
    let workflow_id = create_stored_workflow(&desk);
    let mut runner = TestRunner::new(Config::with_cases(CHANGED_DRAFT_CASES));
    let strategy = (acyclic_graph_strategy(), cyclic_graph_strategy());

    let outcome = runner.run(&strategy, |(valid_graph, cyclic_graph)| {
        let (value, _drafted) = drafted_change(&workflow_id, &valid_graph)?;
        send_change(&desk, &workflow_id, &value.to_string())?;
        let (cyclic_value, _cyclic) =
            drafted_change(&workflow_id, &cyclic_graph)?;
        send_change(&desk, &workflow_id, &cyclic_value.to_string())?;
        let listed = desk.list_workflows().map_err(fail)?;
        let stored = read_listed_workflow(&listed)?;

        let reply = send_change(&desk, &workflow_id, &stored.to_string())?;

        prop_assert_eq!(
            &reply.status["ok"]["state"],
            "done",
            "{}",
            reply.status
        );
        prop_assert_eq!(&reply.listed_after, &reply.listed_before);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
