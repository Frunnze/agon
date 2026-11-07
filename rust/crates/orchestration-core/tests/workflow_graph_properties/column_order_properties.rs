use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{
    find_agent_by_id, forward_connections,
};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::layout_reading::{
    ROW_PITCH, drafted_workflow, drafted_workflow_without_forks,
    hostile_workflow, is_same_coordinate, list_rows, read_column,
};
use crate::workflow_strategies::workflow_from_parts;

const NO_UPSTREAM_COLUMN: f64 = 0.0;
const TOP_ROW: usize = 0;

fn find_agent_position(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> usize {
    workflow
        .agents
        .iter()
        .position(|agent| agent.id == agent_id)
        .unwrap_or_default()
}

fn find_average_input_column_above(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> f64 {
    let mut input_ids: BTreeSet<WorkflowAgentId> = BTreeSet::new();
    for connection in forward_connections(workflow) {
        if connection.to == agent.id {
            input_ids.insert(connection.from);
        }
    }

    let row_above = agent.position.vertical - ROW_PITCH;
    let mut column_total = 0.0;
    let mut input_count = 0.0;
    for input_id in input_ids {
        let Some(input) = find_agent_by_id(workflow, input_id) else {
            continue;
        };
        if is_same_coordinate(input.position.vertical, row_above) {
            column_total += read_column(input);
            input_count += 1.0;
        }
    }
    if input_count == 0.0 {
        return NO_UPSTREAM_COLUMN;
    }
    column_total / input_count
}

fn reverse_connections(workflow: &Workflow) -> Workflow {
    let mut connections = workflow.connections.clone();
    connections.reverse();
    workflow_from_parts(workflow.agents.clone(), connections)
}

fn duplicate_a_plain_connection(
    workflow: &Workflow,
    pick: prop::sample::Index,
) -> Workflow {
    let plain_connections: Vec<_> = workflow
        .connections
        .iter()
        .filter(|connection| connection.condition.is_none())
        .collect();
    let mut connections = workflow.connections.clone();
    if !plain_connections.is_empty() {
        let picked = plain_connections[pick.index(plain_connections.len())];
        connections.push(picked.clone());
    }
    workflow_from_parts(workflow.agents.clone(), connections)
}

proptest! {
    #[test]
    fn test_compare_row_items_property_the_top_row_follows_the_agent_list(
        workflow in prop_oneof![hostile_workflow(), drafted_workflow()],
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let rows = list_rows(&laid_out);
        let top_positions: Vec<usize> = rows[TOP_ROW]
            .iter()
            .map(|agent| find_agent_position(&laid_out, agent.id))
            .collect();
        let mut sorted_positions = top_positions.clone();
        sorted_positions.sort_unstable();
        prop_assert_eq!(top_positions, sorted_positions);
    }

    #[test]
    fn test_compare_row_items_property_rows_follow_inputs_then_the_list(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for row in list_rows(&laid_out) {
            for neighbours in row.windows(2) {
                let (left, right) = (neighbours[0], neighbours[1]);
                let left_average =
                    find_average_input_column_above(&laid_out, left);
                let right_average =
                    find_average_input_column_above(&laid_out, right);
                let left_position = find_agent_position(&laid_out, left.id);
                let right_position = find_agent_position(&laid_out, right.id);
                let is_in_order = left_average < right_average
                    || (is_same_coordinate(left_average, right_average)
                        && left_position < right_position);
                prop_assert!(is_in_order);
            }
        }
    }

    #[test]
    fn test_compare_row_items_property_ignores_the_connection_order(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let reversed = reverse_connections(&workflow);
        let reversed_layout = lay_out_workflow(&reversed);

        prop_assert_eq!(laid_out.agents, reversed_layout.agents);
    }

    #[test]
    fn test_find_upstream_column_property_inputless_steps_sort_first(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for row in list_rows(&laid_out) {
            let mut has_seen_fed_step = false;
            for agent in row {
                let average =
                    find_average_input_column_above(&laid_out, agent);
                let is_fed = average > NO_UPSTREAM_COLUMN;
                prop_assert!(is_fed || !has_seen_fed_step);
                has_seen_fed_step = has_seen_fed_step || is_fed;
            }
        }
    }

    #[test]
    fn test_find_average_input_column_property_counts_each_input_once(
        workflow in drafted_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let duplicated = duplicate_a_plain_connection(&workflow, pick);
        let duplicated_layout = lay_out_workflow(&duplicated);

        prop_assert_eq!(laid_out.agents, duplicated_layout.agents);
    }
}
