use std::cell::Cell;

use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::Value;

use crate::drafted_graphs::{
    DraftedGraph, acyclic_graph_strategy, any_graph_strategy,
    cyclic_graph_strategy, decode_workflow, drafted_workflow_value,
    expected_draft_problem, has_step_in_top_row, lowest_row_vertical,
    row_limit,
};
use crate::drafting_desk::{DraftingDesk, draft_command, open_desk_or_panic};
use crate::test_device::fail;

const NEW_DRAFT_CASES: u32 = 12;
const DRAFT_NAME_PREFIX: &str = "drafted-";

#[derive(Debug)]
struct DraftReply {
    drafted: Workflow,
    status: Value,
    is_listed: bool,
    remaining_runs: usize,
}

fn send_new_draft(
    desk: &DraftingDesk,
    graph: &DraftedGraph,
    name: &str,
) -> Result<DraftReply, TestCaseError> {
    let draft = desk.start(&draft_command(&desk.prepared)).map_err(fail)?;
    let drafted_value =
        drafted_workflow_value(&draft.workflow_id, name, graph);
    let drafted = decode_workflow(&drafted_value).map_err(fail)?;
    desk.finish(&draft, &drafted_value.to_string())
        .map_err(fail)?;

    let status = desk.status_reply(&draft);

    let workflows = desk.list_workflows().map_err(fail)?;
    let is_listed = workflows.to_string().contains(&draft.workflow_id);
    let remaining_runs = desk.count_task_runs(&draft.task_id).map_err(fail)?;
    Ok(DraftReply {
        drafted,
        status,
        is_listed,
        remaining_runs,
    })
}

fn next_draft_name(drafted_count: &Cell<usize>) -> String {
    let number = drafted_count.get() + 1;
    drafted_count.set(number);
    format!("{DRAFT_NAME_PREFIX}{number}")
}

fn read_saved_workflow(status: &Value) -> Result<Workflow, TestCaseError> {
    decode_workflow(&status["ok"]["workflow"]["workflow"]).map_err(fail)
}

#[test]
fn test_parse_drafted_workflow_property_a_cycle_is_a_draft_problem() {
    let desk = open_desk_or_panic();
    let drafted_count = Cell::new(0);
    let mut runner = TestRunner::new(Config::with_cases(NEW_DRAFT_CASES));

    let outcome = runner.run(&cyclic_graph_strategy(), |graph| {
        let name = next_draft_name(&drafted_count);
        let reply = send_new_draft(&desk, &graph, &name)?;

        let expected_problem = expected_draft_problem(&reply.drafted);
        prop_assert!(expected_problem.is_some(), "{:?}", graph);
        let shown_problem = reply.status["error"].as_str().map(str::to_owned);
        prop_assert_eq!(shown_problem, expected_problem);
        prop_assert!(!reply.is_listed);
        prop_assert_eq!(reply.remaining_runs, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_parse_drafted_workflow_property_saves_the_layout_within_rows() {
    let desk = open_desk_or_panic();
    let drafted_count = Cell::new(0);
    let mut runner = TestRunner::new(Config::with_cases(NEW_DRAFT_CASES));

    let outcome = runner.run(&acyclic_graph_strategy(), |graph| {
        let name = next_draft_name(&drafted_count);
        let reply = send_new_draft(&desk, &graph, &name)?;

        prop_assert_eq!(
            &reply.status["ok"]["state"],
            "done",
            "{}",
            reply.status
        );
        let saved = read_saved_workflow(&reply.status)?;
        let laid_out = lay_out_workflow(&reply.drafted);
        prop_assert_eq!(&saved.agents, &laid_out.agents);
        prop_assert!(has_step_in_top_row(&saved));
        prop_assert!(
            lowest_row_vertical(&saved) <= row_limit(graph.step_count)
        );
        prop_assert!(reply.is_listed);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_parse_drafted_workflow_property_accepts_exactly_valid_graphs() {
    let desk = open_desk_or_panic();
    let drafted_count = Cell::new(0);
    let mut runner = TestRunner::new(Config::with_cases(NEW_DRAFT_CASES));

    let outcome = runner.run(&any_graph_strategy(), |graph| {
        let name = next_draft_name(&drafted_count);
        let reply = send_new_draft(&desk, &graph, &name)?;

        let is_valid = expected_draft_problem(&reply.drafted).is_none();
        prop_assert_eq!(reply.status.get("ok").is_some(), is_valid);
        prop_assert_eq!(reply.is_listed, is_valid);
        prop_assert_eq!(reply.remaining_runs, 0);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
