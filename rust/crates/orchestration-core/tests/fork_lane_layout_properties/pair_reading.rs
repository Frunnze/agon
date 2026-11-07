use orchestration_core::workflow::Workflow;

use crate::fork_reading::read_column_of;
use crate::layout_reading::{ONE_COLUMN, is_same_coordinate};
use crate::workflow_strategies::agent_identifier;

pub fn find_listed_position(
    workflow: &Workflow,
    number: u128,
) -> Option<usize> {
    let agent_id = agent_identifier(number);
    workflow
        .agents
        .iter()
        .position(|agent| agent.id == agent_id)
}

pub fn column_of(workflow: &Workflow, number: u128) -> f64 {
    read_column_of(workflow, agent_identifier(number)).unwrap_or(f64::NAN)
}

pub fn is_beside_in_order(
    laid_out: &Workflow,
    fork: u128,
    (first, second): (u128, u128),
) -> bool {
    let first_position = find_connection_position(laid_out, fork, first);
    let second_position = find_connection_position(laid_out, fork, second);
    let expected_gap = if first_position < second_position {
        ONE_COLUMN
    } else {
        -ONE_COLUMN
    };
    let gap = column_of(laid_out, second) - column_of(laid_out, first);
    is_same_coordinate(gap, expected_gap)
}

fn find_connection_position(
    workflow: &Workflow,
    from: u128,
    to: u128,
) -> Option<usize> {
    let (from_id, to_id) = (agent_identifier(from), agent_identifier(to));
    workflow.connections.iter().position(|connection| {
        connection.from == from_id && connection.to == to_id
    })
}
